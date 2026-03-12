#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import shutil
import sqlite3
import subprocess
import sys
import time
import uuid
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable
from urllib.parse import quote


TEXT_EXTENSIONS = {
    ".md",
    ".txt",
    ".sh",
    ".py",
    ".js",
    ".ts",
    ".tsx",
    ".json",
    ".toml",
    ".yaml",
    ".yml",
    ".sql",
}

SKIP_PARTS = {
    ".git",
    ".cursor",
    "node_modules",
    ".next",
    "dist",
    "coverage",
    "__pycache__",
    ".cache",
    "output",
}

REFERENCE_PATTERN = re.compile(
    r"(?P<path>(?:\.\./|\.?/)?[A-Za-z0-9_.-]+(?:/[A-Za-z0-9_.-]+)+\.(?:md|txt|sh|py|js|ts|tsx|json|toml|ya?ml|sql))"
)

PATH_TOKEN_PATTERN = re.compile(
    r"(?:\.\./|\.?/)?[A-Za-z0-9_.-]+(?:/[A-Za-z0-9_.-]+)+"
)


@dataclass
class Document:
    handle: str
    rel_path: str
    doc_type: str
    title: str
    summary: str
    tags: list[str]
    token_estimate: int
    chars: int


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Build and query an RLM-style local retrieval catalog for a repository."
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    build_parser = subparsers.add_parser("build", help="Build or refresh the retrieval catalog")
    add_common_repo_args(build_parser)
    build_parser.add_argument("--force", action="store_true", help="Rebuild even if the catalog already exists")
    build_parser.add_argument("--json", action="store_true", help="Emit JSON instead of human-readable output")

    status_parser = subparsers.add_parser("status", help="Show catalog freshness and metadata")
    add_common_repo_args(status_parser)
    status_parser.add_argument("--json", action="store_true", help="Emit JSON instead of human-readable output")

    query_parser = subparsers.add_parser("query", help="Return candidate handles for a question")
    add_common_repo_args(query_parser)
    query_parser.add_argument("--question", required=True, help="Question or lookup text")
    query_parser.add_argument("--limit", type=int, default=8, help="Maximum candidate handles to return")
    query_parser.add_argument("--session", help="Scratch session id for logging retrieval steps")
    query_parser.add_argument("--json", action="store_true", help="Emit JSON instead of human-readable output")

    peek_parser = subparsers.add_parser("peek", help="Return bounded chunk slices for a handle")
    add_common_repo_args(peek_parser)
    peek_parser.add_argument("--handle", required=True, help="Document handle, usually a repo-relative path")
    peek_parser.add_argument("--offset", type=int, default=0, help="Chunk offset to start from")
    peek_parser.add_argument("--limit", type=int, default=3, help="Maximum chunks to return")
    peek_parser.add_argument("--session", help="Scratch session id for logging retrieval steps")
    peek_parser.add_argument("--json", action="store_true", help="Emit JSON instead of human-readable output")

    expand_parser = subparsers.add_parser("expand", help="Traverse explicit edges from a handle")
    add_common_repo_args(expand_parser)
    expand_parser.add_argument("--handle", required=True, help="Document handle to expand from")
    expand_parser.add_argument("--edge-type", default="references", help="Edge type to traverse")
    expand_parser.add_argument("--depth", type=int, default=1, help="Traversal depth")
    expand_parser.add_argument("--limit", type=int, default=12, help="Maximum related handles to return")
    expand_parser.add_argument("--session", help="Scratch session id for logging retrieval steps")
    expand_parser.add_argument("--json", action="store_true", help="Emit JSON instead of human-readable output")

    summarize_parser = subparsers.add_parser("summarize", help="Compact a set of handles into a small summary")
    add_common_repo_args(summarize_parser)
    summarize_parser.add_argument("--handle", action="append", required=True, help="Handle to summarize")
    summarize_parser.add_argument("--budget", type=int, default=480, help="Maximum summary characters")
    summarize_parser.add_argument("--session", help="Scratch session id for logging retrieval steps")
    summarize_parser.add_argument("--json", action="store_true", help="Emit JSON instead of human-readable output")

    session_start_parser = subparsers.add_parser("session-start", help="Create a scratch retrieval session")
    add_common_repo_args(session_start_parser)
    session_start_parser.add_argument("--json", action="store_true", help="Emit JSON instead of human-readable output")

    session_show_parser = subparsers.add_parser("session-show", help="Show a scratch retrieval session")
    add_common_repo_args(session_show_parser)
    session_show_parser.add_argument("--session", required=True, help="Scratch session id to read")
    session_show_parser.add_argument("--json", action="store_true", help="Emit JSON instead of human-readable output")

    return parser.parse_args()


def add_common_repo_args(parser: argparse.ArgumentParser) -> None:
    parser.add_argument("--repo", required=True, help="Repository root to index")
    parser.add_argument("--index-root", help="Override cache root for index artifacts")


def main() -> int:
    args = parse_args()
    repo_root = Path(args.repo).expanduser().resolve()
    if not repo_root.exists():
        raise SystemExit(f"Repository not found: {repo_root}")

    index_root = resolve_index_root(repo_root, args.index_root)
    db_path = index_root / "catalog.sqlite3"
    manifest_path = index_root / "manifest.json"
    sessions_dir = index_root / "sessions"

    if args.command == "build":
        payload = build_catalog(repo_root, index_root, db_path, manifest_path, force=args.force)
        emit(payload, args.json)
        return 0

    if args.command == "status":
        payload = catalog_status(repo_root, db_path, manifest_path, sessions_dir)
        emit(payload, args.json)
        return 0

    ensure_catalog(repo_root, index_root, db_path, manifest_path)
    status = catalog_status(repo_root, db_path, manifest_path, sessions_dir)

    if args.command == "query":
        payload = query_candidates(db_path, args.question, limit=args.limit)
        payload["catalog_status"] = status
        maybe_record_step(sessions_dir, args.session, "query", {"question": args.question, "limit": args.limit}, payload)
        emit(payload, args.json)
        return 0

    if args.command == "peek":
        payload = peek_chunks(db_path, args.handle, args.offset, args.limit)
        payload["catalog_status"] = status
        maybe_record_step(
            sessions_dir,
            args.session,
            "peek",
            {"handle": args.handle, "offset": args.offset, "limit": args.limit},
            payload,
        )
        emit(payload, args.json)
        return 0

    if args.command == "expand":
        payload = expand_handle(db_path, args.handle, args.edge_type, args.depth, args.limit)
        payload["catalog_status"] = status
        maybe_record_step(
            sessions_dir,
            args.session,
            "expand",
            {"handle": args.handle, "edge_type": args.edge_type, "depth": args.depth, "limit": args.limit},
            payload,
        )
        emit(payload, args.json)
        return 0

    if args.command == "summarize":
        payload = summarize_handles(db_path, args.handle, args.budget)
        payload["catalog_status"] = status
        maybe_record_step(
            sessions_dir,
            args.session,
            "summarize",
            {"handles": args.handle, "budget": args.budget},
            payload,
        )
        emit(payload, args.json)
        return 0

    if args.command == "session-start":
        payload = start_session(sessions_dir, repo_root, status)
        emit(payload, args.json)
        return 0

    if args.command == "session-show":
        payload = show_session(sessions_dir, args.session)
        emit(payload, args.json)
        return 0

    raise SystemExit(f"Unsupported command: {args.command}")


def resolve_index_root(repo_root: Path, index_root: str | None) -> Path:
    if index_root:
        return Path(index_root).expanduser().resolve()
    repo_hash = hashlib.sha1(str(repo_root).encode("utf-8")).hexdigest()[:12]
    return Path.home().resolve() / ".codex" / "cache" / "knowledge" / repo_hash


def ensure_catalog(repo_root: Path, index_root: Path, db_path: Path, manifest_path: Path) -> None:
    if db_path.exists() and manifest_path.exists():
        return
    build_catalog(repo_root, index_root, db_path, manifest_path, force=False)


def build_catalog(repo_root: Path, index_root: Path, db_path: Path, manifest_path: Path, force: bool) -> dict:
    if force and index_root.exists():
        shutil.rmtree(index_root)

    index_root.mkdir(parents=True, exist_ok=True)
    files = list_repo_files(repo_root)
    built_at = time.time()
    documents: list[Document] = []
    chunk_rows: list[tuple] = []
    edge_rows: list[tuple] = []

    for rel_path in files:
        abs_path = repo_root / rel_path
        try:
            text = abs_path.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            continue
        except OSError:
            continue

        title = extract_title(text, rel_path)
        summary = extract_summary(text)
        tags = extract_tags(rel_path, text)
        token_estimate = approx_tokens(text)
        document = Document(
            handle=rel_path,
            rel_path=rel_path,
            doc_type=classify_path(rel_path),
            title=title,
            summary=summary,
            tags=tags,
            token_estimate=token_estimate,
            chars=len(text),
        )
        documents.append(document)

        for ordinal, chunk in enumerate(chunk_document(text, rel_path, title), start=0):
            chunk_rows.append(
                (
                    rel_path,
                    ordinal,
                    chunk["title"],
                    chunk["start_line"],
                    chunk["end_line"],
                    chunk["text"],
                    " ".join(tags),
                )
            )

        for target in extract_references(repo_root, rel_path, text):
            edge_rows.append((rel_path, "references", target))

    write_catalog(db_path, documents, chunk_rows, edge_rows)
    manifest = {
        "repo_root": str(repo_root),
        "built_at": built_at,
        "document_count": len(documents),
        "chunk_count": len(chunk_rows),
        "edge_count": len(edge_rows),
        "index_root": str(index_root),
        "fts_backend": detect_fts_backend(db_path),
        "doc_type_counts": count_doc_types(documents),
        "git_head": get_git_head(repo_root),
        "indexed_source_mtime": max_source_mtime(repo_root, files),
    }
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    return manifest


def list_repo_files(repo_root: Path) -> list[str]:
    git_files = git_ls_files(repo_root)
    if git_files:
        return [path for path in git_files if should_index(path)]

    results: list[str] = []
    for abs_path in repo_root.rglob("*"):
        if not abs_path.is_file():
            continue
        rel_path = abs_path.relative_to(repo_root).as_posix()
        if should_index(rel_path):
            results.append(rel_path)
    return sorted(results)


def git_ls_files(repo_root: Path) -> list[str]:
    try:
        output = subprocess.check_output(
            ["git", "-C", str(repo_root), "ls-files"],
            stderr=subprocess.DEVNULL,
            text=True,
        )
    except (subprocess.CalledProcessError, FileNotFoundError):
        return []
    return [line.strip() for line in output.splitlines() if line.strip()]


def should_index(rel_path: str) -> bool:
    path = Path(rel_path)
    if path.suffix.lower() not in TEXT_EXTENSIONS:
        return False
    if any(part in SKIP_PARTS for part in path.parts):
        return False
    return True


def classify_path(rel_path: str) -> str:
    if rel_path == ".codex/AGENTS.md":
        return "policy"
    if rel_path.startswith(".worklog/"):
        return "worklog"
    if rel_path.endswith("/SKILL.md") or rel_path.startswith(".agents/skills/") or rel_path.startswith(".codex/skills/"):
        return "skill"
    if rel_path.startswith(".codex/prompts/"):
        return "prompt"
    if rel_path.startswith("docs/"):
        return "doc"
    if rel_path.startswith(".codex/scripts/") or rel_path == "scripts/onboarding.sh":
        return "script"
    if rel_path.endswith(".toml") or rel_path.endswith(".json"):
        return "config"
    return "text"


def extract_title(text: str, rel_path: str) -> str:
    for line in text.splitlines():
        stripped = line.strip()
        if stripped.startswith("#"):
            return stripped.lstrip("#").strip()
        if stripped:
            return stripped[:96]
    return rel_path


def extract_summary(text: str) -> str:
    lines: list[str] = []
    in_code = False
    for raw_line in text.splitlines():
        stripped = raw_line.strip()
        if stripped.startswith("```"):
            in_code = not in_code
            continue
        if in_code or not stripped or stripped.startswith("#"):
            continue
        lines.append(stripped)
        if len(" ".join(lines)) >= 220 or len(lines) >= 2:
            break
    summary = " ".join(lines).strip()
    return summary[:240] if summary else "No summary available."


def extract_tags(rel_path: str, text: str) -> list[str]:
    tags = {part for part in Path(rel_path).parts if part not in {".", ".."}}
    lowered = text.lower()
    for keyword in ("policy", "worklog", "skill", "prompt", "linear", "playwright", "bootstrap", "retrieval"):
        if keyword in lowered or keyword in rel_path.lower():
            tags.add(keyword)
    return sorted(tags)


def chunk_document(text: str, rel_path: str, default_title: str) -> list[dict]:
    lines = text.splitlines()
    if not lines:
        return [{"title": default_title, "start_line": 1, "end_line": 1, "text": ""}]

    chunks: list[dict] = []
    current_title = default_title
    start = 0
    window = 36

    for index, line in enumerate(lines):
        stripped = line.strip()
        if stripped.startswith("#"):
            current_title = stripped.lstrip("#").strip() or current_title
        if index > start and (index - start >= window):
            chunk_lines = lines[start:index]
            chunks.append(
                {
                    "title": current_title,
                    "start_line": start + 1,
                    "end_line": index,
                    "text": "\n".join(chunk_lines).strip(),
                }
            )
            start = index

    chunk_lines = lines[start:]
    chunks.append(
        {
            "title": current_title,
            "start_line": start + 1,
            "end_line": len(lines),
            "text": "\n".join(chunk_lines).strip(),
        }
    )
    return [chunk for chunk in chunks if chunk["text"]]


def extract_references(repo_root: Path, rel_path: str, text: str) -> set[str]:
    source_path = repo_root / rel_path
    references: set[str] = set()
    for match in REFERENCE_PATTERN.finditer(text):
        candidate = match.group("path")
        target = resolve_reference(repo_root, source_path.parent, candidate)
        if target:
            references.add(target)
    return references


def resolve_reference(repo_root: Path, source_dir: Path, candidate: str) -> str | None:
    normalized = Path(candidate)
    attempts = []
    if normalized.is_absolute():
        attempts.append(normalized)
    else:
        attempts.append((source_dir / normalized).resolve())
        attempts.append((repo_root / normalized).resolve())

    for abs_path in attempts:
        try:
            rel_path = abs_path.relative_to(repo_root.resolve())
        except ValueError:
            continue
        if abs_path.exists() and abs_path.is_file():
            return rel_path.as_posix()

    if ".codex/skills/" in candidate:
        nested = candidate[candidate.index(".codex/skills/") :]
        nested_attempt = (repo_root / nested).resolve()
        try:
            rel_path = nested_attempt.relative_to(repo_root.resolve())
        except ValueError:
            rel_path = None
        if rel_path and nested_attempt.exists() and nested_attempt.is_file():
            return rel_path.as_posix()
    if "agents/skills/" in candidate:
        nested = candidate[candidate.index("agents/skills/") :]
        nested_attempt = (repo_root / nested).resolve()
        try:
            rel_path = nested_attempt.relative_to(repo_root.resolve())
        except ValueError:
            rel_path = None
        if rel_path and nested_attempt.exists() and nested_attempt.is_file():
            return rel_path.as_posix()
    return None


def write_catalog(
    db_path: Path,
    documents: list[Document],
    chunk_rows: list[tuple],
    edge_rows: list[tuple],
) -> None:
    with sqlite3.connect(db_path) as conn:
        conn.execute("PRAGMA journal_mode = WAL")
        conn.execute("DROP TABLE IF EXISTS documents")
        conn.execute("DROP TABLE IF EXISTS chunks")
        conn.execute("DROP TABLE IF EXISTS edges")
        conn.execute("DROP TABLE IF EXISTS chunk_fts")

        conn.execute(
            """
            CREATE TABLE documents (
                handle TEXT PRIMARY KEY,
                rel_path TEXT NOT NULL,
                doc_type TEXT NOT NULL,
                title TEXT NOT NULL,
                summary TEXT NOT NULL,
                tags TEXT NOT NULL,
                token_estimate INTEGER NOT NULL,
                chars INTEGER NOT NULL
            )
            """
        )
        conn.execute(
            """
            CREATE TABLE chunks (
                handle TEXT NOT NULL,
                ordinal INTEGER NOT NULL,
                title TEXT NOT NULL,
                start_line INTEGER NOT NULL,
                end_line INTEGER NOT NULL,
                text TEXT NOT NULL,
                tags TEXT NOT NULL,
                PRIMARY KEY(handle, ordinal)
            )
            """
        )
        conn.execute(
            """
            CREATE TABLE edges (
                source_handle TEXT NOT NULL,
                edge_type TEXT NOT NULL,
                target_handle TEXT NOT NULL
            )
            """
        )

        conn.executemany(
            """
            INSERT INTO documents(handle, rel_path, doc_type, title, summary, tags, token_estimate, chars)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """,
            [
                (
                    document.handle,
                    document.rel_path,
                    document.doc_type,
                    document.title,
                    document.summary,
                    " ".join(document.tags),
                    document.token_estimate,
                    document.chars,
                )
                for document in documents
            ],
        )
        conn.executemany(
            """
            INSERT INTO chunks(handle, ordinal, title, start_line, end_line, text, tags)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            """,
            chunk_rows,
        )
        conn.executemany(
            """
            INSERT INTO edges(source_handle, edge_type, target_handle)
            VALUES (?, ?, ?)
            """,
            edge_rows,
        )

        try:
            conn.execute(
                """
                CREATE VIRTUAL TABLE chunk_fts USING fts5(
                    handle UNINDEXED,
                    rel_path UNINDEXED,
                    title,
                    text,
                    tags
                )
                """
            )
            conn.execute(
                """
                INSERT INTO chunk_fts(handle, rel_path, title, text, tags)
                SELECT chunks.handle, documents.rel_path, chunks.title, chunks.text, chunks.tags
                FROM chunks
                JOIN documents ON documents.handle = chunks.handle
                """
            )
        except sqlite3.OperationalError:
            pass


def connect_readonly(db_path: Path) -> sqlite3.Connection:
    uri = f"file:{quote(str(db_path.resolve()))}?mode=ro&immutable=1"
    return sqlite3.connect(uri, uri=True)


def detect_fts_backend(db_path: Path) -> str:
    with connect_readonly(db_path) as conn:
        row = conn.execute(
            "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'chunk_fts'"
        ).fetchone()
        return "fts5" if row else "fallback"


def get_git_head(repo_root: Path) -> str | None:
    try:
        output = subprocess.check_output(
            ["git", "-C", str(repo_root), "rev-parse", "HEAD"],
            stderr=subprocess.DEVNULL,
            text=True,
        ).strip()
    except (subprocess.CalledProcessError, FileNotFoundError):
        return None
    return output or None


def max_source_mtime(repo_root: Path, files: Iterable[str] | None = None) -> float | None:
    rel_paths = list(files) if files is not None else list_repo_files(repo_root)
    latest: float | None = None
    for rel_path in rel_paths:
        try:
            mtime = (repo_root / rel_path).stat().st_mtime
        except OSError:
            continue
        if latest is None or mtime > latest:
            latest = mtime
    return latest


def count_doc_types(documents: Iterable[Document]) -> dict[str, int]:
    counts: dict[str, int] = {}
    for document in documents:
        counts[document.doc_type] = counts.get(document.doc_type, 0) + 1
    return dict(sorted(counts.items()))


def load_manifest(manifest_path: Path) -> dict:
    if not manifest_path.exists():
        return {}
    return json.loads(manifest_path.read_text(encoding="utf-8"))


def catalog_status(repo_root: Path, db_path: Path, manifest_path: Path, sessions_dir: Path) -> dict:
    manifest = load_manifest(manifest_path)
    catalog_exists = db_path.exists()
    manifest_exists = manifest_path.exists()
    current_git_head = get_git_head(repo_root)
    current_source_mtime = max_source_mtime(repo_root) if catalog_exists or manifest_exists else None
    recorded_git_head = manifest.get("git_head")
    recorded_source_mtime = manifest.get("indexed_source_mtime")
    built_at = manifest.get("built_at")
    stale_reasons: list[str] = []

    if not catalog_exists:
        stale_reasons.append("catalog_missing")
    if not manifest_exists:
        stale_reasons.append("manifest_missing")
    if recorded_git_head and current_git_head and recorded_git_head != current_git_head:
        stale_reasons.append("git_head_changed")
    if (
        current_source_mtime is not None
        and (
            (recorded_source_mtime is not None and current_source_mtime > float(recorded_source_mtime) + 0.001)
            or (recorded_source_mtime is None and built_at is not None and current_source_mtime > float(built_at) + 0.001)
        )
    ):
        stale_reasons.append("source_files_newer")

    return {
        "index_root": str(db_path.parent),
        "catalog_path": str(db_path),
        "manifest_path": str(manifest_path),
        "sessions_dir": str(sessions_dir),
        "catalog_exists": catalog_exists,
        "manifest_exists": manifest_exists,
        "built_at": built_at,
        "document_count": manifest.get("document_count"),
        "chunk_count": manifest.get("chunk_count"),
        "edge_count": manifest.get("edge_count"),
        "fts_backend": manifest.get("fts_backend"),
        "doc_type_counts": manifest.get("doc_type_counts", {}),
        "git_head_recorded": recorded_git_head,
        "git_head_current": current_git_head,
        "indexed_source_mtime": recorded_source_mtime,
        "current_source_mtime": current_source_mtime,
        "stale": bool(stale_reasons),
        "stale_reasons": stale_reasons,
    }


def query_candidates(db_path: Path, question: str, limit: int) -> dict:
    query = normalize_query(question)
    path_tokens = extract_path_tokens(question)
    candidates: dict[str, dict] = {}
    lowered_question = question.lower()

    with connect_readonly(db_path) as conn:
        conn.row_factory = sqlite3.Row

        for token in path_tokens:
            rows = conn.execute(
                """
                SELECT handle, rel_path, doc_type, title, summary, tags, token_estimate
                FROM documents
                WHERE rel_path LIKE ? OR rel_path LIKE ? OR title LIKE ?
                """,
                (f"%{token}%", f"%/{token}%", f"%{token}%"),
            ).fetchall()
            for row in rows:
                candidates.setdefault(row["handle"], materialize_candidate(row, 120.0))

        if query:
            fts_available = conn.execute(
                "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = 'chunk_fts'"
            ).fetchone()
            if fts_available:
                rows = conn.execute(
                    """
                    SELECT documents.handle, documents.rel_path, documents.doc_type, documents.title,
                           documents.summary, documents.tags, documents.token_estimate,
                           bm25(chunk_fts) AS rank_score
                    FROM chunk_fts
                    JOIN documents ON documents.handle = chunk_fts.handle
                    WHERE chunk_fts MATCH ?
                    ORDER BY rank_score
                    LIMIT ?
                    """,
                    (query, limit * 3),
                ).fetchall()
                for row in rows:
                    score = max(0.0, 100.0 - float(row["rank_score"]) * 10.0)
                    existing = candidates.get(row["handle"])
                    if existing is None or score > existing["score"]:
                        candidates[row["handle"]] = materialize_candidate(row, score)
            else:
                tokens = [token for token in query.split() if token]
                for token in tokens:
                    rows = conn.execute(
                        """
                        SELECT handle, rel_path, doc_type, title, summary, tags, token_estimate
                        FROM documents
                        WHERE title LIKE ? OR summary LIKE ? OR tags LIKE ?
                        LIMIT ?
                        """,
                        (f"%{token}%", f"%{token}%", f"%{token}%", limit * 2),
                    ).fetchall()
                    for row in rows:
                        existing = candidates.get(row["handle"])
                        score = 70.0 if existing is None else existing["score"] + 5.0
                        candidates[row["handle"]] = materialize_candidate(row, score)

        apply_question_heuristics(conn, candidates, lowered_question)

    ranked = sorted(candidates.values(), key=lambda item: (-item["score"], item["handle"]))[:limit]
    return {"question": question, "query": query, "candidates": ranked}


def materialize_candidate(row: sqlite3.Row, score: float) -> dict:
    return {
        "handle": row["handle"],
        "rel_path": row["rel_path"],
        "doc_type": row["doc_type"],
        "title": row["title"],
        "summary": row["summary"],
        "tags": row["tags"].split(),
        "token_estimate": row["token_estimate"],
        "score": round(score, 2),
    }


def normalize_query(question: str) -> str:
    tokens = []
    for token in re.findall(r"[A-Za-z0-9_.-]+", question.lower()):
        if len(token) < 3:
            continue
        if token in {"what", "when", "where", "with", "that", "this", "from", "into", "only"}:
            continue
        tokens.append(token)
    return " OR ".join(dict.fromkeys(tokens))


def extract_path_tokens(question: str) -> list[str]:
    tokens = [match.group(0) for match in PATH_TOKEN_PATTERN.finditer(question)]
    cleaned: list[str] = []
    for token in tokens:
        normalized = token.strip("`\"' ")
        if normalized:
            cleaned.append(normalized)
    return cleaned


def apply_question_heuristics(
    conn: sqlite3.Connection,
    candidates: dict[str, dict],
    lowered_question: str,
) -> None:
    boosts: list[tuple[str, float]] = []
    if any(term in lowered_question for term in ("git", "pr", "pull request", "ticket", "linear")):
        boosts.append((".codex/AGENTS.md", 140.0))
    if any(term in lowered_question for term in ("current goal", "current focus", "active goal", "active focus")):
        boosts.append((".worklog/current-focus.md", 145.0))
    if "worklog" in lowered_question:
        boosts.append((".worklog/latest-handoff.md", 120.0))
        boosts.append((".worklog/current-focus.md", 120.0))
    if "read" in lowered_question and "worklog" in lowered_question:
        boosts.append((".codex/AGENTS.md", 130.0))
    if "skill" in lowered_question and "script" in lowered_question:
        boosts.append((".codex/skills/playwright/SKILL.md", 115.0))

    for handle, score in boosts:
        row = conn.execute(
            """
            SELECT handle, rel_path, doc_type, title, summary, tags, token_estimate
            FROM documents
            WHERE handle = ?
            """,
            (handle,),
        ).fetchone()
        if row is None:
            continue
        existing = candidates.get(handle)
        if existing is None or score > existing["score"]:
            candidates[handle] = materialize_candidate(row, score)


def peek_chunks(db_path: Path, handle: str, offset: int, limit: int) -> dict:
    with connect_readonly(db_path) as conn:
        conn.row_factory = sqlite3.Row
        doc = conn.execute(
            """
            SELECT handle, rel_path, doc_type, title, summary, tags, token_estimate
            FROM documents
            WHERE handle = ?
            """,
            (handle,),
        ).fetchone()
        if doc is None:
            raise SystemExit(f"Unknown handle: {handle}")

        rows = conn.execute(
            """
            SELECT ordinal, title, start_line, end_line, text
            FROM chunks
            WHERE handle = ?
            ORDER BY ordinal
            LIMIT ? OFFSET ?
            """,
            (handle, limit, offset),
        ).fetchall()

    return {
        "handle": handle,
        "rel_path": doc["rel_path"],
        "title": doc["title"],
        "offset": offset,
        "limit": limit,
        "chunks": [
            {
                "ordinal": row["ordinal"],
                "title": row["title"],
                "start_line": row["start_line"],
                "end_line": row["end_line"],
                "text": row["text"],
            }
            for row in rows
        ],
    }


def expand_handle(db_path: Path, handle: str, edge_type: str, depth: int, limit: int) -> dict:
    visited = {handle}
    frontier = [(handle, 0)]
    related: list[dict] = []

    with connect_readonly(db_path) as conn:
        conn.row_factory = sqlite3.Row
        while frontier and len(related) < limit:
            current_handle, current_depth = frontier.pop(0)
            if current_depth >= depth:
                continue
            rows = conn.execute(
                """
                SELECT edges.target_handle AS handle, documents.rel_path, documents.doc_type,
                       documents.title, documents.summary
                FROM edges
                JOIN documents ON documents.handle = edges.target_handle
                WHERE edges.source_handle = ? AND edges.edge_type = ?
                ORDER BY documents.rel_path
                """,
                (current_handle, edge_type),
            ).fetchall()
            for row in rows:
                if row["handle"] in visited:
                    continue
                visited.add(row["handle"])
                related.append(
                    {
                        "handle": row["handle"],
                        "rel_path": row["rel_path"],
                        "doc_type": row["doc_type"],
                        "title": row["title"],
                        "summary": row["summary"],
                        "depth": current_depth + 1,
                    }
                )
                frontier.append((row["handle"], current_depth + 1))
                if len(related) >= limit:
                    break

    return {"handle": handle, "edge_type": edge_type, "depth": depth, "related": related}


def summarize_handles(db_path: Path, handles: Iterable[str], budget: int) -> dict:
    unique_handles = list(dict.fromkeys(handles))
    with connect_readonly(db_path) as conn:
        conn.row_factory = sqlite3.Row
        rows = conn.execute(
            f"""
            SELECT handle, rel_path, doc_type, title, summary, token_estimate
            FROM documents
            WHERE handle IN ({",".join("?" for _ in unique_handles)})
            ORDER BY rel_path
            """,
            unique_handles,
        ).fetchall()

    lines: list[str] = []
    used = 0
    for row in rows:
        line = f"- {row['rel_path']}: {row['summary']}"
        projected = used + len(line) + (1 if lines else 0)
        if projected > budget and lines:
            break
        lines.append(line[: max(0, budget - used)])
        used = projected

    return {
        "handles": unique_handles,
        "budget": budget,
        "summary": "\n".join(lines),
        "used_chars": len("\n".join(lines)),
    }


def start_session(sessions_dir: Path, repo_root: Path, status: dict) -> dict:
    session_id = uuid.uuid4().hex[:12]
    root_metadata = {
        "document_count": status.get("document_count", 0),
        "chunk_count": status.get("chunk_count", 0),
        "edge_count": status.get("edge_count", 0),
        "fts_backend": status.get("fts_backend"),
        "doc_type_counts": status.get("doc_type_counts", {}),
        "git_head_recorded": status.get("git_head_recorded"),
        "git_head_current": status.get("git_head_current"),
        "stale": status.get("stale", False),
    }
    payload = {
        "session": session_id,
        "repo_root": str(repo_root),
        "created_at": int(time.time()),
        "root_metadata": root_metadata,
        "catalog_status": status,
        "persisted": True,
        "steps": [],
    }
    try:
        sessions_dir.mkdir(parents=True, exist_ok=True)
        (sessions_dir / f"{session_id}.json").write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
    except OSError as exc:
        payload["persisted"] = False
        payload["persistence_error"] = str(exc)
    return payload


def show_session(sessions_dir: Path, session_id: str) -> dict:
    session_path = sessions_dir / f"{session_id}.json"
    if not session_path.exists():
        raise SystemExit(f"Unknown session: {session_id}")
    return json.loads(session_path.read_text(encoding="utf-8"))


def maybe_record_step(
    sessions_dir: Path,
    session_id: str | None,
    operation: str,
    request_payload: dict,
    response_payload: dict,
) -> None:
    if not session_id:
        return
    session_path = sessions_dir / f"{session_id}.json"
    if not session_path.exists():
        raise SystemExit(f"Unknown session: {session_id}")
    payload = json.loads(session_path.read_text(encoding="utf-8"))
    payload.setdefault("steps", []).append(
        {
            "at": int(time.time()),
            "operation": operation,
            "request": request_payload,
            "response": response_payload,
        }
    )
    session_path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")


def approx_tokens(text: str) -> int:
    return (len(text) + 3) // 4


def emit(payload: dict, as_json: bool) -> None:
    if as_json:
        json.dump(payload, sys.stdout, indent=2)
        sys.stdout.write("\n")
        return
    print(json.dumps(payload, indent=2))


if __name__ == "__main__":
    raise SystemExit(main())

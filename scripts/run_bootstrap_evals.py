#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import tarfile
import tempfile
import time
from io import BytesIO
from pathlib import Path

from role_skill_matrix import load_matrix, set_enabled

SCENARIOS = [
    {
        "name": "plan_generation",
        "workspace": "target",
        "search": False,
        "prompt": (
            "Using only local repository context, write a compact implementation plan to add a CI gate "
            "that runs scripts/bootstrap-budget.sh against tw-portfolio and fails if bootstrap exceeds "
            "1500 approximate tokens or the session total exceeds 3000. Do not use web, do not spawn "
            "agents, and do not edit files. Use sections: Goal, Key Changes, Verification."
        ),
        "checks": [
            ("mentions bootstrap script", re.compile(r"bootstrap-budget\.sh", re.I)),
            ("mentions 1500 threshold", re.compile(r"\b1500\b")),
            ("mentions 3000 threshold", re.compile(r"\b3000\b")),
            ("mentions CI workflow", re.compile(r"\bCI\b|\.github/workflows|pull_request", re.I)),
        ],
    },
    {
        "name": "code_review",
        "workspace": "shared",
        "search": False,
        "prompt": (
            "Review this diff. Findings first, ordered by severity, with file references. If there are no "
            "material findings, say so explicitly and mention residual risks or testing gaps. Do not run "
            "tests, do not use web, and do not spawn agents.\n\n"
            "Diff to review:\n{shared_diff}"
        ),
        "checks": [
            ("findings-first output", re.compile(r"(?is)^\s*(?:\*\*findings\*\*|findings\b|1\.\s|-\s|no material findings)")),
            ("references changed files", re.compile(r"scripts/onboarding\.sh|scripts/bootstrap-budget\.sh|AGENTS\.md", re.I)),
            ("mentions risk or testing gap", re.compile(r"risk|testing gap|residual", re.I)),
        ],
    },
    {
        "name": "research_with_citations",
        "workspace": "target",
        "search": True,
        "prompt": (
            "Using official OpenAI sources, answer this question for a Codex-style agent workflow: when "
            "is vector retrieval preferable to on-demand file reads for keeping bootstrap tokens low, and "
            "when is a graph layer justified? Use sections: Verified, Inference, Sources. Do not edit files."
        ),
        "checks": [
            ("has verified section", re.compile(r"verified", re.I)),
            ("has inference section", re.compile(r"inference", re.I)),
            ("has sources section", re.compile(r"sources", re.I)),
            ("contains OpenAI source", re.compile(r"openai\.com|platform\.openai\.com|developers\.openai\.com", re.I)),
        ],
    },
]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Run paired baseline vs candidate bootstrap-quality evals and retrieval checks."
    )
    parser.add_argument("--shared-repo", default=str(Path(__file__).resolve().parents[1]), help="Path to codex-home repo")
    parser.add_argument("--target-repo", required=True, help="Path to the repository to evaluate as the working repo")
    parser.add_argument("--baseline-ref", default="HEAD", help="Git ref to use as the prompt baseline")
    parser.add_argument("--output-dir", help="Directory for eval artifacts")
    parser.add_argument("--model", help="Optional model override")
    parser.add_argument("--timeout-seconds", type=int, default=180, help="Timeout per Codex exec trial")
    parser.add_argument("--json", action="store_true", help="Emit JSON summary")
    parser.add_argument("--keep-artifacts", action="store_true", help="Keep temp artifact directories")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    shared_repo = Path(args.shared_repo).expanduser().resolve()
    target_repo = Path(args.target_repo).expanduser().resolve()
    output_dir = Path(args.output_dir).expanduser().resolve() if args.output_dir else Path(tempfile.mkdtemp(prefix="bootstrap-evals-"))
    output_dir.mkdir(parents=True, exist_ok=True)

    workspace = Path(tempfile.mkdtemp(prefix="bootstrap-evals-work-"))
    try:
        shared_baseline = workspace / "shared-baseline"
        shared_candidate = workspace / "shared-candidate"
        target_baseline = workspace / "target-baseline"
        target_candidate = workspace / "target-candidate"

        extract_git_snapshot(shared_repo, args.baseline_ref, shared_baseline)
        extract_git_snapshot(target_repo, args.baseline_ref, target_baseline)
        copy_worktree_snapshot(shared_repo, shared_candidate)
        copy_worktree_snapshot(target_repo, target_candidate)

        baseline_home = prepare_eval_home(shared_baseline, shared_repo, workspace / "home-baseline")
        candidate_home = prepare_eval_home(shared_candidate, shared_repo, workspace / "home-candidate")

        shared_diff = subprocess.check_output(
            ["git", "-C", str(shared_repo), "diff", "--", "AGENTS.md", "scripts/onboarding.sh", "scripts/bootstrap-budget.sh"],
            text=True,
        ).strip()

        result = {
            "run_at": int(time.time()),
            "output_dir": str(output_dir),
            "baseline_ref": args.baseline_ref,
            "shared_repo": str(shared_repo),
            "target_repo": str(target_repo),
            "baseline": run_variant(
                "baseline",
                baseline_home,
                shared_baseline,
                shared_repo,
                target_baseline,
                output_dir / "baseline",
                shared_diff,
                args.model,
                args.timeout_seconds,
            ),
            "candidate": run_variant(
                "candidate",
                candidate_home,
                shared_candidate,
                shared_repo,
                target_candidate,
                output_dir / "candidate",
                shared_diff,
                args.model,
                args.timeout_seconds,
            ),
        }
        result["comparison"] = compare_variants(result["baseline"], result["candidate"])
        result["retrieval_trials"] = run_retrieval_trials(shared_candidate, target_candidate, output_dir / "retrieval")

        summary_path = output_dir / "summary.json"
        summary_path.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
        if args.json:
            json.dump(result, sys.stdout, indent=2)
            sys.stdout.write("\n")
        else:
            print_summary(result, summary_path)
        return 0
    finally:
        if not args.keep_artifacts:
            shutil.rmtree(workspace, ignore_errors=True)


def extract_git_snapshot(repo_root: Path, git_ref: str, destination: Path) -> None:
    destination.mkdir(parents=True, exist_ok=True)
    archive = subprocess.check_output(["git", "-C", str(repo_root), "archive", git_ref])
    with tarfile.open(fileobj=BytesIO(archive)) as tar:
        tar.extractall(destination)


def copy_worktree_snapshot(repo_root: Path, destination: Path) -> None:
    ignore = shutil.ignore_patterns(
        ".git",
        "node_modules",
        ".next",
        "dist",
        "coverage",
        "__pycache__",
        ".cache",
        "output",
        "tmp",
        "log",
        "shell_snapshots",
        "state_*.sqlite*",
        "models_cache.json",
        "session_index.jsonl",
        "history.jsonl",
        "sessions",
    )
    shutil.copytree(repo_root, destination, ignore=ignore)


def prepare_eval_home(shared_snapshot: Path, actual_shared_repo: Path, home_dir: Path) -> Path:
    home_dir.mkdir(parents=True, exist_ok=True)
    codex_home = home_dir / ".codex"
    if codex_home.exists():
        codex_home.unlink()
    os.symlink(shared_snapshot, codex_home, target_is_directory=True)

    for filename in ("auth.json", ".credentials.json", "config.toml", "config.local.toml"):
        source = actual_shared_repo / filename
        target = shared_snapshot / filename
        if source.exists() and not target.exists():
            shutil.copy2(source, target)

    duplicate_system_dir = shared_snapshot / "agents" / "skills" / ".system"
    canonical_system_dir = shared_snapshot / "skills" / ".system"
    if duplicate_system_dir.exists() and canonical_system_dir.exists():
        shutil.rmtree(duplicate_system_dir)

    agents_home = home_dir / ".agents"
    agents_home.mkdir(parents=True, exist_ok=True)
    skills_dir = agents_home / "skills"
    skills_library_dir = agents_home / "skills-library"
    for directory in (skills_dir, skills_library_dir):
        if directory.exists():
            shutil.rmtree(directory)
        directory.mkdir(parents=True, exist_ok=True)

    source_skill_root = shared_snapshot / "agents" / "skills"
    enabled = set(set_enabled(load_matrix()))
    for skill_dir in sorted(source_skill_root.iterdir()):
        if not skill_dir.is_dir() or skill_dir.name.startswith("."):
            continue
        destination = skills_dir if skill_dir.name in enabled else skills_library_dir
        os.symlink(skill_dir, destination / skill_dir.name, target_is_directory=True)

    return home_dir


def run_variant(
    label: str,
    home_dir: Path,
    shared_snapshot: Path,
    fallback_shared_repo: Path,
    target_snapshot: Path,
    output_dir: Path,
    shared_diff: str,
    model: str | None,
    timeout_seconds: int,
) -> dict:
    output_dir.mkdir(parents=True, exist_ok=True)
    budget_script = shared_snapshot / "scripts" / "bootstrap-budget.sh"
    if not budget_script.exists():
        budget_script = fallback_shared_repo / "scripts" / "bootstrap-budget.sh"
    budget = json.loads(
        subprocess.check_output(
            [
                "bash",
                str(budget_script),
                "--repo",
                str(target_snapshot),
                "--json",
            ],
            text=True,
        )
    )

    scenario_results = []
    for scenario in SCENARIOS:
        prompt = scenario["prompt"].format(shared_diff=shared_diff or "No diff provided.")
        scenario_cwd = shared_snapshot if scenario["workspace"] == "shared" else target_snapshot
        result = run_codex_exec(
            label=label,
            scenario_name=scenario["name"],
            prompt=prompt,
            home_dir=home_dir,
            cwd=scenario_cwd,
            output_dir=output_dir,
            search=scenario["search"],
            model=model,
            timeout_seconds=timeout_seconds,
        )
        result["checks"] = evaluate_checks(result["output"], scenario["checks"])
        result["pass"] = all(check["passed"] for check in result["checks"]) and result["returncode"] == 0
        scenario_results.append(result)

    return {
        "label": label,
        "budget": budget,
        "scenarios": scenario_results,
        "pass_count": sum(1 for scenario in scenario_results if scenario["pass"]),
    }


def run_codex_exec(
    label: str,
    scenario_name: str,
    prompt: str,
    home_dir: Path,
    cwd: Path,
    output_dir: Path,
    search: bool,
    model: str | None,
    timeout_seconds: int,
) -> dict:
    stdout_path = output_dir / f"{scenario_name}.stdout.txt"
    message_path = output_dir / f"{scenario_name}.last-message.txt"

    command = ["codex", "--disable", "multi_agent"]
    if search:
        command.append("--search")
    if model:
        command.extend(["-m", model])
    command.extend(
        [
            "-c",
            'model_reasoning_effort="medium"',
            "exec",
            "--skip-git-repo-check",
            "--ephemeral",
            "--color",
            "never",
            "-s",
            "read-only",
            "-C",
            str(cwd),
            "-o",
            str(message_path),
            "-",
        ]
    )

    environment = os.environ.copy()
    environment["HOME"] = str(home_dir)
    environment["CODEX_HOME"] = str(home_dir / ".codex")

    started_at = time.time()
    try:
        completed = subprocess.run(
            command,
            input=prompt,
            text=True,
            capture_output=True,
            env=environment,
            timeout=timeout_seconds,
            check=False,
        )
        timed_out = False
        stdout = completed.stdout
        stderr = completed.stderr
        returncode = completed.returncode
    except subprocess.TimeoutExpired as exc:
        timed_out = True
        stdout = exc.stdout or ""
        stderr = exc.stderr or ""
        returncode = 124

    stdout_path.write_text(stdout, encoding="utf-8")
    output = message_path.read_text(encoding="utf-8") if message_path.exists() else stdout

    warnings = []
    combined = f"{stdout}\n{stderr}"
    for pattern in (
        "failed to install system skills",
        "playwright failed",
        "shell snapshot",
        "slow statement",
    ):
        if pattern in combined:
            warnings.append(pattern)

    return {
        "label": label,
        "scenario": scenario_name,
        "returncode": returncode,
        "timed_out": timed_out,
        "duration_seconds": round(time.time() - started_at, 2),
        "output": output,
        "stdout_path": str(stdout_path),
        "message_path": str(message_path),
        "warnings": warnings,
    }


def evaluate_checks(output: str, checks: list[tuple[str, re.Pattern[str]]]) -> list[dict]:
    return [
        {"name": description, "passed": bool(pattern.search(output))}
        for description, pattern in checks
    ]


def compare_variants(baseline: dict, candidate: dict) -> dict:
    baseline_passes = baseline["pass_count"]
    candidate_passes = candidate["pass_count"]
    return {
        "same_or_better_quality": candidate_passes >= baseline_passes,
        "baseline_pass_count": baseline_passes,
        "candidate_pass_count": candidate_passes,
        "lower_bootstrap_tokens": candidate["budget"]["bootstrap_total"] < baseline["budget"]["bootstrap_total"],
        "baseline_bootstrap_tokens": baseline["budget"]["bootstrap_total"],
        "candidate_bootstrap_tokens": candidate["budget"]["bootstrap_total"],
    }


def run_retrieval_trials(shared_snapshot: Path, target_snapshot: Path, output_dir: Path) -> list[dict]:
    output_dir.mkdir(parents=True, exist_ok=True)
    retrieval_script = shared_snapshot / "scripts" / "rlm_retrieval.py"
    subprocess.check_call(
        ["python3", str(retrieval_script), "build", "--repo", str(shared_snapshot)],
        stdout=subprocess.DEVNULL,
    )
    subprocess.check_call(
        ["python3", str(retrieval_script), "build", "--repo", str(target_snapshot)],
        stdout=subprocess.DEVNULL,
    )

    trials = []

    trials.append(
        run_retrieval_trial(
            name="precise_repo_rule",
            retrieval_script=retrieval_script,
            repo=target_snapshot,
            question="What is the git or PR ticket format rule for this repository?",
            expected_handles={"AGENTS.md"},
            output_dir=output_dir,
        )
    )

    trials.append(
        run_retrieval_trial(
            name="worklog_plus_policy",
            retrieval_script=retrieval_script,
            repo=target_snapshot,
            question="What is the current active goal and when should worklog files be read?",
            expected_handles={"AGENTS.md", ".worklog/current-focus.md"},
            output_dir=output_dir,
        )
    )

    trials.append(
        run_relation_trial(
            name="skill_to_script_to_doc",
            retrieval_script=retrieval_script,
            repo=shared_snapshot,
            handle="agents/skills/playwright/SKILL.md",
            expected_handles={
                "agents/skills/playwright/scripts/playwright_cli.sh",
                "agents/skills/playwright/references/cli.md",
            },
            output_dir=output_dir,
        )
    )

    return trials


def fetch_retrieval_status(retrieval_script: Path, repo: Path) -> dict:
    return json.loads(
        subprocess.check_output(
            ["python3", str(retrieval_script), "status", "--repo", str(repo), "--json"],
            text=True,
        )
    )


def run_retrieval_trial(
    name: str,
    retrieval_script: Path,
    repo: Path,
    question: str,
    expected_handles: set[str],
    output_dir: Path,
) -> dict:
    status = fetch_retrieval_status(retrieval_script, repo)
    session = json.loads(
        subprocess.check_output(
            ["python3", str(retrieval_script), "session-start", "--repo", str(repo), "--json"],
            text=True,
        )
    )
    query_result = json.loads(
        subprocess.check_output(
            [
                "python3",
                str(retrieval_script),
                "query",
                "--repo",
                str(repo),
                "--question",
                question,
                "--limit",
                "6",
                "--session",
                session["session"],
                "--json",
            ],
            text=True,
        )
    )
    handles = {candidate["handle"] for candidate in query_result["candidates"]}
    full_selection = sorted(expected_handles & handles or handles)
    selected_handles = full_selection[:3]
    if selected_handles:
        summarize_command = [
            "python3",
            str(retrieval_script),
            "summarize",
            "--repo",
            str(repo),
        ]
        for handle in selected_handles:
            summarize_command.extend(["--handle", handle])
        summarize_command.extend(
            [
                "--budget",
                "320",
                "--session",
                session["session"],
                "--json",
            ]
        )
        summary = json.loads(
            subprocess.check_output(summarize_command, text=True)
        )
        summary_text = summary["summary"]
    else:
        summary_text = ""
    result = {
        "name": name,
        "question": question,
        "expected_handles": sorted(expected_handles),
        "candidate_handles": sorted(handles),
        "selected_handles": selected_handles,
        "max_selected_handles": 3,
        "retrieval_depth": 1,
        "retrieved_sections": len(query_result["candidates"]),
        "bounded_selection_pass": len(full_selection) <= 3,
        "pass": expected_handles.issubset(handles) and len(full_selection) <= 3,
        "session": session["session"],
        "catalog_status": status,
        "root_metadata": session.get("root_metadata", {}),
        "summary": summary_text,
    }
    (output_dir / f"{name}.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    return result


def run_relation_trial(
    name: str,
    retrieval_script: Path,
    repo: Path,
    handle: str,
    expected_handles: set[str],
    output_dir: Path,
) -> dict:
    status = fetch_retrieval_status(retrieval_script, repo)
    session = json.loads(
        subprocess.check_output(
            ["python3", str(retrieval_script), "session-start", "--repo", str(repo), "--json"],
            text=True,
        )
    )
    expanded = json.loads(
        subprocess.check_output(
            [
                "python3",
                str(retrieval_script),
                "expand",
                "--repo",
                str(repo),
                "--handle",
                handle,
                "--edge-type",
                "references",
                "--depth",
                "1",
                "--limit",
                "12",
                "--session",
                session["session"],
                "--json",
            ],
            text=True,
        )
    )
    handles = {item["handle"] for item in expanded["related"]}
    full_selection = sorted(handles)
    selected_handles = full_selection[:3]
    result = {
        "name": name,
        "handle": handle,
        "expected_handles": sorted(expected_handles),
        "candidate_handles": sorted(handles),
        "selected_handles": selected_handles,
        "max_selected_handles": 3,
        "retrieval_depth": 1,
        "retrieved_sections": len(expanded["related"]),
        "bounded_selection_pass": len(full_selection) <= 3,
        "pass": expected_handles.issubset(handles) and len(full_selection) <= 3,
        "session": session["session"],
        "catalog_status": status,
        "root_metadata": session.get("root_metadata", {}),
    }
    (output_dir / f"{name}.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    return result


def print_summary(result: dict, summary_path: Path) -> None:
    print(f"Summary: {summary_path}")
    print(
        "A/B quality passes:",
        f"baseline={result['comparison']['baseline_pass_count']}",
        f"candidate={result['comparison']['candidate_pass_count']}",
    )
    print(
        "Bootstrap tokens:",
        f"baseline={result['comparison']['baseline_bootstrap_tokens']}",
        f"candidate={result['comparison']['candidate_bootstrap_tokens']}",
    )
    print(
        "Quality same-or-better:",
        "yes" if result["comparison"]["same_or_better_quality"] else "no",
    )
    print(
        "Lower bootstrap:",
        "yes" if result["comparison"]["lower_bootstrap_tokens"] else "no",
    )
    for trial in result["retrieval_trials"]:
        print(f"Retrieval trial {trial['name']}: {'pass' if trial['pass'] else 'fail'}")


if __name__ == "__main__":
    raise SystemExit(main())

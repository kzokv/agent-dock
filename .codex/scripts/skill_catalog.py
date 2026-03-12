#!/usr/bin/env python3
"""Discover installed skills under .codex/skills with nested-path support."""

from __future__ import annotations

from collections import defaultdict
from dataclasses import dataclass
from pathlib import Path
import re


FRONTMATTER_VALUE_RE = r'^{}:\s*["\']?(.+?)["\']?\s*$'


@dataclass(frozen=True)
class SkillEntry:
    skill_id: str
    rel_path: str
    path: Path
    skill_md: Path
    name: str
    description: str
    is_system: bool


class SkillLookupError(ValueError):
    """Raised when a skill id or name cannot be resolved cleanly."""


class SkillCatalog:
    def __init__(self, skills_root: Path, entries: list[SkillEntry]) -> None:
        self.skills_root = skills_root
        self.entries = entries
        self.by_id = {entry.skill_id: entry for entry in entries}
        by_name: dict[str, list[SkillEntry]] = defaultdict(list)
        for entry in entries:
            by_name[entry.name].append(entry)
        self.by_name = dict(by_name)

    def resolve(self, query: str) -> SkillEntry:
        if query in self.by_id:
            return self.by_id[query]

        matches = self.by_name.get(query, [])
        if len(matches) == 1:
            return matches[0]
        if len(matches) > 1:
            ids = ", ".join(sorted(entry.skill_id for entry in matches))
            raise SkillLookupError(f"ambiguous skill reference '{query}' (matches: {ids})")
        raise SkillLookupError(f"unknown skill reference '{query}'")


def parse_frontmatter_value(content: str, key: str) -> str:
    match = re.search(FRONTMATTER_VALUE_RE.format(re.escape(key)), content, flags=re.M)
    if not match:
        return ""
    return match.group(1).strip()


def load_skill_catalog(skills_root: Path) -> SkillCatalog:
    skills_root = skills_root.resolve()
    entries: list[SkillEntry] = []
    for skill_md in sorted(skills_root.rglob("SKILL.md")):
        rel_path = skill_md.parent.relative_to(skills_root).as_posix()
        content = skill_md.read_text(encoding="utf-8")
        name = parse_frontmatter_value(content, "name") or skill_md.parent.name
        description = parse_frontmatter_value(content, "description")
        entries.append(
            SkillEntry(
                skill_id=rel_path,
                rel_path=rel_path,
                path=skill_md.parent,
                skill_md=skill_md,
                name=name,
                description=description,
                is_system=skill_md.parent.relative_to(skills_root).parts[0] == ".system",
            )
        )
    return SkillCatalog(skills_root=skills_root, entries=entries)

#!/usr/bin/env python3
"""Validate canonical role/skill topology and skill metadata hygiene."""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
AGENTS_DIR = ROOT / "agents"
SKILLS_DIR = ROOT / "skills"


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def parse_skill_section(text: str, section: str) -> list[tuple[str, bool, int]]:
    pattern = rf"## {re.escape(section)}\n\n(.*?)(?:\n## |\Z)"
    m = re.search(pattern, text, flags=re.S)
    if not m:
        return []

    out: list[tuple[str, bool, int]] = []
    block = m.group(1)
    for idx, line in enumerate(block.splitlines(), start=1):
        if "`" not in line:
            continue
        external = "(external)" in line
        for skill in re.findall(r"`([^`]+)`", line):
            out.append((skill.strip(), external, idx))
    return out


def parse_canonical_roles() -> tuple[dict[str, Path], list[str]]:
    errors: list[str] = []
    roles: dict[str, Path] = {}
    for path in sorted(AGENTS_DIR.glob("role-*.md")):
        if path.name == "role-topology.md":
            continue
        role_id = path.stem
        if role_id in roles:
            errors.append(f"duplicate canonical role file id: {role_id}")
        roles[role_id] = path
    if len(roles) == 0:
        errors.append("no canonical role files found (agents/role-*.md)")
    return roles, errors


def validate_role_skills(roles: dict[str, Path]) -> list[str]:
    errors: list[str] = []

    for role_id, path in roles.items():
        text = read_text(path)

        required = parse_skill_section(text, "Required Skills")
        optional = parse_skill_section(text, "Optional Skills")

        required_names = [name for name, _, _ in required]
        optional_names = [name for name, _, _ in optional]

        if not required_names:
            errors.append(f"{path}: missing required skills list")

        dup_required = sorted({s for s in required_names if required_names.count(s) > 1})
        for s in dup_required:
            errors.append(f"{path}: duplicate required skill declaration: {s}")

        overlap = sorted(set(required_names) & set(optional_names))
        for s in overlap:
            errors.append(f"{path}: skill declared in both required and optional: {s}")

        for s, external, _ in required:
            if external:
                errors.append(f"{path}: required skill marked external: {s}")
            if not (SKILLS_DIR / s).is_dir():
                errors.append(f"{path}: required skill directory missing: skills/{s}")

        for s, external, _ in optional:
            if external:
                continue
            if not (SKILLS_DIR / s).is_dir():
                errors.append(
                    f"{path}: optional skill missing and not marked external: skills/{s}"
                )

    return errors


def validate_capability_ownership(roles: dict[str, Path]) -> list[str]:
    errors: list[str] = []
    path = AGENTS_DIR / "role-topology.md"
    text = read_text(path)

    m = re.search(
        r"## Capability Ownership \(RACI\)\n\n(.*?)(?:\n## |\Z)",
        text,
        flags=re.S,
    )
    if not m:
        return [f"{path}: missing Capability Ownership (RACI) section"]

    table_block = m.group(1)
    capabilities_seen: set[str] = set()
    parsed_rows = 0

    for raw in table_block.splitlines():
        line = raw.strip()
        if not line.startswith("|"):
            continue
        cols = [c.strip() for c in line.split("|")[1:-1]]
        if len(cols) < 3:
            continue
        if cols[0] == "Capability" or set("".join(cols)) <= {"-", " ", ":"}:
            continue

        parsed_rows += 1
        capability = cols[0]
        owner_col = cols[1]
        owners = re.findall(r"`([^`]+)`", owner_col)

        if capability in capabilities_seen:
            errors.append(f"{path}: duplicate capability row: {capability}")
        capabilities_seen.add(capability)

        if len(owners) != 1:
            errors.append(
                f"{path}: capability must have exactly one primary owner: {capability}"
            )
            continue

        owner = owners[0]
        if owner not in roles:
            errors.append(
                f"{path}: primary owner for '{capability}' is unknown canonical role: {owner}"
            )

    if parsed_rows == 0:
        errors.append(f"{path}: no capability rows parsed")

    return errors


def validate_skill_docs_hygiene() -> list[str]:
    errors: list[str] = []

    for yaml_path in sorted(SKILLS_DIR.glob("*/agents/openai.yaml")):
        for ln, line in enumerate(read_text(yaml_path).splitlines(), start=1):
            stripped = line.strip()
            if not stripped or stripped.startswith("#"):
                continue
            # Simple YAML quote sanity check for common broken-string typo.
            if stripped.count('"') % 2 == 1:
                errors.append(f"{yaml_path}:{ln}: odd number of double quotes")

    for skill_md in sorted(SKILLS_DIR.glob("*/SKILL.md")):
        for ln, line in enumerate(read_text(skill_md).splitlines(), start=1):
            if "skills/skills/" in line:
                errors.append(f"{skill_md}:{ln}: invalid duplicated path prefix: skills/skills/")

    return errors


def main() -> int:
    roles, role_errs = parse_canonical_roles()
    errors: list[str] = []
    errors.extend(role_errs)
    errors.extend(validate_role_skills(roles))
    errors.extend(validate_capability_ownership(roles))
    errors.extend(validate_skill_docs_hygiene())

    if errors:
        print("Validation failed:")
        for err in errors:
            print(f"- {err}")
        return 1

    print("Validation passed")
    print(f"- canonical roles: {len(roles)}")
    print("- required/optional role skill bindings: valid")
    print("- capability ownership table: valid")
    print("- skill metadata/path hygiene: valid")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

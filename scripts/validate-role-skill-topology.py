#!/usr/bin/env python3
"""Validate canonical role/skill topology and skill metadata hygiene."""

from __future__ import annotations

from pathlib import Path

from role_skill_matrix import load_matrix

ROOT = Path(__file__).resolve().parents[1]
AGENTS_DIR = ROOT / "agents"
SKILLS_DIR = AGENTS_DIR / "skills"


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


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


def validate_role_files_point_to_matrix(roles: dict[str, Path]) -> list[str]:
    errors: list[str] = []

    for role_id, path in roles.items():
        text = read_text(path)
        if "## Required Skills" in text or "## Optional Skills" in text:
            errors.append(f"{path}: role file must not define inline required/optional skills")
        if "## Skill Binding" not in text:
            errors.append(f"{path}: missing Skill Binding section")
        if "agents/skills-matrix.md" not in text:
            errors.append(f"{path}: Skill Binding section must point to agents/skills-matrix.md")

    return errors


def validate_matrix_role_bindings(roles: dict[str, Path]) -> list[str]:
    errors: list[str] = []

    try:
        matrix = load_matrix()
    except ValueError as exc:
        return [f"{AGENTS_DIR / 'skills-matrix.md'}: {exc}"]

    matrix_roles = matrix["roles"]
    universal_optional = matrix["universal_optional"]

    unknown_roles = sorted(set(matrix_roles) - set(roles))
    for role_id in unknown_roles:
        errors.append(f"{AGENTS_DIR / 'skills-matrix.md'}: unknown canonical role in matrix: {role_id}")

    missing_roles = sorted(set(roles) - set(matrix_roles))
    for role_id in missing_roles:
        errors.append(f"{AGENTS_DIR / 'skills-matrix.md'}: missing role binding row: {role_id}")

    for skill in universal_optional:
        if not (SKILLS_DIR / skill).is_dir():
            errors.append(
                f"{AGENTS_DIR / 'skills-matrix.md'}: universal optional skill directory missing: agents/skills/{skill}"
            )

    for role_id, binding in matrix_roles.items():
        required_names = binding["required"]
        optional_names = binding["optional"]

        dup_required = sorted({s for s in required_names if required_names.count(s) > 1})
        for skill in dup_required:
            errors.append(
                f"{AGENTS_DIR / 'skills-matrix.md'}: duplicate required skill for {role_id}: {skill}"
            )

        dup_optional = sorted({s for s in optional_names if optional_names.count(s) > 1})
        for skill in dup_optional:
            errors.append(
                f"{AGENTS_DIR / 'skills-matrix.md'}: duplicate optional skill for {role_id}: {skill}"
            )

        overlap = sorted(set(required_names) & set(optional_names))
        for skill in overlap:
            errors.append(
                f"{AGENTS_DIR / 'skills-matrix.md'}: skill declared in both required and optional for {role_id}: {skill}"
            )

        for skill in required_names:
            if not (SKILLS_DIR / skill).is_dir():
                errors.append(
                    f"{AGENTS_DIR / 'skills-matrix.md'}: required skill directory missing for {role_id}: agents/skills/{skill}"
                )
        for skill in optional_names:
            if not (SKILLS_DIR / skill).is_dir():
                errors.append(
                    f"{AGENTS_DIR / 'skills-matrix.md'}: optional skill directory missing for {role_id}: agents/skills/{skill}"
                )

    return errors


def validate_capability_ownership(roles: dict[str, Path]) -> list[str]:
    import re

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


def validate_repo_skill_policy() -> list[str]:
    errors: list[str] = []
    disallowed_repo_skills = ROOT / ".agents" / "skills"
    if disallowed_repo_skills.exists():
        errors.append(
            f"{disallowed_repo_skills}: disallowed in codex-home; use user-level agents/skills instead"
        )
    return errors


def main() -> int:
    roles, role_errs = parse_canonical_roles()
    errors: list[str] = []
    errors.extend(role_errs)
    errors.extend(validate_role_files_point_to_matrix(roles))
    errors.extend(validate_matrix_role_bindings(roles))
    errors.extend(validate_capability_ownership(roles))
    errors.extend(validate_skill_docs_hygiene())
    errors.extend(validate_repo_skill_policy())

    if errors:
        print("Validation failed:")
        for err in errors:
            print(f"- {err}")
        return 1

    print("Validation passed")
    print(f"- canonical roles: {len(roles)}")
    print("- skills matrix bindings: valid")
    print("- role files point to skills matrix: valid")
    print("- capability ownership table: valid")
    print("- skill metadata/path hygiene: valid")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

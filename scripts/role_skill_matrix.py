#!/usr/bin/env python3
"""Parse the canonical role/skill bindings from agents/skills-matrix.md."""

from __future__ import annotations

import argparse
import json
import re
import sys
from collections import OrderedDict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MATRIX_PATH = ROOT / "agents" / "skills-matrix.md"
SKILLS_DIR = ROOT / "agents" / "skills"


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def parse_section(text: str, heading: str) -> str:
    match = re.search(rf"^## {re.escape(heading)}\n(.*?)(?=^## |\Z)", text, flags=re.M | re.S)
    if not match:
        raise ValueError(f"missing section: {heading}")
    return match.group(1)


def parse_skill_list(block: str) -> list[str]:
    return [item.strip() for item in re.findall(r"`([^`]+)`", block)]


def parse_bullets(block: str) -> list[str]:
    out: list[str] = []
    for line in block.splitlines():
        stripped = line.strip()
        if not stripped.startswith("- "):
            continue
        out.extend(parse_skill_list(stripped))
    return out


def parse_role_rows(block: str) -> OrderedDict[str, dict[str, list[str]]]:
    rows: OrderedDict[str, dict[str, list[str]]] = OrderedDict()
    for raw in block.splitlines():
        line = raw.strip()
        if not line.startswith("|"):
            continue
        cols = [col.strip() for col in line.split("|")[1:-1]]
        if len(cols) < 3:
            continue
        if cols[0] == "Role" or set("".join(cols)) <= {"-", " ", ":"}:
            continue
        role = parse_skill_list(cols[0])
        if len(role) != 1:
            raise ValueError(f"invalid role row: {line}")
        role_id = role[0]
        required = parse_skill_list(cols[1]) if cols[1].lower() != "none" else []
        optional = parse_skill_list(cols[2]) if cols[2].lower() != "none" else []
        if role_id in rows:
            raise ValueError(f"duplicate role row: {role_id}")
        rows[role_id] = {"required": required, "optional": optional}
    if not rows:
        raise ValueError("no canonical role rows parsed")
    return rows


def load_matrix() -> dict[str, object]:
    text = read_text(MATRIX_PATH)
    universal = parse_bullets(parse_section(text, "Universal Optional Skills"))
    role_rows = parse_role_rows(parse_section(text, "Canonical Role Skill Bindings"))
    return {
        "path": str(MATRIX_PATH),
        "universal_optional": universal,
        "roles": role_rows,
    }


def unique_ordered(items: list[str]) -> list[str]:
    return list(OrderedDict.fromkeys(items))


def set_required(matrix: dict[str, object]) -> list[str]:
    out: list[str] = []
    roles = matrix["roles"]
    assert isinstance(roles, OrderedDict)
    for payload in roles.values():
        out.extend(payload["required"])
    return unique_ordered(out)


def set_enabled(matrix: dict[str, object]) -> list[str]:
    return unique_ordered(set_required(matrix) + list(matrix["universal_optional"]))


def validate_local_skills(skills: list[str]) -> list[str]:
    missing = []
    for skill in skills:
        if not (SKILLS_DIR / skill).is_dir():
            missing.append(skill)
    return missing


def main() -> int:
    parser = argparse.ArgumentParser(description="Read canonical role/skill bindings")
    parser.add_argument(
        "--set",
        choices=("required", "enabled", "universal"),
        help="Emit one skill id per line for the requested set",
    )
    parser.add_argument("--json", action="store_true", help="Emit JSON")
    parser.add_argument(
        "--validate-local-skills",
        action="store_true",
        help="Fail if any emitted skill or matrix-referenced skill is missing locally",
    )
    args = parser.parse_args()

    try:
        matrix = load_matrix()
    except ValueError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1

    if args.set == "required":
        payload: object = set_required(matrix)
    elif args.set == "enabled":
        payload = set_enabled(matrix)
    elif args.set == "universal":
        payload = matrix["universal_optional"]
    else:
        payload = matrix

    if args.validate_local_skills:
        skills_to_check: list[str]
        if isinstance(payload, list):
            skills_to_check = payload
        else:
            role_skills = []
            roles = matrix["roles"]
            assert isinstance(roles, OrderedDict)
            for role_data in roles.values():
                role_skills.extend(role_data["required"])
                role_skills.extend(role_data["optional"])
            role_skills.extend(matrix["universal_optional"])
            skills_to_check = unique_ordered(role_skills)
        missing = validate_local_skills(skills_to_check)
        if missing:
            print("ERROR: missing local skills: " + ", ".join(missing), file=sys.stderr)
            return 1

    if args.json:
        json.dump(payload, sys.stdout, indent=2)
        sys.stdout.write("\n")
    elif isinstance(payload, list):
        for item in payload:
            print(item)
    else:
        json.dump(payload, sys.stdout, indent=2)
        sys.stdout.write("\n")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())

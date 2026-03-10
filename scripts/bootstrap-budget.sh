#!/usr/bin/env bash
set -euo pipefail

SCRIPT_PATH="${0##*/}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_ROOT="$(pwd)"
MAX_BOOTSTRAP_TOKENS=""
MAX_SESSION_TOKENS=""
OUTPUT_JSON=0

print_help() {
  cat <<EOF_HELP
Description:
  Report approximate fresh-session bootstrap cost for the shared codex-home policy, the
  active repository policy, enabled user skills, system skills, repo-local skills, and
  optional worklog files. Token estimates use chars/4 and normalized skill paths to stay
  stable across runs.

Usage: ${SCRIPT_PATH} [OPTIONS]

Options:
  --repo PATH                  Repository to inspect for local AGENTS, repo skills, and worklog files (default: current directory)
  --max-bootstrap-tokens N     Fail if shared bootstrap sources exceed N approximate tokens
  --max-session-tokens N       Fail if bootstrap + optional worklog sources exceed N approximate tokens
  --json                       Emit machine-readable JSON
  -h, --help                   Show this help message and exit
EOF_HELP
}

while [ $# -gt 0 ]; do
  case "$1" in
    --repo)
      shift
      [ $# -gt 0 ] || { print_help; exit 1; }
      PROJECT_ROOT="$1"
      shift
      ;;
    --repo=*)
      PROJECT_ROOT="${1#*=}"
      shift
      ;;
    --max-bootstrap-tokens)
      shift
      [ $# -gt 0 ] || { print_help; exit 1; }
      MAX_BOOTSTRAP_TOKENS="$1"
      shift
      ;;
    --max-bootstrap-tokens=*)
      MAX_BOOTSTRAP_TOKENS="${1#*=}"
      shift
      ;;
    --max-session-tokens)
      shift
      [ $# -gt 0 ] || { print_help; exit 1; }
      MAX_SESSION_TOKENS="$1"
      shift
      ;;
    --max-session-tokens=*)
      MAX_SESSION_TOKENS="${1#*=}"
      shift
      ;;
    --json)
      OUTPUT_JSON=1
      shift
      ;;
    -h|--help)
      print_help
      exit 0
      ;;
    *)
      printf 'ERROR: Unknown argument %s\n' "$1" >&2
      print_help
      exit 1
      ;;
  esac
done

node - "$REPO_ROOT" "$PROJECT_ROOT" "$MAX_BOOTSTRAP_TOKENS" "$MAX_SESSION_TOKENS" "$OUTPUT_JSON" <<'NODE'
const fs = require("fs");
const path = require("path");
const { execFileSync } = require("child_process");

const [repoRoot, projectRootInput, maxBootstrapInput, maxSessionInput, outputJsonInput] = process.argv.slice(2);
const projectRoot = path.resolve(projectRootInput);
const outputJson = outputJsonInput === "1";

function approxTokens(chars) {
  return Math.ceil(chars / 4);
}

function readIfExists(filePath) {
  if (!fs.existsSync(filePath)) return null;
  return fs.readFileSync(filePath, "utf8");
}

function canonical(filePath) {
  try {
    return fs.realpathSync(filePath);
  } catch {
    return path.resolve(filePath);
  }
}

function parseFrontmatterValue(content, key) {
  const match = content.match(new RegExp(`^${key}:\\s*(.+)$`, "m"));
  if (!match) return "";
  return match[1].trim().replace(/^['"]|['"]$/g, "");
}

function makeSkillPromptLine(name, description, filePath) {
  return `- ${name}: ${description} (file: ${filePath})`;
}

function collectSkillPromptLines(skillRoots, pathBuilder) {
  const rows = [];
  for (const root of skillRoots) {
    if (!fs.existsSync(root)) continue;
    for (const entry of fs.readdirSync(root, { withFileTypes: true })) {
      if (!entry.isDirectory()) continue;
      const skillDir = path.join(root, entry.name);
      const skillMd = path.join(skillDir, "SKILL.md");
      if (!fs.existsSync(skillMd)) continue;
      const content = fs.readFileSync(skillMd, "utf8");
      const name = parseFrontmatterValue(content, "name") || entry.name;
      const description = parseFrontmatterValue(content, "description");
      rows.push(makeSkillPromptLine(name, description, pathBuilder(entry.name, name)));
    }
  }
  return rows;
}

function collectEnabledUserSkillLines() {
  const parserPath = path.join(repoRoot, "scripts/role_skill_matrix.py");
  if (!fs.existsSync(parserPath)) return [];
  const names = execFileSync("python3", [parserPath, "--set", "enabled"], { encoding: "utf8" })
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter(Boolean);
  const rows = [];
  for (const name of names) {
    const skillMd = path.join(repoRoot, "agents/skills", name, "SKILL.md");
    const skillContent = readIfExists(skillMd);
    if (!skillContent) continue;
    const skillName = parseFrontmatterValue(skillContent, "name") || name;
    const description = parseFrontmatterValue(skillContent, "description");
    rows.push(makeSkillPromptLine(skillName, description, `~/.codex/agents/skills/${name}/SKILL.md`));
  }
  return rows;
}

function measureText(label, text, optional = false) {
  const chars = text.length;
  return { label, chars, tokens: approxTokens(chars), optional };
}

const sections = [];

const sharedAgentsPath = path.join(repoRoot, "AGENTS.md");
const sharedAgents = readIfExists(sharedAgentsPath);
if (sharedAgents) sections.push({ key: "shared_agents", ...measureText("shared AGENTS", sharedAgents) });

const repoAgentsPath = path.join(projectRoot, "AGENTS.md");
if (fs.existsSync(repoAgentsPath) && canonical(repoAgentsPath) !== canonical(sharedAgentsPath)) {
  sections.push({ key: "repo_agents", ...measureText("repo AGENTS", fs.readFileSync(repoAgentsPath, "utf8")) });
}

const enabledUserSkillLines = collectEnabledUserSkillLines();
sections.push({
  key: "enabled_user_skills",
  item_count: enabledUserSkillLines.length,
  ...measureText(`enabled user skills (${enabledUserSkillLines.length})`, enabledUserSkillLines.join("\n")),
});

const systemSkillLines = collectSkillPromptLines(
  [path.join(repoRoot, "skills/.system")],
  (entryName) => `~/.codex/skills/.system/${entryName}/SKILL.md`
);
sections.push({
  key: "system_skills",
  item_count: systemSkillLines.length,
  ...measureText(`system skills (${systemSkillLines.length})`, systemSkillLines.join("\n")),
});

const repoSkillLines = collectSkillPromptLines(
  [path.join(projectRoot, ".agents/skills")],
  (entryName) => `<repo>/.agents/skills/${entryName}/SKILL.md`
);
if (repoSkillLines.length > 0) {
  sections.push({
    key: "repo_skills",
    item_count: repoSkillLines.length,
    ...measureText(`repo skills (${repoSkillLines.length})`, repoSkillLines.join("\n")),
  });
}

const worklogFiles = [
  path.join(projectRoot, ".worklog/latest-handoff.md"),
  path.join(projectRoot, ".worklog/current-focus.md"),
  path.join(projectRoot, ".worklog/open-questions.md"),
];

let worklogChars = 0;
for (const worklogFile of worklogFiles) {
  const content = readIfExists(worklogFile);
  if (!content) continue;
  worklogChars += content.length;
}
if (worklogChars > 0) {
  sections.push({
    key: "optional_worklog",
    label: "optional worklog",
    chars: worklogChars,
    tokens: approxTokens(worklogChars),
    optional: true,
  });
}

const bootstrapTotal = sections.filter((section) => !section.optional).reduce((sum, section) => sum + section.tokens, 0);
const sessionTotal = sections.reduce((sum, section) => sum + section.tokens, 0);

const labelWidth = Math.max(...sections.map((section) => section.label.length), "total bootstrap".length, "total with worklog".length);

function printRow(label, chars, tokens) {
  console.log(`${label.padEnd(labelWidth)}  ${String(chars).padStart(6)} chars  ${String(tokens).padStart(5)} tokens`);
}

const maxBootstrap = maxBootstrapInput ? Number(maxBootstrapInput) : null;
const maxSession = maxSessionInput ? Number(maxSessionInput) : null;
const budget = {
  repo_root: repoRoot,
  project_root: projectRoot,
  path_mode: "normalized",
  sections,
  bootstrap_total: bootstrapTotal,
  session_total: sessionTotal,
  thresholds: {
    max_bootstrap_tokens: maxBootstrap,
    max_session_tokens: maxSession,
  },
};

if (outputJson) {
  process.stdout.write(`${JSON.stringify(budget, null, 2)}\n`);
} else {
  console.log(`Bootstrap budget for ${projectRoot}`);
  for (const section of sections) {
    printRow(section.label, section.chars, section.tokens);
  }
  printRow("total bootstrap", 0, bootstrapTotal);
  printRow("total with worklog", 0, sessionTotal);
}

if (maxBootstrap !== null && bootstrapTotal > maxBootstrap) {
  console.error(`Bootstrap token budget exceeded: ${bootstrapTotal} > ${maxBootstrap}`);
  process.exit(1);
}

if (maxSession !== null && sessionTotal > maxSession) {
  console.error(`Session token budget exceeded: ${sessionTotal} > ${maxSession}`);
  process.exit(1);
}
NODE

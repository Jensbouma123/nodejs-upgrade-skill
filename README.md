# Node.js Runtime Upgrade Skill

A custom AI agent skill that safely upgrades Node.js projects from any outdated version to the latest stable LTS. Works with **any AI coding agent**.

## What it does

When triggered, the skill guides the agent through a structured upgrade process:

1. **Discovery** — runs a scanner that detects every version reference, framework, native addon, deprecated API, and removable polyfill in the project
2. **Risk assessment** — classifies all dependencies and maps breaking changes for the specific version jump
3. **Preparation** — makes backward-compatible changes that work on the current Node version
4. **Version bump** — updates all version declarations and does a clean install
5. **Fix & adapt** — systematically resolves build/test failures
6. **Validation** — runs full test suite, performance checks, and deployment verification
7. **Cleanup** — removes dead polyfills, old version guards, and documents the change

It dynamically resolves the target version (no hardcoded versions), references breaking changes from a curated reference table, and includes a pre-flight scanner script that does deterministic work so the agent spends tokens on reasoning, not grep commands.

## Supported agents

| Agent | Install method | File created |
|-------|---------------|--------------|
| **Claude Code** | `.claude/skills/` directory | `SKILL.md` (with frontmatter) |
| **GitHub Copilot** | `.github/instructions/` directory | `.instructions.md` |
| **Cursor** | `.cursor/rules/` directory | `.mdc` rule file |
| **Windsurf** | `.windsurf/rules/` directory | `.md` rule file |
| **OpenAI Codex** | Project root | `AGENTS.md` |
| **Google Gemini** | Project root | `GEMINI.md` |
| **Cline** | `.clinerules/` directory | `.md` rule file |
| **Aider** | Project root + config | `CONVENTIONS.md` |
| **Amazon Q** | `.amazonq/rules/` directory | `.md` rule file |

## Installation

### Option 1: `npx skills add` (easiest)

The fastest way to install — works with 40+ AI coding agents automatically:

```bash
cd your-project/
npx skills add jensbouma/nodejs-upgrade-skill
```

This detects which agents you use and installs the skill in the correct format for each one. You can also target specific agents:

```bash
# Install for specific agents only
npx skills add jensbouma/nodejs-upgrade-skill -a claude-code -a cursor

# Non-interactive (CI/CD friendly)
npx skills add jensbouma/nodejs-upgrade-skill -y
```

### Option 2: Setup script (interactive)

Clone this repo, then run the setup script in your target project:

```bash
git clone https://github.com/jensbouma/nodejs-upgrade-skill /tmp/nodejs-upgrade-skill
cd your-project/
bash /tmp/nodejs-upgrade-skill/scripts/setup.sh
```

The script asks which agent(s) you use and installs the skill in the correct format.

```bash
# Or install for a specific agent directly
bash /tmp/nodejs-upgrade-skill/scripts/setup.sh --agent claude
bash /tmp/nodejs-upgrade-skill/scripts/setup.sh --agent cursor
bash /tmp/nodejs-upgrade-skill/scripts/setup.sh --all
```

### Option 3: Git clone (Claude Code)

Clone directly into your skills directory:

```bash
# Project-level (shared with team)
mkdir -p .claude/skills
git clone https://github.com/jensbouma/nodejs-upgrade-skill .claude/skills/nodejs-upgrade-skill

# Or user-level (all your projects)
mkdir -p ~/.claude/skills
git clone https://github.com/jensbouma/nodejs-upgrade-skill ~/.claude/skills/nodejs-upgrade-skill
```

### Option 4: Manual

Copy the content of `SKILL.md` (without the YAML frontmatter between `---` lines) into the appropriate file for your agent. See the supported agents table above for file paths.

## Usage

Once installed, trigger the skill by asking your agent to upgrade Node.js:

```
Upgrade this project to the latest Node.js LTS
Migrate from Node 18 to Node 22
Check if this project is ready for Node 24
Fix Node.js EOL warnings in this repo
Our CI is failing because Node 16 is EOL
```

### Pre-flight scanner

Run the scanner independently to get a quick overview before starting an upgrade:

```bash
bash scripts/scan-node-version.sh /path/to/your/project
```

The scanner detects: version declarations, Docker/CI/serverless references, frameworks, test runners, build tools, ORMs, native addons, deprecated APIs, removable polyfills, and module system.

## Project structure

```
nodejs-upgrade-skill/
  SKILL.md                        # Skill definition (core prompt)
  references/
    REFERENCES.md                 # Breaking changes by version jump
    EXAMPLE_REPORT.md             # Example upgrade report output
  scripts/
    scan-node-version.sh          # Pre-flight scanner
    setup.sh                      # Multi-agent installer
```

## Updating

```bash
cd .claude/skills/nodejs-upgrade-skill   # or wherever you cloned it
git pull
```

For non-Claude agents, re-run the setup script after pulling updates.

## Customization

- **Add breaking changes**: Edit `references/REFERENCES.md` to add entries for newer Node.js versions or project-specific packages
- **Extend the scanner**: Add checks to `scripts/scan-node-version.sh` for project-specific patterns
- **Adjust triggers**: Edit the `description` field in `SKILL.md` frontmatter to change when the skill activates

## Requirements

- Any supported AI coding agent (see table above)
- `curl` (for fetching live release data)
- `bash` (for the scanner and setup scripts)

## License

MIT

# Node.js Runtime Upgrade Skill

A [Claude Code](https://docs.anthropic.com/en/docs/claude-code) custom skill that safely upgrades Node.js projects from any outdated version to the latest stable LTS.

## What it does

When triggered, the skill guides the agent through a structured 7-phase upgrade process:

1. **Discovery** — scans every version reference (`.nvmrc`, `Dockerfile`, CI/CD, serverless configs, etc.)
2. **Risk assessment** — classifies all dependencies and maps breaking changes for the specific version jump
3. **Preparation** — makes backward-compatible changes that work on the current Node version
4. **Version bump** — updates all version declarations and does a clean install
5. **Fix & adapt** — systematically resolves build/test failures
6. **Validation** — runs full test suite, performance checks, and deployment verification
7. **Cleanup** — removes dead polyfills, old version guards, and documents the change

It dynamically resolves the target version (no hardcoded versions), references breaking changes from a curated reference table, and includes a pre-flight scanner script.

## Installation

### Option 1: Add as a project skill (recommended)

Clone this repo into your project's `.claude/skills/` directory:

```bash
cd your-project/
mkdir -p .claude/skills
git clone https://github.com/YOUR_USERNAME/nodejs-upgrade-skill .claude/skills/nodejs-upgrade-skill
```

Claude Code will automatically discover `SKILL.md` inside `.claude/skills/`.

### Option 2: Add as a user-level skill (available across all projects)

```bash
mkdir -p ~/.claude/skills
git clone https://github.com/YOUR_USERNAME/nodejs-upgrade-skill ~/.claude/skills/nodejs-upgrade-skill
```

### Option 3: Reference via `settings.json`

Add the skill path to your Claude Code settings (`~/.claude/settings.json` or `.claude/settings.json` in your project):

```json
{
  "skills": [
    "/absolute/path/to/nodejs-upgrade-skill/SKILL.md"
  ]
}
```

## Usage

Once installed, trigger the skill by asking Claude Code to upgrade Node.js:

```
> Upgrade this project to the latest Node.js LTS
> Migrate from Node 18 to Node 22
> Check if this project is ready for Node 24
> Fix Node.js EOL warnings in this repo
```

The skill triggers automatically when you mention Node.js upgrades, migrations, EOL, version bumps, or engine compatibility.

### Pre-flight scanner

You can also run the included scanner script independently to get a quick overview of all Node.js version references and potential issues in a project:

```bash
bash /path/to/nodejs-upgrade-skill/scripts/scan-node-version.sh /path/to/your/project
```

## Project structure

```
nodejs-upgrade-skill/
  SKILL.md              # The skill definition (core prompt)
  references/
    REFERENCES.md       # Breaking changes lookup table by version jump
  scripts/
    scan-node-version.sh  # Pre-flight scanner for version references & issues
```

## Customization

- **Add breaking changes**: Edit `references/REFERENCES.md` to add entries for newer Node.js versions or project-specific packages.
- **Extend the scanner**: Add checks to `scripts/scan-node-version.sh` for project-specific patterns.
- **Adjust triggers**: Edit the `description` field in `SKILL.md` frontmatter to change when the skill activates.

## Requirements

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI, desktop app, or IDE extension
- `curl` (used by the scanner and skill to fetch live release data)
- `bash` (for the scanner script)

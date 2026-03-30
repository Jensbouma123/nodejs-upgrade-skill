#!/usr/bin/env bash
# scan-node-version.sh — Pre-flight scanner for Node.js upgrade skill
# Scans a project directory and reports all Node.js version references,
# native addons, deprecated patterns, polyfills, tooling, and frameworks.
#
# Usage: bash scripts/scan-node-version.sh [project-root]
# Default project-root is current directory.
#
# This script does the deterministic discovery work so the AI agent
# can focus on reasoning about the upgrade strategy, not grep commands.

set -euo pipefail

PROJECT_ROOT="${1:-.}"
YELLOW='\033[1;33m'
RED='\033[1;31m'
GREEN='\033[1;32m'
CYAN='\033[1;36m'
NC='\033[0m'

header() { echo -e "\n${CYAN}══════════════════════════════════════════════════${NC}"; echo -e "${CYAN}  $1${NC}"; echo -e "${CYAN}══════════════════════════════════════════════════${NC}"; }
warn()   { echo -e "  ${YELLOW}⚠ $1${NC}"; }
err()    { echo -e "  ${RED}✗ $1${NC}"; }
ok()     { echo -e "  ${GREEN}✓ $1${NC}"; }
info()   { echo -e "  → $1"; }

cd "$PROJECT_ROOT"

# Helper: search source files (excludes node_modules, build dirs)
search_src() {
  local pattern="$1"
  local label="$2"
  local results
  results=$(grep -rnl --include='*.js' --include='*.mjs' --include='*.cjs' --include='*.ts' --include='*.mts' --include='*.cts' --include='*.jsx' --include='*.tsx' \
    --exclude-dir=node_modules --exclude-dir=.next --exclude-dir=dist --exclude-dir=build --exclude-dir=.git --exclude-dir=coverage \
    "$pattern" . 2>/dev/null | head -10 || true)
  if [ -n "$results" ]; then
    warn "$label:"
    echo "$results" | sed 's/^/      /'
  fi
}

# Helper: check if package exists in package.json deps
has_pkg() {
  [ -f package.json ] && grep -q "\"$1\"" package.json 2>/dev/null
}

# ─── Current Node version ────────────────────────────────────────────
header "Current Node.js Version"
if command -v node &>/dev/null; then
  info "System Node: $(node --version)"
else
  warn "Node.js not found in PATH"
fi

# ─── Fetch current release landscape ────────────────────────────────
header "Node.js Release Landscape (live)"
if command -v curl &>/dev/null; then
  eol_data=$(curl -sf "https://endoflife.date/api/nodejs.json" 2>/dev/null || true)
  if [ -n "$eol_data" ]; then
    echo "$eol_data" | grep -oE '"cycle":"[^"]+"|"lts":"[^"]+"|"eol":"[^"]+"|"latest":"[^"]+"' | head -20 | sed 's/^/      /'
    echo ""
    info "Full schedule: https://endoflife.date/nodejs"
  else
    warn "endoflife.date unreachable — trying fallback (nodejs.org/dist)"
    dist_data=$(curl -sf "https://nodejs.org/dist/index.json" 2>/dev/null || true)
    if [ -n "$dist_data" ]; then
      echo "$dist_data" | grep -oE '"version":"[^"]+"|"lts":[^,}]+' | head -20 | sed 's/^/      /'
      echo ""
      info "Cross-reference with: https://nodejs.org/en/about/previous-releases"
    else
      warn "Could not fetch release data — check https://endoflife.date/nodejs manually"
    fi
  fi
else
  warn "curl not available — check https://endoflife.date/nodejs manually"
fi

# ─── Version declaration files ───────────────────────────────────────
header "Version Declaration Files"

for f in .nvmrc .node-version; do
  if [ -f "$f" ]; then
    info "$f: $(cat "$f" | tr -d '[:space:]')"
  fi
done

if [ -f .tool-versions ]; then
  node_line=$(grep -iE '^nodejs\s' .tool-versions 2>/dev/null || true)
  if [ -n "$node_line" ]; then
    info ".tool-versions: $node_line"
  else
    info ".tool-versions: found but no nodejs entry"
  fi
fi

if [ -f package.json ]; then
  engines=$(grep -o '"node"[[:space:]]*:[[:space:]]*"[^"]*"' package.json 2>/dev/null || true)
  [ -n "$engines" ] && info "package.json engines: $engines"

  volta=$(grep -A2 '"volta"' package.json 2>/dev/null | grep '"node"' || true)
  [ -n "$volta" ] && info "Volta pin: $volta"
fi

# ─── Docker ──────────────────────────────────────────────────────────
header "Docker Node References"
find . -maxdepth 5 \( -name 'Dockerfile*' -o -name 'docker-compose*.yml' -o -name 'docker-compose*.yaml' \) 2>/dev/null | while read -r f; do
  matches=$(grep -inE 'node:[0-9]|nodejs[0-9]' "$f" 2>/dev/null || true)
  if [ -n "$matches" ]; then
    info "$f:"
    echo "$matches" | sed 's/^/      /'
  fi
done

# ─── CI/CD ───────────────────────────────────────────────────────────
header "CI/CD Node References"
ci_files=$(find . -maxdepth 4 \( \
  -path './.github/workflows/*.yml' -o \
  -path './.github/workflows/*.yaml' -o \
  -name '.gitlab-ci.yml' -o \
  -name 'Jenkinsfile' -o \
  -name 'bitbucket-pipelines.yml' -o \
  -name '.circleci/config.yml' -o \
  -name 'azure-pipelines.yml' \
  \) 2>/dev/null || true)

if [ -n "$ci_files" ]; then
  echo "$ci_files" | while read -r f; do
    matches=$(grep -inE 'node.version|node-version|nodejs|node:[0-9]|setup-node' "$f" 2>/dev/null || true)
    if [ -n "$matches" ]; then
      info "$f:"
      echo "$matches" | sed 's/^/      /'
    fi
  done
else
  warn "No CI/CD config files found"
fi

# ─── Serverless / Cloud ─────────────────────────────────────────────
header "Serverless / Cloud Function References"
for f in serverless.yml serverless.yaml template.yaml template.yml cdk.json vercel.json netlify.toml fly.toml render.yaml; do
  if [ -f "$f" ]; then
    matches=$(grep -inE 'nodejs|node.*runtime|NODE_VERSION' "$f" 2>/dev/null || true)
    if [ -n "$matches" ]; then
      info "$f:"
      echo "$matches" | sed 's/^/      /'
    fi
  fi
done

tf_files=$(find . -maxdepth 5 -name '*.tf' 2>/dev/null || true)
if [ -n "$tf_files" ]; then
  echo "$tf_files" | while read -r f; do
    matches=$(grep -inE 'nodejs[0-9]' "$f" 2>/dev/null || true)
    if [ -n "$matches" ]; then
      info "$f:"
      echo "$matches" | sed 's/^/      /'
    fi
  done
fi

# ─── Project Tooling (so the agent doesn't have to search) ──────────
header "Project Tooling"

# Package manager
[ -f package-lock.json ] && info "Package manager: npm"
[ -f yarn.lock ]         && info "Package manager: Yarn"
[ -f pnpm-lock.yaml ]    && info "Package manager: pnpm"
[ -f bun.lockb ]         && info "Package manager: Bun"
[ -f .npmrc ]            && info ".npmrc: $(cat .npmrc | tr '\n' ' ')"

# Module system
if [ -f package.json ]; then
  type_field=$(grep -oP '"type"\s*:\s*"\K[^"]+' package.json 2>/dev/null || true)
  if [ -n "$type_field" ]; then
    info "Module system: $type_field"
  else
    info "Module system: commonjs (default)"
  fi
fi
cjs_count=$(find . -maxdepth 5 -name '*.cjs' -not -path '*/node_modules/*' 2>/dev/null | wc -l | tr -d ' ')
mjs_count=$(find . -maxdepth 5 -name '*.mjs' -not -path '*/node_modules/*' 2>/dev/null | wc -l | tr -d ' ')
[ "$cjs_count" -gt 0 ] && info "Explicit .cjs files: $cjs_count"
[ "$mjs_count" -gt 0 ] && info "Explicit .mjs files: $mjs_count"

# Frameworks
for pkg in express fastify next nuxt remix @nestjs/core hono koa @hapi/hapi; do
  has_pkg "$pkg" && info "Framework: $pkg"
done

# Test runners
for pkg in jest vitest mocha ava @playwright/test cypress; do
  has_pkg "$pkg" && info "Test runner: $pkg"
done

# Build tools
for pkg in webpack vite esbuild rollup turbo @swc/core tsup; do
  has_pkg "$pkg" && info "Build tool: $pkg"
done

# ORMs / DB drivers
for pkg in prisma drizzle-orm typeorm sequelize mongoose pg mysql2 better-sqlite3 @neondatabase/serverless; do
  has_pkg "$pkg" && info "Database: $pkg"
done

# TypeScript
has_pkg "typescript" && info "TypeScript: yes"
for pkg in tsx ts-node; do
  has_pkg "$pkg" && info "TS runner: $pkg"
done

# Monorepo
for pkg in nx turbo lerna; do
  has_pkg "$pkg" && info "Monorepo tool: $pkg"
done
[ -f package.json ] && grep -q '"workspaces"' package.json 2>/dev/null && info "Monorepo: workspaces enabled"

# ─── Native Addons ──────────────────────────────────────────────────
header "Native / C++ Addons"
if [ -f package.json ]; then
  native_pkgs="bcrypt better-sqlite3 canvas sharp node-sass grpc leveldown farmhash dtrace-provider sqlite3 fsevents node-canvas cpu-features bufferutil utf-8-validate"
  for pkg in $native_pkgs; do
    has_pkg "$pkg" && warn "Native addon: $pkg"
  done

  if [ -d node_modules ]; then
    gyp_count=$(find node_modules -maxdepth 3 -name 'binding.gyp' 2>/dev/null | wc -l | tr -d ' ')
    if [ "$gyp_count" -gt 0 ]; then
      warn "Found $gyp_count packages with binding.gyp:"
      find node_modules -maxdepth 3 -name 'binding.gyp' 2>/dev/null | sed 's|node_modules/||;s|/binding.gyp||' | sed 's/^/      /'
    fi
  fi
fi

# ─── Deprecated APIs & Patterns ─────────────────────────────────────
header "Deprecated API Usage"
search_src 'url\.parse(' "url.parse() — use new URL()"
search_src "require('punycode')" "punycode — removed in Node 22"
search_src 'require("punycode")' "punycode — removed in Node 22"
search_src 'SlowBuffer' "SlowBuffer — deprecated"
search_src "require('domain')" "domain module — deprecated"
search_src 'require("domain")' "domain module — deprecated"
search_src "require('sys')" "sys module — removed"
search_src 'new Buffer(' "Buffer() constructor — use Buffer.from()/alloc()"
search_src 'Buffer(' "Buffer() without new — removed"
search_src "import.*assert.*{" "import assertions — use 'with' syntax (Node 22+)"
search_src 'createCipher(' "crypto.createCipher — use createCipheriv"
search_src 'createDecipher(' "crypto.createDecipher — use createDecipheriv"
search_src '--harmony' "--harmony flags — likely unnecessary on modern Node"
search_src '--openssl-legacy-provider' "--openssl-legacy-provider workaround"
search_src 'NODE_OPTIONS' "NODE_OPTIONS env var — check for version-specific flags"

# ─── Removable Polyfills ────────────────────────────────────────────
header "Potentially Removable Polyfills"
if [ -f package.json ]; then
  # Native since Node 16
  has_pkg "abort-controller" && warn "abort-controller — native since Node 16"
  has_pkg "abortcontroller-polyfill" && warn "abortcontroller-polyfill — native since Node 16"

  # Native since Node 18
  for pkg in node-fetch form-data web-streams-polyfill blob-polyfill whatwg-url isomorphic-fetch cross-fetch; do
    has_pkg "$pkg" && warn "$pkg — native since Node 18"
  done
  has_pkg "structured-clone" && warn "structured-clone — native since Node 17"
  has_pkg "webcrypto" && warn "webcrypto — native since Node 19"

  # Native since Node 22
  has_pkg "glob" && warn "glob — fs.glob() available since Node 22"
  has_pkg "fast-glob" && warn "fast-glob — fs.glob() available since Node 22"
  has_pkg "nodemon" && warn "nodemon — node --watch stable since Node 22"
  has_pkg "ws" && warn "ws — WebSocket global available since Node 22 (check if client-only usage)"
fi

# ─── Summary ─────────────────────────────────────────────────────────
header "Scan Complete"
echo -e "  All findings above are pre-computed. Use them to build your upgrade plan."
echo -e "  Run this script again after the upgrade to verify all references are updated."
echo ""

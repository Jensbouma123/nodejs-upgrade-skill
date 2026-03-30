#!/usr/bin/env bash
# scan-node-version.sh — Pre-flight scanner for Node.js upgrade skill
# Scans a project directory and reports all Node.js version references,
# native addons, deprecated patterns, and polyfills that can be removed.
#
# Usage: bash scripts/scan-node-version.sh [project-root]
# Default project-root is current directory.
#
# This script is version-agnostic — it reports what it finds
# and the agent determines relevance based on the target version.

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
    # Show active and maintenance LTS versions
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
  if [ -n "$engines" ]; then
    info "package.json engines: $engines"
  fi

  volta=$(grep -A2 '"volta"' package.json 2>/dev/null | grep '"node"' || true)
  if [ -n "$volta" ]; then
    info "Volta pin: $volta"
  fi
fi

# ─── Docker ──────────────────────────────────────────────────────────
header "Docker Node References"
find . -maxdepth 5 -name 'Dockerfile*' -o -name 'docker-compose*.yml' -o -name 'docker-compose*.yaml' 2>/dev/null | while read -r f; do
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

# Also search Terraform files
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

# ─── Native Addons ──────────────────────────────────────────────────
header "Native / C++ Addons"
if [ -f package.json ]; then
  # Check for known native addon packages
  native_pkgs="bcrypt better-sqlite3 canvas sharp node-sass grpc leveldown farmhash dtrace-provider sqlite3 fsevents node-canvas cpu-features bufferutil utf-8-validate"
  for pkg in $native_pkgs; do
    if grep -q "\"$pkg\"" package.json 2>/dev/null; then
      warn "Native addon found: $pkg"
    fi
  done

  # Check for node-gyp in any dependency
  if [ -d node_modules ]; then
    gyp_count=$(find node_modules -maxdepth 3 -name 'binding.gyp' 2>/dev/null | wc -l | tr -d ' ')
    if [ "$gyp_count" -gt 0 ]; then
      warn "Found $gyp_count packages with binding.gyp (native addons):"
      find node_modules -maxdepth 3 -name 'binding.gyp' 2>/dev/null | sed 's|node_modules/||;s|/binding.gyp||' | sed 's/^/      /'
    fi
  fi
fi

# ─── Deprecated APIs & Patterns ─────────────────────────────────────
header "Deprecated API Usage"

# Search source files (not node_modules)
src_pattern="*.js *.mjs *.cjs *.ts *.mts *.cts *.jsx *.tsx"
search_src() {
  local pattern="$1"
  local label="$2"
  local results=$(grep -rnl --include='*.js' --include='*.mjs' --include='*.cjs' --include='*.ts' --include='*.mts' --include='*.cts' --include='*.jsx' --include='*.tsx' \
    --exclude-dir=node_modules --exclude-dir=.next --exclude-dir=dist --exclude-dir=build --exclude-dir=.git --exclude-dir=coverage \
    "$pattern" . 2>/dev/null | head -10 || true)
  if [ -n "$results" ]; then
    warn "$label:"
    echo "$results" | sed 's/^/      /'
  fi
}

search_src 'url\.parse(' "url.parse() — deprecated, use new URL()"
search_src "require('punycode')" "punycode — removed from globals in Node 22"
search_src 'require("punycode")' "punycode — removed from globals in Node 22"
search_src 'SlowBuffer' "SlowBuffer — deprecated"
search_src "require('domain')" "domain module — deprecated"
search_src 'require("domain")' "domain module — deprecated"
search_src "require('sys')" "sys module — removed"
search_src 'new Buffer(' "Buffer() constructor — deprecated, use Buffer.from()/alloc()"
search_src 'Buffer(' "Buffer() without new — removed"
search_src "import.*assert.*{" "import assertions — replaced by import attributes (with) in Node 22+"
search_src 'createCipher(' "crypto.createCipher — removed, use createCipheriv"
search_src 'createDecipher(' "crypto.createDecipher — removed, use createDecipheriv"

# ─── Removable Polyfills ────────────────────────────────────────────
header "Potentially Removable Polyfills (native in Node 18+)"
if [ -f package.json ]; then
  polyfills="node-fetch abort-controller abortcontroller-polyfill form-data web-streams-polyfill structured-clone blob-polyfill whatwg-url isomorphic-fetch cross-fetch"
  for pkg in $polyfills; do
    if grep -q "\"$pkg\"" package.json 2>/dev/null; then
      warn "$pkg — likely replaceable with native API"
    fi
  done

  # Dev tool polyfills
  if grep -q '"nodemon"' package.json 2>/dev/null; then
    info "nodemon — consider node --watch (stable in Node 22+)"
  fi
  if grep -q '"glob"' package.json 2>/dev/null; then
    info "glob — consider fs.glob() (available in Node 22+)"
  fi
fi

# ─── Module System ──────────────────────────────────────────────────
header "Module System"
if [ -f package.json ]; then
  type_field=$(grep '"type"' package.json 2>/dev/null | head -1 || true)
  if [ -n "$type_field" ]; then
    info "package.json type: $type_field"
  else
    info "package.json type: not set (defaults to CommonJS)"
  fi
fi

cjs_count=$(find . -maxdepth 5 -name '*.cjs' -not -path '*/node_modules/*' 2>/dev/null | wc -l | tr -d ' ')
mjs_count=$(find . -maxdepth 5 -name '*.mjs' -not -path '*/node_modules/*' 2>/dev/null | wc -l | tr -d ' ')
info "Explicit CJS files (.cjs): $cjs_count"
info "Explicit ESM files (.mjs): $mjs_count"

# ─── Package Manager ────────────────────────────────────────────────
header "Package Manager"
[ -f package-lock.json ] && info "npm (package-lock.json found)"
[ -f yarn.lock ] && info "Yarn (yarn.lock found)"
[ -f pnpm-lock.yaml ] && info "pnpm (pnpm-lock.yaml found)"
[ -f bun.lockb ] && info "Bun (bun.lockb found)"

if [ -f .npmrc ]; then
  info ".npmrc found"
  cat .npmrc | sed 's/^/      /'
fi

# ─── Summary ─────────────────────────────────────────────────────────
header "Scan Complete"
echo -e "  Review the findings above and use them to plan your Node.js upgrade."
echo -e "  Recommended target: the current Active LTS version (see release landscape above)."
echo -e "  Run this script again after the upgrade to verify all references are updated."
echo ""
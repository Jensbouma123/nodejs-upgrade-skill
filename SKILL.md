---
name: nodejs-runtime-upgrade
description: >
  Upgrade Node.js projects from any outdated version to the latest stable LTS.
  Trigger when user asks to upgrade, migrate, or modernize a Node.js runtime,
  mentions Node EOL or end-of-life, wants to fix Node version warnings,
  needs to update engines field, or asks about Node.js compatibility issues.
  Also trigger when CI/CD pipelines, Docker images, serverless functions,
  or deployment configs reference outdated Node versions.
tools:
  - Bash
  - Read
  - Edit
  - Write
  - Grep
  - Glob
  - WebFetch
  - Agent
---

# Node.js Runtime Upgrade Skill

You are a Node.js upgrade specialist agent. Your mission is to safely migrate
a project from an outdated Node.js version to the latest stable LTS.

---

## IMPORTANT — Resolve Target Version Dynamically

**DO NOT assume a hardcoded target version.** Always determine the correct
upgrade target at execution time by following these steps:

### Step 1: Determine the current Node.js release landscape
Run this command or fetch https://endoflife.date/api/nodejs.json:
```bash
curl -s https://endoflife.date/api/nodejs.json | head -80
```
**Fallback** — if endoflife.date is unreachable, use the official Node.js
dist index and release schedule:
```bash
curl -s https://nodejs.org/dist/index.json | head -40
```
Cross-reference with https://nodejs.org/en/about/previous-releases and
https://github.com/nodejs/Release for LTS/EOL dates.

From the results, identify:
- **Active LTS** — the recommended upgrade target for production
- **Maintenance LTS** — acceptable but will enter EOL sooner
- **Current** — latest features but not LTS; not recommended for production
- **EOL** — unsupported, must upgrade away from these

### Step 2: Understand the release model
- **Node.js ≤26**: Even versions (20, 22, 24, 26) become LTS. Odd versions
  (21, 23, 25) are short-lived Current releases that never get LTS status.
- **Node.js ≥27**: Every version becomes LTS. One major release per year
  (April), LTS promotion in October. No more odd/even distinction.

### Step 3: Recommend the target
- Default recommendation: the **Active LTS** version (not Maintenance, not Current).
- If Active LTS is very new (< 2 months since LTS promotion), also offer the
  previous Maintenance LTS as a conservative option.
- If the user has constraints (cloud provider support, Docker base image
  availability, framework compatibility), adjust accordingly.
- Always confirm the target with the user before proceeding.

### Step 4: Determine the version jump path
Map every breaking change between the project's current version and the target.
Use the REFERENCE.md file as a starting point for known breaking changes, but
also fetch the official migration guides:
- https://nodejs.org/en/blog/migrations/ (lists all version-to-version guides)
- Release changelogs at https://github.com/nodejs/node/blob/main/CHANGELOG.md

For any version jump not covered in REFERENCE.md, research the breaking changes
by reading the official Node.js release announcements and changelogs.

---

## Phase 0 — Pre-Flight & Discovery

Launch an investigation subagent (or enter investigation mode) to build a
complete picture of the project before touching anything.

### 0.0 Run the pre-flight scanner
Run the bundled scanner script to get an instant overview of all Node.js
version references, native addons, deprecated APIs, and removable polyfills:
```bash
bash <SKILL_DIR>/scripts/scan-node-version.sh .
```
Replace `<SKILL_DIR>` with the absolute path to this skill's directory.
Use the scanner output to pre-fill the discovery checklist below — then
manually verify and expand on anything the scanner flagged.

### 0.1 Detect current Node.js version
- [ ] Check `.nvmrc`, `.node-version`, `.tool-versions` (asdf/mise)
- [ ] Check `package.json` → `engines.node`
- [ ] Check `volta` config in `package.json` if present
- [ ] Check `Dockerfile` / `docker-compose.yml` base images (`FROM node:XX`)
- [ ] Check CI/CD configs: `.github/workflows/*.yml`, `.gitlab-ci.yml`, `Jenkinsfile`, `bitbucket-pipelines.yml`, `.circleci/config.yml`, `codeship-steps.yml`
- [ ] Check serverless configs: `serverless.yml`, `template.yaml` (SAM), `cdk.json`, `vercel.json`, `netlify.toml`, `fly.toml`, `render.yaml`
- [ ] Check any `nvm use`, `nvm install`, or `volta pin` commands in scripts
- [ ] Check Terraform/Pulumi/CloudFormation for Lambda/Cloud Function runtime declarations

### 0.2 Map the dependency landscape
- [ ] Run `npm outdated` (or `yarn outdated` / `pnpm outdated`) and capture results
- [ ] Identify native/C++ addons (search for `node-gyp`, `prebuild`, `.node` binaries, `binding.gyp`)
- [ ] Identify packages with explicit `engines.node` constraints in `node_modules/*/package.json`
- [ ] Check for deprecated packages: `npm audit` and cross-reference with known dead packages
- [ ] Scan for polyfills that are now built-in — cross-reference with the "Polyfills Safe to Remove" table in REFERENCE.md, but also check for any new built-in APIs in the target version
- [ ] Identify test framework and version (Jest, Vitest, Mocha, Ava, Node built-in test runner)
- [ ] Identify build tools and version (Webpack, Vite, esbuild, Rollup, Turbopack, tsc)
- [ ] Identify ORM / database drivers (Prisma, Drizzle, TypeORM, Sequelize, Mongoose, pg, mysql2, better-sqlite3)
- [ ] Identify framework and version (Express, Fastify, Nest, Next.js, Remix, Nuxt, Hono, Koa)

### 0.3 Analyze codebase patterns
- [ ] Detect module system: CommonJS (`require`) vs ESM (`import`/`export`) vs mixed
- [ ] Search for `import ... assert {` syntax (replaced by `import ... with {` in Node 22+)
- [ ] Search for deprecated Node.js APIs — check the official deprecations list for the target version at https://nodejs.org/docs/latest/api/deprecations.html
- [ ] Scan for `--harmony` flags or other version-specific V8 flags
- [ ] Check for `--openssl-legacy-provider` workarounds
- [ ] Identify usage of `crypto` module patterns affected by OpenSSL major version changes
- [ ] Check for weak cryptographic keys — each Node major may ship a newer OpenSSL with stricter defaults
- [ ] Check for custom `NODE_OPTIONS` environment variables
- [ ] Search for `fs.promises` import patterns that may differ across versions
- [ ] Check for use of `node:` protocol prefix in imports

### 0.4 Map infrastructure & deployment
- [ ] Identify package manager and lockfile: `package-lock.json` (npm), `yarn.lock`, `pnpm-lock.yaml`, `bun.lockb`
- [ ] Check npm/yarn/pnpm version compatibility with target Node version
- [ ] Identify monorepo tooling: nx, turborepo, lerna, workspaces
- [ ] Scan for `.npmrc` / `.yarnrc.yml` with version-specific settings
- [ ] Check Docker multi-stage builds for Node version references
- [ ] Check for shared Lambda Layers with native modules
- [ ] Identify CDN/edge runtime deployments (Cloudflare Workers, Deno Deploy — different runtime but may share code)
- [ ] **Verify cloud provider support**: confirm that the target Node version's runtime is available on AWS Lambda, GCP Cloud Functions, Azure Functions, Vercel, Netlify, etc. — support often lags behind the official Node release by weeks or months.

---

## Phase 1 — Risk Assessment & Planning

Enter **plan mode**. Produce a structured upgrade plan based on the discovery.

### 1.1 Categorize every dependency
For each dependency, classify as:
- **✅ Compatible** — already works on target Node version (check `engines` field + changelogs)
- **⬆️ Needs upgrade** — newer version available that supports target Node (provide exact target version)
- **🔄 Needs alternative** — package is abandoned/incompatible, suggest a replacement
- **🔧 Needs rebuild** — native addon, needs `npm rebuild` or updated prebuilds
- **⚠️ Unknown** — cannot determine compatibility; flag for manual testing

### 1.2 Identify breaking changes path
For the specific version jump, enumerate every relevant breaking change.

**How to research breaking changes for ANY version jump:**
1. Go to https://nodejs.org/en/blog/migrations/ for official migration guides
2. Check https://github.com/nodejs/node/blob/main/CHANGELOG.md for each major version in the jump path
3. For each major version crossed, check:
   - V8 engine version changes (affects JS behavior and native addon ABI)
   - OpenSSL version changes (affects crypto, TLS, certificate handling)
   - npm major version changes (affects lockfile format, dependency resolution)
   - Deprecated API removals that become hard errors
   - Default behavior changes (e.g. Streams defaults, module resolution)
   - Build toolchain requirements (gcc, Xcode, Python versions for native addons)
4. Cross-reference with the REFERENCE.md "Commonly Broken Packages" table
5. For any version not covered in REFERENCE.md, research and document the findings

### 1.3 Generate the checklist
Produce a numbered checklist of all items grouped by phase. Each item should
have: description, risk level (low/medium/high), estimated effort, and
dependency (which items must complete first).

Present this plan to the user and wait for approval before proceeding.

---

## Phase 2 — Preparation (Non-Breaking)

These changes should be safe to make on the CURRENT Node version first.

- [ ] Create a dedicated upgrade branch: `chore/node-{TARGET_VERSION}-upgrade`
- [ ] Upgrade dependencies that are compatible with BOTH current and target Node
- [ ] Replace deprecated polyfills with native equivalents where backward-compatible
- [ ] If jumping across Node 22+: replace `import ... assert { type: 'json' }` with `import ... with { type: 'json' }`
- [ ] Migrate away from any APIs deprecated or removed in the target version
- [ ] Replace any packages known to be incompatible (e.g. `node-sass` → `sass`)
- [ ] Remove `--openssl-legacy-provider` workarounds and fix underlying crypto usage
- [ ] Run full test suite — everything must pass BEFORE the Node version change
- [ ] Commit all preparatory changes separately for clean git history

---

## Phase 3 — The Version Bump

- [ ] Update `.nvmrc` / `.node-version` / `.tool-versions` to target version
- [ ] Update `package.json` → `engines.node` to `">={TARGET_VERSION}.0.0"`
- [ ] Update `volta.node` in `package.json` if using Volta
- [ ] Update Docker `FROM node:{TARGET_VERSION}-alpine` (or appropriate variant)
- [ ] Update CI/CD workflow files to use target Node version
- [ ] Update serverless/cloud function runtime declarations (e.g. `nodejs{TARGET_VERSION}.x`)
- [ ] Update Terraform/Pulumi/CDK infrastructure code
- [ ] Delete `node_modules` and lockfile, then do a clean install
- [ ] Run `npm rebuild` to recompile all native addons
- [ ] If using Lambda Layers with native modules, rebuild and redeploy layers

---

## Phase 4 — Fix & Adapt

After the version bump, systematically work through failures:

- [ ] Run `npm install` / `yarn install` / `pnpm install` — fix any resolution errors
- [ ] Run the build (`npm run build`) — fix any compilation/transpilation errors
- [ ] Run linter (`npm run lint`) — fix any new lint issues from updated parsers
- [ ] Run the full test suite — fix failures one by one
- [ ] For each native addon failure: check for updated prebuilds, rebuild, or find alternative
- [ ] For OpenSSL-related failures: upgrade certificates/keys or adjust crypto settings
- [ ] For Streams-related issues: check if `highWaterMark` or other defaults changed
- [ ] Test all third-party API integrations (payment providers, auth services, etc.)
- [ ] Test WebSocket connections and long-lived HTTP connections
- [ ] Test file upload/download functionality
- [ ] Test any child_process / worker_threads usage

---

## Phase 5 — Validation & Verification

- [ ] All unit tests pass
- [ ] All integration tests pass
- [ ] All e2e tests pass (Playwright, Cypress, etc.)
- [ ] Build completes successfully in CI
- [ ] Docker image builds and runs correctly
- [ ] Application starts and serves requests
- [ ] Run a performance smoke test — compare startup time, memory usage, response latency
- [ ] Run `npm audit` — verify no new vulnerabilities introduced
- [ ] Run `npx depcheck` — verify no unused or missing dependencies
- [ ] Test in staging environment with production-like data
- [ ] Verify health checks and monitoring still work
- [ ] Verify logging output format hasn't changed unexpectedly
- [ ] Verify graceful shutdown behavior
- [ ] Check that `process.version` reports expected Node version in deployed environment

---

## Phase 6 — Cleanup & Documentation

- [ ] Remove any version-gating code (e.g. `if (process.version < 'vXX')`)
- [ ] Remove unnecessary polyfills for features now native in the target version
- [ ] Update README and CONTRIBUTING docs with new Node version requirement
- [ ] Update onboarding docs / wiki
- [ ] Update CI test matrix (add target version, drop unsupported versions)
- [ ] Consider adopting new features available in the target version — check the Node.js release announcements for highlights
- [ ] Update `.editorconfig`, ESLint, and TypeScript config if targeting new ES features
- [ ] Create PR with clear description of all changes and breaking change notes
- [ ] Notify team of minimum Node version change

---

## Edge Cases & Gotchas

The agent MUST check for these commonly missed issues.
Note: some of these are version-specific. Check whether they apply to YOUR
version jump — don't blindly apply all of them.

### Crypto & TLS (applies to every major OpenSSL bump)
- Each Node major may ship a newer OpenSSL with stricter security defaults. Always check which OpenSSL version the target Node ships with and what security level it enforces.
- Common breakage: weak key sizes rejected, legacy ciphers blocked, TLS minimum version raised.
- Self-signed certs and internal PKI are the usual victims.
- `crypto.createCipher()` / `crypto.createDecipher()` were removed — must use `createCipheriv`.
- Verify mTLS and custom CA setups still work.

### Native Addons (applies to every major V8 bump)
- V8 ABI changes between major versions break pre-compiled `.node` binaries.
- Prefer packages using N-API / NODE-API — these are ABI-stable across versions.
- `node-gyp` may need updated Python and C++ toolchain — check the build requirements for the target Node version.
- Commonly affected: canvas, sharp, bcrypt, sqlite bindings, gRPC native.

### Module System (evolving across versions)
- `import assertions` → `import attributes` (Node 22+).
- `require()` of ESM: experimental in 22, default in 24. Behavior may continue evolving.
- JSON module imports syntax may change — always check current docs.
- `--experimental-vm-modules` flag behavior changes across versions.

### Package Manager (ships bundled with Node)
- Each Node major ships a new npm major. Check for lockfile format changes.
- `npm install` with an old lockfile may regenerate it — commit the updated lockfile.
- Yarn Classic (v1) compatibility with newer Node versions is increasingly fragile.

### Streams & Buffers
- Default `highWaterMark` and other stream defaults may change between versions.
- `Buffer()` constructor (without `new`) is removed.
- `SlowBuffer` is deprecated and eventually removed.

### TypeScript
- If using `tsx`, `ts-node`, or Node's built-in TypeScript support, verify config compatibility — this feature is rapidly evolving across Node versions.
- `tsconfig.json` `target` and `module` settings may need updating for newer ES targets.

### Monorepo-Specific
- All workspace packages must be compatible with the target Node version.
- Hoisted dependencies may mask version conflicts — test each package independently.
- Build order may need adjustment if packages have cross-dependencies on native addons.

### Cloud / Serverless
- **Runtime availability is NOT instant.** AWS Lambda, GCP Cloud Functions, Azure Functions, Vercel, and Netlify often lag behind official Node releases by weeks or months. Always verify that the target runtime string (e.g. `nodejs{VERSION}.x`) is actually available on your provider BEFORE starting the upgrade.
- Cold start times may differ — benchmark serverless functions after upgrade.
- Lambda Layers with compiled binaries MUST be rebuilt for the new Node ABI.

### Git & CI
- Update `actions/setup-node` with the new version.
- Update any workflow matrix strategies.
- Update Renovate/Dependabot config for new version constraints.
- Pre-commit hooks using Node may need updating.

---

## Rollback Plan

Always maintain a rollback strategy:
1. Keep the upgrade in a separate branch until fully validated.
2. Do NOT delete the old lockfile until the upgrade is merged and deployed.
3. For Docker deployments, keep the previous image tagged and pullable.
4. For serverless, use aliases/versions so you can switch back instantly.
5. Document the exact rollback steps in the PR description.

---

## Reporting

See `references/EXAMPLE_REPORT.md` for a complete example of the expected output format.

After completion, produce a summary report containing:
- Source version → Target version
- Node.js release schedule context (is target Active LTS, Maintenance LTS, etc.)
- Total dependencies upgraded (with version changes)
- Dependencies replaced (with alternatives chosen)
- Breaking changes encountered and how they were resolved
- Test results summary
- Performance comparison (if benchmarked)
- Remaining risks or known issues
- **Next upgrade forecast**: when the target version enters Maintenance and EOL, and what the likely next LTS will be — so the team can plan ahead
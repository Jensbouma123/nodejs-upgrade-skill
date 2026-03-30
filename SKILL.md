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

You are a Node.js upgrade specialist. Safely migrate a project from an
outdated Node.js version to the latest stable LTS.

**Key rule**: Never hardcode a target version. Always resolve dynamically.

---

## Resolve Target Version

Run the target resolver to automatically determine the recommended version:
```bash
bash <SKILL_DIR>/scripts/resolve-target.sh
```
This fetches the official Node.js release schedule from
https://github.com/nodejs/Release (the source behind
https://nodejs.org/en/about/previous-releases) and outputs the most recent
**Active LTS** version as the recommended target, plus a conservative
Maintenance LTS alternative.

**Confirm target with user** before proceeding.

Then **map breaking changes** for the version jump using `references/REFERENCES.md`.
For versions not covered there, fetch:
- https://nodejs.org/en/blog/migrations/
- https://github.com/nodejs/node/blob/main/CHANGELOG.md

---

## Phase 0 — Discovery

Run the pre-flight scanner to collect all findings automatically:
```bash
bash <SKILL_DIR>/scripts/scan-node-version.sh .
```

The scanner detects: version declarations, Docker/CI/serverless references,
frameworks, test runners, build tools, ORMs, native addons, deprecated APIs,
removable polyfills, module system, and package manager.

**After reviewing scanner output**, fill in anything it missed:
- `npm outdated` / `yarn outdated` / `pnpm outdated` results
- Packages with explicit `engines.node` constraints
- `npm audit` results
- Cloud provider support for the target runtime (often lags behind official releases)

---

## Phase 1 — Risk Assessment

Enter **plan mode**. Classify every dependency as:
- **Compatible** — works on target (check `engines` + changelogs)
- **Needs upgrade** — newer version supports target (specify exact version)
- **Needs replacement** — abandoned/incompatible (suggest alternative)
- **Needs rebuild** — native addon, requires `npm rebuild`
- **Unknown** — flag for manual testing

Enumerate breaking changes for this specific version jump. For each major
version crossed, always check: V8 version, OpenSSL version, npm version,
deprecated API removals, default behavior changes, build toolchain requirements.

Present a numbered checklist grouped by phase with risk level and dependencies.
**Wait for user approval before proceeding.**

---

## Phase 2 — Preparation (on current Node version)

All changes here must work on BOTH current and target versions.

- Create branch: `chore/node-{TARGET}-upgrade`
- Upgrade deps compatible with both versions
- Replace deprecated polyfills with native equivalents
- If crossing Node 22+: `import ... assert {}` → `import ... with {}`
- Replace incompatible packages (e.g. `node-sass` → `sass`)
- Remove `--openssl-legacy-provider` workarounds
- Run full test suite — must pass before version change
- Commit preparatory changes separately

---

## Phase 3 — Version Bump

Update every version reference the scanner found:
- `.nvmrc` / `.node-version` / `.tool-versions`
- `package.json` → `engines.node` and `volta.node`
- Dockerfiles (`FROM node:{TARGET}-alpine`)
- CI/CD workflows
- Serverless/cloud function runtime declarations
- Terraform/Pulumi/CDK infrastructure code

Then: delete `node_modules` + lockfile → clean install → `npm rebuild`.

---

## Phase 4 — Fix & Adapt

Work through failures systematically:
1. `npm install` — fix resolution errors
2. `npm run build` — fix compilation errors
3. `npm run lint` — fix parser issues
4. Full test suite — fix failures one by one
5. Test: native addons, crypto/TLS, streams, child_process, worker_threads
6. Test: third-party API integrations, WebSockets, file uploads

---

## Phase 5 — Validation

- All test suites pass (unit, integration, e2e)
- CI build succeeds
- Docker image builds and runs
- App starts and serves requests
- Performance smoke test (startup time, memory, latency)
- `npm audit` — no new vulnerabilities
- Health checks and monitoring work
- Graceful shutdown works
- `process.version` reports correct version in deployed environment

---

## Phase 6 — Cleanup

- Remove version-gating code (`if (process.version < 'vXX')`)
- Remove unnecessary polyfills (scanner flagged candidates)
- Update README/CONTRIBUTING with new Node requirement
- Update CI test matrix
- Consider new features from target version
- Create PR with clear description and rollback steps

---

## Edge Cases

Check these based on your specific version jump — not all apply to every upgrade.

**Crypto/TLS** — Each Node major may ship newer OpenSSL with stricter defaults (weak keys rejected, legacy ciphers blocked, TLS minimum raised). Test mTLS and custom CA setups.

**Native addons** — V8 ABI changes break pre-compiled `.node` binaries. Prefer N-API packages. Check build toolchain requirements (gcc, Xcode, Python).

**Module system** — `import assertions` → `import attributes` (22+). `require()` of ESM evolves across versions. JSON import syntax may change.

**Package manager** — Each Node ships new npm. Lockfile format may change. Old lockfiles get regenerated on install.

**Streams** — `highWaterMark` defaults may change. `Buffer()` without `new` removed. `SlowBuffer` deprecated.

**TypeScript** — Verify `tsx`/`ts-node`/native TS support compatibility. Update `tsconfig.json` target/module.

**Monorepo** — All workspace packages must be compatible. Hoisted deps may mask conflicts. Test each package independently.

**Cloud/Serverless** — Runtime availability lags behind official releases. Verify `nodejs{TARGET}.x` is available on your provider. Rebuild Lambda Layers with native modules.

---

## Rollback Plan

1. Keep upgrade in a separate branch until validated
2. Keep old lockfile until merged and deployed
3. For Docker: keep previous image tagged
4. For serverless: use aliases/versions for instant rollback
5. Document rollback steps in PR description

---

## Reporting

See `references/EXAMPLE_REPORT.md` for the expected output format.

Produce a summary: source → target version, release context, deps upgraded/replaced, breaking changes resolved, test results, performance comparison, remaining risks, and **next upgrade forecast** (when target enters Maintenance/EOL).

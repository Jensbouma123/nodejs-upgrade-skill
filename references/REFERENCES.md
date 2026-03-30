# Node.js Breaking Changes Reference

Quick-lookup table for the upgrade agent. Consult this when determining
which breaking changes apply to a specific version jump.

> **This file covers known breaking changes up to Node.js 24.**
> For any target version beyond what's listed here, the agent MUST fetch
> the official migration guide and release notes dynamically:
> - Migration guides: https://nodejs.org/en/blog/migrations/
> - Changelogs: https://github.com/nodejs/node/blob/main/CHANGELOG.md
> - Release schedule: https://github.com/nodejs/Release
> - EOL dates: https://endoflife.date/api/nodejs.json

---

## Release Model Reference

### Legacy model (Node ≤26)
- Even versions (20, 22, 24, 26) → LTS (30 months total support)
- Odd versions (21, 23, 25) → Current only (6 months, no LTS)
- Production should only run Active LTS or Maintenance LTS

### New model (Node ≥27)
- One major release per year (April)
- EVERY version becomes LTS (promoted in October)
- 36 months total support from first Current release to EOL
- Alpha channel replaces odd-version early-testing role
- Version numbers align with calendar year: 27 in 2027, 28 in 2028, etc.

---

## Breaking Changes by Version Jump

### 18 → 20

| Area    | Change                                                    | Action                              |
| ------- | --------------------------------------------------------- | ----------------------------------- |
| URL     | `url.parse()` emits deprecation warning for invalid ports | Migrate to `new URL()`              |
| V8      | Engine updated to V8 11.3                                 | Test for subtle JS behavior changes |
| fetch   | `fetch()` is now stable and global                        | Remove `node-fetch` polyfill        |
| Test    | Built-in test runner available (experimental)             | Consider migration                  |
| OpenSSL | Updated to OpenSSL 3.0                                    | Test all crypto operations          |

### 20 → 22

| Area       | Change                                                    | Action                                                         |
| ---------- | --------------------------------------------------------- | -------------------------------------------------------------- |
| Import     | `import ... assert {}` → `import ... with {}`             | Find-and-replace all import assertions                         |
| Streams    | Default `highWaterMark` 16KB → 64KB                       | Check memory-sensitive stream pipelines                        |
| Native     | ABI version changed                                       | Run `npm rebuild` on all native addons                         |
| punycode   | `punycode` removed from globals                           | Use `require('punycode/')` (trailing slash) or `node:punycode` |
| ESM        | `require()` of ESM behind `--experimental-require-module` | Check for accidental CJS/ESM mixing                            |
| Glob       | `fs.glob()` / `fs.globSync()` added                       | Can replace `glob` / `fast-glob` for simple cases              |
| WebSocket  | `WebSocket` available globally (experimental)             | Can replace `ws` for client-side use                           |
| TypeScript | `--experimental-strip-types` flag available               | Can run `.ts` files without transpiler                         |
| Watch      | `node --watch` is stable                                  | Can replace `nodemon` for development                          |

### 22 → 24

| Area        | Change                                             | Action                                                        |
| ----------- | -------------------------------------------------- | ------------------------------------------------------------- |
| OpenSSL     | Updated to OpenSSL 3.5, security level 2           | RSA/DSA < 2048, ECC < 224 bits REJECTED. RC4 blocked.         |
| V8          | Engine updated to V8 13.6                          | C++ addons may need C++20 (was C++17)                         |
| ESM         | `require()` of ESM enabled by default              | Verify no unintended CJS→ESM loading                          |
| Permissions | Permission model improvements                      | Review if using `--experimental-permission`                   |
| TypeScript  | Native TS execution more mature                    | Consider dropping `tsx`/`ts-node`                             |
| crypto      | `generateKeyPair` option names changed for RSA-PSS | Update `hash`→`hashAlgorithm`, `mgf1Hash`→`mgf1HashAlgorithm` |
| Build       | Minimum gcc 12.2 for source builds                 | Update CI compilers if building from source                   |
| Build       | Minimum Xcode 16.1 on macOS                        | Update macOS CI runners                                       |
| npm         | Ships with npm 11                                  | Lockfile format may change, new `overrides` behavior          |

### 24 → future versions

**For any version jump beyond 24, the agent must dynamically research
breaking changes.** Follow this procedure:

1. Fetch the migration guide if available:
   `curl -s https://nodejs.org/en/blog/migrations/v{CURRENT}-to-v{TARGET}`
2. If no migration guide exists, check the changelog:
   `https://github.com/nodejs/node/blob/main/doc/changelogs/CHANGELOG_V{TARGET}.md`
3. Key areas to always check for any major version bump:
   - **V8 engine version** → affects JS behavior, native addon ABI, C++ standard required
   - **OpenSSL version** → affects crypto defaults, key size requirements, cipher availability
   - **npm version** → affects lockfile format, dependency resolution algorithm
   - **Deprecated APIs** → check https://nodejs.org/docs/latest-v{TARGET}.x/api/deprecations.html
   - **Build requirements** → minimum gcc, Xcode, Python versions for native addon compilation
   - **Default behavior changes** → Streams, module resolution, permissions, timers
4. Document findings in the same table format as above before proceeding

---

## Commonly Broken Packages

These packages are known to break frequently across Node major versions.
Check each one if present in the project.

| Package                  | Issue                              | Solution                                                        |
| ------------------------ | ---------------------------------- | --------------------------------------------------------------- |
| `node-sass`              | No Node 22+ support                | Migrate to `sass` (dart-sass)                                   |
| `bcrypt`                 | Native addon ABI mismatch          | `npm rebuild bcrypt` or switch to `bcryptjs`                    |
| `node-canvas`            | Needs rebuild + system deps        | Rebuild, or use `@napi-rs/canvas`                               |
| `sharp`                  | Needs matching prebuild            | `npm rebuild sharp` (usually has prebuilds)                     |
| `better-sqlite3`         | Native addon                       | Rebuild; usually supports new Node quickly                      |
| `grpc` / `@grpc/grpc-js` | Legacy `grpc` needs native rebuild | Migrate to `@grpc/grpc-js` (pure JS)                            |
| `node-gyp`               | Needs Python 3 + C++ toolchain     | Ensure `python3` and `g++` available                            |
| `fsevents`               | macOS-only native addon            | Usually auto-rebuilds; verify on CI                             |
| `esbuild`                | Platform-specific binary           | Update to latest; binaries ship per-platform                    |
| `sqlite3`                | Native addon                       | Rebuild, or migrate to `better-sqlite3`                         |
| `dtrace-provider`        | Optional native addon              | Usually safe to skip; install with `--ignore-scripts` if broken |
| `fibers`                 | Incompatible with Node 16+         | Remove; use async/await patterns                                |
| `farmhash`               | Native addon                       | Rebuild or use JS alternative                                   |
| `leveldown`              | Native addon                       | Rebuild or use `classic-level`                                  |

> **For future versions**: any package using `node-gyp` or shipping `.node`
> binaries is at risk on every major Node bump. Always search for
> `binding.gyp` files in `node_modules` to find them all.

---

## Polyfills Safe to Remove

Check the "Native Since" column against your **target** version.
Only remove polyfills if your target version is >= the "Native Since" version.

| Polyfill Package           | Native Since               | Native API                                                 |
| -------------------------- | -------------------------- | ---------------------------------------------------------- |
| `node-fetch`               | Node 18                    | `globalThis.fetch`                                         |
| `abort-controller`         | Node 16                    | `globalThis.AbortController`                               |
| `abortcontroller-polyfill` | Node 16                    | `globalThis.AbortController`                               |
| `form-data`                | Node 18                    | `globalThis.FormData`                                      |
| `web-streams-polyfill`     | Node 18                    | `globalThis.ReadableStream` etc.                           |
| `structured-clone`         | Node 17                    | `globalThis.structuredClone`                               |
| `blob-polyfill`            | Node 18                    | `globalThis.Blob`                                          |
| `whatwg-url`               | Node 10+ (URL), 18+ (full) | `globalThis.URL`, `globalThis.URLSearchParams`             |
| `webcrypto`                | Node 19                    | `globalThis.crypto`                                        |
| `undici` (fetch part)      | Node 18                    | `globalThis.fetch` (undici still useful for advanced HTTP) |
| `glob` / `fast-glob`       | Node 22                    | `fs.glob()` / `fs.globSync()` (simple patterns only)       |
| `ws` (client-only)         | Node 22                    | `globalThis.WebSocket` (experimental in 22)                |
| `nodemon` (dev)            | Node 22                    | `node --watch`                                             |

> **For future versions**: check the Node.js release announcements for
> newly stabilized APIs that may replace additional polyfills. Common
> candidates include test runners, glob utilities, and HTTP client features.

---

## CI/CD Version Strings

When updating version references, replace `{TARGET}` with the actual
target major version number.

```yaml
# GitHub Actions
- uses: actions/setup-node@v4  # or latest version of this action
  with:
    node-version: '{TARGET}'

# GitLab CI
image: node:{TARGET}-alpine

# Docker
FROM node:{TARGET}-alpine

# AWS Lambda (SAM) — verify runtime availability first!
Runtime: nodejs{TARGET}.x

# AWS CDK — verify runtime availability first!
runtime: lambda.Runtime.NODEJS_{TARGET}_X

# Vercel — set in package.json engines or vercel.json

# Netlify (netlify.toml)
[build.environment]
  NODE_VERSION = "{TARGET}"

# Fly.io — uses Docker, update Dockerfile

# Render (render.yaml)
envVars:
  - key: NODE_VERSION
    value: "{TARGET}"

# Heroku — set in package.json engines
"engines": { "node": "{TARGET}.x" }

# Terraform (AWS Lambda) — verify runtime availability first!
resource "aws_lambda_function" "fn" {
  runtime = "nodejs{TARGET}.x"
}
```

> **Cloud provider warning**: AWS Lambda, GCP Cloud Functions, and Azure
> Functions often lag behind official Node.js releases by weeks or months.
> Always verify that `nodejs{TARGET}.x` is listed as an available runtime
> on your provider BEFORE updating infrastructure code.
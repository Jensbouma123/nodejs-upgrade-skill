# Example Upgrade Report

> This is an example of the report the skill produces after a completed
> Node.js upgrade. Your actual report will reflect your project's specifics.

---

## Node.js Upgrade Report

| Field               | Value                                |
| ------------------- | ------------------------------------ |
| **Project**         | acme-api                             |
| **Source version**  | Node.js 18.20.2 (Maintenance LTS)   |
| **Target version**  | Node.js 22.14.0 (Active LTS)        |
| **Date**            | 2025-03-15                           |
| **Upgrade branch**  | `chore/node-22-upgrade`              |

---

### Release Context

- Node.js 22 entered **Active LTS** on 2024-10-29
- Node.js 18 enters **End of Life** on 2025-04-30
- This upgrade crosses **two major versions** (18 → 20 → 22)

---

### Dependencies Upgraded

| Package            | From     | To       | Reason                            |
| ------------------ | -------- | -------- | --------------------------------- |
| `sharp`            | 0.32.6   | 0.33.2   | Native addon — needed Node 22 prebuilds |
| `bcrypt`           | 5.1.0    | 5.1.1    | Rebuilt for new ABI               |
| `typescript`       | 5.3.3    | 5.4.2    | Better Node 22 type support       |
| `@types/node`      | 18.19.8  | 22.13.1  | Match target Node version         |
| `eslint`           | 8.56.0   | 9.1.0    | Dropped Node 18 compat in v9      |
| `jest`             | 29.7.0   | 30.0.0   | Required for Node 22 ESM support  |

**Total**: 6 dependencies upgraded

### Dependencies Replaced

| Removed            | Replaced with        | Reason                           |
| ------------------ | -------------------- | -------------------------------- |
| `node-fetch`       | native `fetch()`     | Global fetch stable since Node 18 |
| `glob`             | native `fs.glob()`   | Built-in since Node 22           |
| `nodemon`          | `node --watch`       | Stable since Node 22             |

**Total**: 3 polyfills removed

---

### Breaking Changes Encountered

#### 1. Import assertions syntax (Medium risk)
**Change**: `import ... assert { type: 'json' }` replaced by `import ... with { type: 'json' }`
**Files affected**: `src/config/loader.ts`, `src/utils/schema.ts`
**Resolution**: Find-and-replace `assert {` → `with {` in all import statements

#### 2. OpenSSL 3.0 stricter defaults (High risk)
**Change**: Node 22 ships OpenSSL 3.x which rejects some legacy crypto operations
**Files affected**: `src/services/encryption.ts`
**Resolution**: Replaced `crypto.createCipher()` with `crypto.createCipheriv()` and updated key derivation to use explicit IV

#### 3. Streams `highWaterMark` default change (Low risk)
**Change**: Default increased from 16KB to 64KB
**Files affected**: None (our stream pipelines used explicit `highWaterMark` values)
**Resolution**: No action required

#### 4. `punycode` module removed from globals (Low risk)
**Change**: `require('punycode')` no longer works without trailing slash
**Files affected**: `src/utils/domain-validator.ts`
**Resolution**: Changed to `require('punycode/')` (npm package, not built-in)

---

### Test Results

| Suite           | Pass | Fail | Skip | Duration |
| --------------- | ---- | ---- | ---- | -------- |
| Unit tests      | 342  | 0    | 3    | 12s      |
| Integration     | 87   | 0    | 0    | 45s      |
| E2E (Playwright)| 24   | 0    | 1    | 2m 10s   |

All previously passing tests continue to pass.

---

### Performance Comparison

| Metric              | Node 18     | Node 22     | Change  |
| ------------------- | ----------- | ----------- | ------- |
| Cold start          | 1.8s        | 1.4s        | -22%    |
| Memory (idle)       | 82 MB       | 78 MB       | -5%     |
| HTTP req/s (p50)    | 4,200       | 4,850       | +15%    |
| HTTP latency (p99)  | 45ms        | 38ms        | -16%    |

---

### Version References Updated

- [x] `.nvmrc` → `22`
- [x] `package.json` engines → `">=22.0.0"`
- [x] `Dockerfile` → `FROM node:22-alpine`
- [x] `.github/workflows/ci.yml` → `node-version: '22'`
- [x] `serverless.yml` → `runtime: nodejs22.x`
- [x] `README.md` → updated prerequisites section

---

### Remaining Risks

- **AWS Lambda `nodejs22.x` runtime**: verified available as of 2025-02-15. Monitor for any provider-side patches.
- **`bcrypt` native addon**: rebuilt successfully, but monitor for issues on ARM-based CI runners.

---

### Next Upgrade Forecast

| Version  | Status          | LTS Start   | Maintenance Start | EOL         |
| -------- | --------------- | ----------- | ----------------- | ----------- |
| Node 22  | Active LTS      | 2024-10-29  | 2025-10-21        | 2027-04-30  |
| Node 24  | Current (Apr 25)| 2025-10-21  | 2026-10-20        | 2028-04-30  |

**Recommended next upgrade window**: Q4 2025, after Node 24 enters Active LTS (October 2025). Plan to begin assessment in September 2025.

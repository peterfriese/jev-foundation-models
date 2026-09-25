# Remediation Plan: Post-Audit Hardening & Architectural Compliance

- **Document ID**: `REMEDIATION-PLAN-2026-09-25`
- **Date**: 2026-09-25
- **Status**: Approved with Custom User Guidance (Ready for Implementation)
- **Author**: Documentation Agent (in collaboration with Senior Architect & Code Reviewer)
- **Target Repository**: `system-one-laya`
- **Target Scope**: Core Swift Package (`Sources/`), Reference App (`Examples/MailTriageApp/`), and Toolchain
- **Upstream References**: 
  - `docs/prd/PRD-2026-09-25-mail-triage-system-one-engine.md`
  - `docs/architecture/ADR-2026-09-25-mail-triage-system-one-engine.md`
  - `docs/plans/QA-VERIFICATION-REPORT-2026-09-25.md`

---

## 1. Executive Summary & Context

Following the initial implementation and Phase 5 QA verification of the **System One Decision Model Engine** and the **MailTriage reference application**, an exhaustive codebase audit was conducted. The audit spanned security posture, credential handling, on-device Core ML inference integrity, PRD functional fidelity, and Swift 6 concurrency hygiene.

While the core decision bridge and baseline UI compile cleanly with 100% test pass rates in synthetic mock scenarios, the audit surfaced **14 discrete issues** across four operational domains:

1. **Security & Credential Protection (SEC-1 – SEC-4)**: Critical exposure of sensitive API keys and tokens in unencrypted `UserDefaults`, compile-time path leakage via `#filePath` during runtime `.env` crawling, and unconstrained loopback URL validation.
2. **Simulation Elimination & Real Inference (SIM-1 – SIM-3)**: Hidden mock fallback closures in the Core ML engine returning static hardcoded probabilities (`[0.85, 0.15]`), and unsupported treat-as-compiled handling for raw `.safetensors` files.
3. **PRD Compliance & UI Integration (PRD-1 – PRD-4)**: The centerpiece floating `DecisionActionBarView` was left unanchored in `MailDetailView`, urgency score rubric values were inverted between detail views and schema specifications, and primary toolbar interaction buttons remained empty stubs.
4. **Engineering Hygiene & Concurrency Polish (IMP-1 – IMP-3)**: Overuse of `@unchecked Sendable` with manual `NSLock` instances in place of modern Swift 6 actors, unstandardized `NSError` propagation, and test coverage blind spots for negative error branches.

This document serves as the **authoritative remediation roadmap**. It provides an interactive decision framework allowing stakeholders to review findings, make binding approval decisions, and select execution bundles.

---

## 2. Interactive Decision Matrix

Use this high-level matrix to view the triage status and record decisions before reviewing the detailed specifications.

| Code | Category | Description | Severity | Target Target | Decision Status |
| :--- | :--- | :--- | :---: | :--- | :---: |
| **SEC-1** | Security | Remove plaintext credential fallback in `UserDefaults` | **Critical** | `AppCore/KeychainService.swift` | `[x] Modified (User Guidance)` |
| **SEC-2** | Security | Eliminate runtime `.env` filesystem crawl & `#filePath` leak | **High** | `AppCore/BackendConfigurationStore.swift` | `[x] Modified (User Guidance)` |
| **SEC-3** | Security | Protect Hugging Face token & sanitize public model downloads | **Medium** | `AppCore/CoreMLModelManager.swift`, `AppUI/SettingsView.swift` | `[x] Approved` |
| **SEC-4** | Security | Enforce scheme & loopback security on custom endpoint URLs | **Medium** | `AppCore/BackendConfigurationStore.swift`, `LayaHTTPBackend.swift` | `[x] Approved` |
| **SIM-1** | Real Inference | Remove silent mock predictor fallback in `TriageEngine` | **Critical** | `AppCore/TriageEngine.swift` | `[x] Approved` |
| **SIM-2** | Real Inference | Reject raw `.safetensors` as compiled Core ML models | **High** | `AppCore/CoreMLModelManager.swift` | `[x] Approved` |
| **SIM-3** | Real Inference | Enforce benchmark ground-truth checksum & live parity | **Medium** | `AppCore/BenchmarkTruthStore.swift`, `AppCoreTests` | `[x] Approved` |
| **PRD-1** | PRD Compliance | Retain toolbar triage & align PRDs (no UI code changes) | **High** | `docs/mail-triage-prd.md`, PRD specs | `[x] Modified (PRD Update Only, No Code Changes)` |
| **PRD-2** | PRD Compliance | Fix inverted urgency score rubric (0=P0 vs 3=P0) in detail banner | **High** | `AppUI/MailDetailView.swift` | `[x] Approved` |
| **PRD-3** | PRD Compliance | Wire functional stubs for Reply, Forward, and Compose | **Medium** | `AppUI/MailDetailView.swift` | `[x] Approved` |
| **PRD-4** | PRD Compliance | Polish multi-window minimum sizing & Liquid Glass contrast | **Low** | `AppUI/MailSplitView.swift`, `MailTriageAppApp.swift` | `[x] Approved` |
| **IMP-1** | Hygiene | Migrate `@unchecked Sendable` & `NSLock` to Swift 6 actors | **Medium** | `KeychainService`, `ConfigStore`, `TriageEngine` | `[x] Approved` |
| **IMP-2** | Hygiene | Standardize typed domain errors & localized user recovery | **Medium** | `AppCore/Services`, `SystemOneCore` | `[x] Approved` |
| **IMP-3** | Hygiene | Add regression tests for error paths, timeouts, and cancels | **Low** | `AppCoreTests`, `AppUITests` | `[x] Approved` |

---

## 3. Pre-Packaged Execution Bundles

To streamline execution, choose one of the pre-configured implementation bundles below, or customize individual items in Section 4.

### 📦 Option A: Full Remediation (All 14 Items)
- **Scope**: Comprehensive fix across all 4 categories (SEC-1..4, SIM-1..3, PRD-1..4, IMP-1..3).
- **Target Audience**: Production release, public open-source publication, enterprise security audit compliance.
- **Estimated Effort**: 3–4 days engineering + QA verification.
- **Selection**:
  - [ ] **Select Option A (Complete Remediation)**

### 📦 Option B: Production Hardening & Core UI (Recommended)
- **Scope**: All Security (SEC-1..4), Real Inference Integrity (SIM-1..2), and High-Impact PRD items (PRD-1, PRD-2).
- **Exclusions**: Hygiene refactoring to actors (IMP-1..3) and non-essential UI stubs (PRD-3, PRD-4).
- **Target Audience**: High-velocity milestone requiring zero security compromises and 100% genuine inference.
- **Estimated Effort**: 1.5–2 days engineering + QA verification.
- **Selection**:
  - [ ] **Select Option B (Hardening & Core UI - Recommended)**

### 📦 Option C: Critical Fast-Path Fixes Only
- **Scope**: Critical security and functional blockers only: SEC-1 (Keychain plaintext leak), SIM-1 (Silent fake Core ML fallback), PRD-1 (Missing action bar), and PRD-2 (Inverted urgency score).
- **Target Audience**: Immediate patch release or critical demo stabilization.
- **Estimated Effort**: 0.5–1 day engineering + QA verification.
- **Selection**:
  - [ ] **Select Option C (Critical Fast-Path)**

---

## 4. Detailed Remediation Specifications

---

### Category 1: Security & Credential Protection

```
┌────────────────────────────────────────────────────────────────────────┐
│                        CATEGORY 1: SECURITY                            │
│  SEC-1: UserDefaults Secret Fallback    SEC-2: Runtime .env Crawling   │
│  SEC-3: Cleartext HuggingFace Tokens   SEC-4: Cleartext HTTP Boundary  │
└────────────────────────────────────────────────────────────────────────┘
```

#### SEC-1: Plaintext Credential Persistence in `UserDefaults` (`KeychainService`)

- **Identifier**: `SEC-1`
- **Severity**: **Critical** (CWE-312: Cleartext Storage of Sensitive Information)
- **File Location**: `Examples/MailTriageApp/apps/apple/Packages/AppCore/Sources/AppCore/Services/KeychainService.swift`
- **Lines**: 80–85, 120–124, 169–170

##### Technical Root Cause
When storing credentials (`typesafeApiKey`, `hostedVpcToken`, `huggingFaceToken`), `KeychainService` mirrors every secret directly into `UserDefaults.standard` under the key prefix `ai.typesafe.secure.storage.*` as an "immediate fallback" to survive app restarts in unsigned or simulator environments:
```swift
// KeychainService.swift:121-123
let storageKey = persistentStorageKey(for: key)
inMemoryFallback[key] = value
defaults.set(value, forKey: storageKey) // <-- CRITICAL VULNERABILITY
```
`UserDefaults` is serialized to unencrypted `.plist` files within the app sandbox (`Library/Preferences/<bundle-id>.plist`). These files are included in standard unencrypted device backups, can be read by jailbroken devices or inspection tools, and violate fundamental mobile security standards.

##### Remediation Plan
1. **Ensure `.env` Gitignored & Provide Sample Template**: Ensure `.env` is explicitly included in `.gitignore` to prevent accidental credential commits. Provide a checked-in sample file `.env.example` documenting expected environment keys (e.g. `TYPESAFE_API_KEY=`, `TYPESAFE_BASE_URL=`, `HUGGINGFACE_TOKEN=`).
2. **Write Strictly to Keychain, NOT UserDefaults**: Write all credentials strictly into Keychain and NOT into `UserDefaults`. Completely eliminate all calls to `defaults.set(value, forKey: storageKey)` and `defaults.string(forKey: storageKey)`.
3. **One-Time Migration & Purge**: On startup, inspect `UserDefaults` for legacy keys prefixed with `ai.typesafe.secure.storage.`. If present, migrate them into the secure Keychain and immediately invoke `defaults.removeObject(forKey:)`.
4. **Hardened Keychain Query**: Enforce `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` so keys are hardware-encrypted and excluded from cloud backups.
5. **Isolated Ephemeral Test Store**: In automated testing environments where the macOS/iOS security daemon (`securityd`) is restricted, use an explicit `MockKeychainService` retaining secrets strictly in volatile RAM (`[String: String]`), never touching disk.

##### Verification Steps
- Verify `.gitignore` contains `.env` and `.env.example` is checked into the repository root.
- Run unit test verifying that setting a key writes to Keychain and does not populate `UserDefaults.standard.dictionaryRepresentation()`.
- Run automated migration test confirming legacy `UserDefaults` values migrate to Keychain and the original keys are erased.

##### 🗳️ User Decision
- [ ] **Approve (Proceed with implementation)**
- [x] **Modify (See notes below)**
- [ ] **Defer (Postpone to future milestone)**
- [ ] **Reject (Skip / Do not implement)**

**Decision Notes / Specific Instructions**:
> Ensure `.env` is gitignored, provide a `.env.example` sample file to check in. Write strictly into Keychain and NOT into UserDefaults.

---

#### SEC-2: Runtime `.env` Traversal and Compile-Time Path Leakage (`BackendConfigurationStore`)

- **Identifier**: `SEC-2`
- **Severity**: **High** (CWE-200: Exposure of Sensitive Information, CWE-22: Path Traversal)
- **File Location**: `Examples/MailTriageApp/apps/apple/Packages/AppCore/Sources/AppCore/Services/BackendConfigurationStore.swift`
- **Lines**: 109–142

##### Technical Root Cause
`BackendConfigurationStore.loadKeyFromDotEnv` attempts to locate developer environment files by crawling parent directories at runtime. It initializes the search root using `#filePath`:
```swift
// BackendConfigurationStore.swift:119-120
let sourceFileURL = URL(fileURLWithPath: #filePath)
candidateRoots.append(sourceFileURL.deletingLastPathComponent())
```
1. `#filePath` embeds the absolute filesystem path of the building developer machine into the compiled Mach-O binary (e.g. `/Users/runner/work/...` or `/Users/peterfriese/...`), leaking host system usernames and directory structures.
2. Dynamic directory crawling upward from runtime bundle locations violates iOS/macOS sandbox policies and can cause sandbox exceptions or crash the app in hardened production builds.

##### Remediation Plan
1. **Environment Key Precedence & Deterministic Test Failure**: If the required API keys are present in the environment (`ProcessInfo.processInfo.environment`), use them, otherwise fail the respective test explicitly rather than silently falling back to mock responses or crawling filesystem directories.
2. **Eliminate Runtime `.env` Traversal & `#filePath` Leak**: Eliminate `#filePath` as a candidate root and remove filesystem traversal upward from runtime bundle locations in the application binary. Restrict any optional `.env` file reading strictly to offline developer CLI tools (`BenchmarkCLI`) under `#if DEBUG`, never in GUI application bundles.
3. **Production Path**: In production, credentials must only originate from explicit user input via `SettingsView` (Keychain) or explicit deployment configuration profiles.

##### Verification Steps
- Run tests without required API keys in `ProcessInfo.processInfo.environment` and assert the respective tests fail cleanly with descriptive messages.
- Run tests with required environment keys present and verify they are correctly consumed.
- Inspect Release build binary strings using `strings MailTriageApp | grep Users` to verify zero source path leakage.
- Execute sandboxed test run on iOS Simulator to confirm no sandbox permission denials in console logs.

##### 🗳️ User Decision
- [ ] **Approve (Proceed with implementation)**
- [x] **Modify (See notes below)**
- [ ] **Defer (Postpone to future milestone)**
- [ ] **Reject (Skip / Do not implement)**

**Decision Notes / Specific Instructions**:
> If the required API keys are present in the environment (`ProcessInfo.processInfo.environment`), use them, otherwise fail the respective test.

---

#### SEC-3: Cleartext Hugging Face Token Storage & Authorization Leak (`CoreMLModelManager`)

- **Identifier**: `SEC-3`
- **Severity**: **Medium** (CWE-522: Insufficiently Protected Credentials)
- **File Location**: `Examples/MailTriageApp/apps/apple/Packages/AppCore/Sources/AppCore/Services/CoreMLModelManager.swift` (lines 140–158) & `Examples/MailTriageApp/apps/apple/Packages/AppUI/Sources/AppUI/Views/SettingsView.swift` (lines 405–415)

##### Technical Root Cause
1. `SettingsView.swift` renders the Hugging Face access token input using an insecure `TextField` instead of `SecureField`, exposing user access tokens to screen recording and shoulder surfing.
2. `CoreMLModelManager.downloadAndCompile` attaches the token to the HTTP `Authorization: Bearer <token>` header unconditionally for any configured URL, even when downloading from public endpoints:
```swift
// CoreMLModelManager.swift:140-143
let token = configStore.huggingFaceToken.trimmingCharacters(in: .whitespacesAndNewlines)
if !token.isEmpty {
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
}
```
If the download redirects to an external CDN (e.g. Cloudflare, AWS S3) or a third-party mirror, the credentials may be leaked in HTTP request headers.

##### Remediation Plan
1. **Mask UI Input**: Change the Hugging Face token field in `SettingsView.swift` to `SecureField`.
2. **Domain-Restricted Authorization**: Only attach the `Authorization` header if the destination host is strictly `huggingface.co` or a designated private enterprise model repository.
3. **URL Sanitization**: Reject plain `http://` download URLs to prevent MITM interception of weights or credentials.

##### Verification Steps
- Verify `SettingsView` masks character input for the HF token.
- Mock an HTTP download redirect to a third-party host and assert the `Authorization` header is stripped.

##### 🗳️ User Decision
- [x] **Approve (Proceed with implementation)**
- [ ] **Modify (See notes below)**
- [ ] **Defer (Postpone to future milestone)**
- [ ] **Reject (Skip / Do not implement)**

**Decision Notes / Specific Instructions**:
> _[Fill in your notes, parameters, or custom guidance here]_

---

#### SEC-4: Arbitrary System One URL Validation & Loopback Security Boundaries

- **Identifier**: `SEC-4`
- **Severity**: **Medium** (CWE-319: Cleartext Transmission of Sensitive Information)
- **File Location**: `Examples/MailTriageApp/apps/apple/Packages/AppCore/Sources/AppCore/Services/BackendConfigurationStore.swift` (lines 19–66) & `Sources/LayaFoundationModels/LayaHTTPBackend.swift`

##### Technical Root Cause
`normalizeSystemOneEndpoint` accepts arbitrary strings as custom backend URLs. If a user configures a remote enterprise VPC or custom endpoint using `http://` (unencrypted), the application will attempt to dispatch private email content and authentication bearer tokens over plain HTTP, violating Apple Transport Security (ATS) principles.

##### Remediation Plan
1. **Strict Transport Boundary**: Require `https://` for all remote network endpoints.
2. **Loopback Exception Only**: Permit unencrypted `http://` strictly if the host resolves to loopback addresses (`127.0.0.1`, `localhost`, `::1`).
3. **UI Validation Feedback**: If an invalid or unencrypted remote URL is entered in `SettingsView`, display an inline warning badge and disable the "Save / Test Connection" button.

##### Verification Steps
- Unit test passing `http://remote-server.com/v1` asserts validation error or protocol promotion.
- Unit test passing `http://127.0.0.1:8000/v1` successfully connects to local `laya-serve`.

##### 🗳️ User Decision
- [x] **Approve (Proceed with implementation)**
- [ ] **Modify (See notes below)**
- [ ] **Defer (Postpone to future milestone)**
- [ ] **Reject (Skip / Do not implement)**

**Decision Notes / Specific Instructions**:
> _[Fill in your notes, parameters, or custom guidance here]_

---

### Category 2: Simulation Elimination & Real Inference

```
┌────────────────────────────────────────────────────────────────────────┐
│                   CATEGORY 2: REAL INFERENCE INTEGRITY                 │
│  SIM-1: Eliminate Core ML Mock Fallback  SIM-2: Reject Raw Safetensors │
│  SIM-3: Ground-Truth Determinism & Checksums                          │
└────────────────────────────────────────────────────────────────────────┘
```

#### SIM-1: Eliminate Core ML Silent Mock Fallback Closure in `TriageEngine`

- **Identifier**: `SIM-1`
- **Severity**: **Critical** (Violation of Architectural Principle #5: Deterministic Integrity)
- **File Location**: `Examples/MailTriageApp/apps/apple/Packages/AppCore/Sources/AppCore/Services/TriageEngine.swift`
- **Lines**: 83–90

##### Technical Root Cause
In `TriageEngine.getOrInitializeCoreMLEngine(modelURL:)`, when the real `LayaCoreMLEngine` fails to initialize (e.g. missing weights, incompatible architecture, corrupted files), the catch block silently traps the failure and instantiates a mock engine with a simulated closure returning hardcoded probabilities:
```swift
// TriageEngine.swift:83-90
do {
    let engine = try LayaCoreMLEngine(modelURL: modelURL, tokenizer: tokenizer)
    cachedCoreMLEngine = (url: modelURL, engine: engine)
    return engine
} catch {
    // CRITICAL ISSUE: Silently fakes inference with 85% probability!
    let engine = LayaCoreMLEngine(tokenizer: tokenizer) { _ in
        [0.85, 0.15]
    }
    cachedCoreMLEngine = (url: modelURL, engine: engine)
    return engine
}
```
This causes the reference app to display "92.0% Certainty" and "AUTO EXECUTED" on-device even when no model weights are installed or loaded, completely obscuring operational failures from the developer.

##### Remediation Plan
1. **Remove Silent Mock Fallback**: Delete the fallback closure instantiation from production `TriageEngine.swift`.
2. **Propagate Typed Engine Failure**: If `LayaCoreMLEngine` initialization throws, catch the error and rethrow a structured `BackendUnreachableError`:
   - `reason`: "Core ML Model Load Failure: \(error.localizedDescription)"
   - `guidance`: "The on-device model weights could not be loaded. Please open Settings (⌘,) and re-download or re-import the Core ML model."
3. **Keep Mocks in Test Targets**: Mocks must only be injected via `MockSystemOneBackend` or `MockTriageEngine` within automated test suites.

##### Verification Steps
- Supply a non-existent or dummy file URL to `TriageEngine.triage(email:backend:.onDeviceCoreML)` and verify that it throws `BackendUnreachableError` rather than returning a 92% confidence fake prediction.
- Verify that valid `.mlmodelc` bundles evaluate real inferences.

##### 🗳️ User Decision
- [x] **Approve (Proceed with implementation)**
- [ ] **Modify (See notes below)**
- [ ] **Defer (Postpone to future milestone)**
- [ ] **Reject (Skip / Do not implement)**

**Decision Notes / Specific Instructions**:
> _[Fill in your notes, parameters, or custom guidance here]_

---

#### SIM-2: Reject Raw `.safetensors` as Compiled Core ML Models in `CoreMLModelManager`

- **Identifier**: `SIM-2`
- **Severity**: **High** (Format Incompatibility & Pipeline Failure)
- **File Location**: `Examples/MailTriageApp/apps/apple/Packages/AppCore/Sources/AppCore/Services/CoreMLModelManager.swift`
- **Lines**: 236–238, 244–246, 260–263, 311–312

##### Technical Root Cause
`CoreMLModelManager` treats `.safetensors` files as "precompiled models":
```swift
// CoreMLModelManager.swift:236-237
} else if ext == "mlmodelc" || ext == "safetensors" || ext == "bin" {
    precompiledModel = workingFile
}
```
It then moves `model.safetensors` into Application Support and names it `LayaDecisionModel.mlmodelc`. 
A `.safetensors` file is a raw binary key-value tensor container used by PyTorch/Hugging Face; it is **not** a compiled Core ML model package (`.mlmodelc`). When Apple's `MLModel(contentsOf: url)` attempts to load this file as a Core ML bundle, it fails immediately. This failure directly triggers the silent mock fallback in SIM-1.

##### Remediation Plan
1. **Strict Format Validation**: Update `CoreMLModelManager` to only accept Apple Core ML formats:
   - Uncompiled: `.mlpackage`, `.mlmodel` (which pass through `MLModel.compileModel(at:)`).
   - Compiled: `.mlmodelc` (directories containing Apple Neural Engine bytecode).
2. **Explicit Rejection of Raw Tensors**: If a user attempts to import a `.safetensors` or `.bin` file, throw an explicit, descriptive error:
   - "Raw Hugging Face safetensors cannot be executed directly by Core ML. Please provide a compiled Core ML model (.mlmodelc) or Core ML package (.mlpackage)."
3. **Correct Default Download Asset**: Update `defaultCoreMLDownloadURL` in `BackendConfigurationStore.swift` to point to a genuine compiled Core ML zip archive or release asset, rather than `resolve/main/model.safetensors`.

##### Verification Steps
- Attempt to import a `.safetensors` file via `CoreMLModelManager.importLocalModel` and verify a clean rejection error is displayed in the UI.
- Import a genuine `.mlmodelc` and confirm `MLModel(contentsOf:)` loads successfully without falling back to mocks.

##### 🗳️ User Decision
- [x] **Approve (Proceed with implementation)**
- [ ] **Modify (See notes below)**
- [ ] **Defer (Postpone to future milestone)**
- [ ] **Reject (Skip / Do not implement)**

**Decision Notes / Specific Instructions**:
> _[Fill in your notes, parameters, or custom guidance here]_

---

#### SIM-3: Benchmark Ground-Truth Checksum & Evaluation Parity (`BenchmarkTruthStore`)

- **Identifier**: `SIM-3`
- **Severity**: **Medium** (Dataset Integrity & Reproducibility)
- **File Location**: `Examples/MailTriageApp/apps/apple/Packages/AppCore/Sources/AppCore/Services/BenchmarkTruthStore.swift` & `BenchmarkTruthTests.swift`

##### Technical Root Cause
`BenchmarkTruthStore` loads `benchmark-truth.json` to compute accuracy and calibration metrics in `BatchSummarySheet`. However:
1. There is no cryptographic checksum (SHA-256) validating that the loaded dataset matches the canonical 500-email reference truth.
2. If the ground truth JSON is modified or corrupted in Application Support, benchmarks can silently skew without notice.

##### Remediation Plan
1. **SHA-256 Checksum Verification**: Embed the expected SHA-256 hash of the canonical `benchmark-truth.json` in `BenchmarkTruthStore`.
2. **Automatic Self-Healing**: If the Application Support file does not match the canonical hash, log a warning and fall back to the immutable bundled reference inside `Bundle.module`.
3. **Telemetry UI Indication**: In `BatchSummarySheet`, clearly display whether the accuracy scores were calculated against the verified canonical truth.

##### Verification Steps
- Unit test verifying hash computation and fallback when a corrupted file is written to Application Support.

##### 🗳️ User Decision
- [x] **Approve (Proceed with implementation)**
- [ ] **Modify (See notes below)**
- [ ] **Defer (Postpone to future milestone)**
- [ ] **Reject (Skip / Do not implement)**

**Decision Notes / Specific Instructions**:
> _[Fill in your notes, parameters, or custom guidance here]_

---

### Category 3: PRD Compliance & UI Integration

```
┌────────────────────────────────────────────────────────────────────────┐
│                     CATEGORY 3: PRD COMPLIANCE                         │
│  PRD-1: Attach DecisionActionBarView   PRD-2: Align Urgency Rubric     │
│  PRD-3: Implement Action Button Stubs  PRD-4: Multi-Window Polish      │
└────────────────────────────────────────────────────────────────────────┘
```

#### PRD-1: Align PRD Specifications with Main Toolbar Triage Action (No Code Changes)

- **Identifier**: `PRD-1`
- **Severity**: **High** (Specification Alignment / PRD Update Only)
- **File Location**: `docs/mail-triage-prd.md` & `docs/prd/PRD-2026-09-25-mail-triage-system-one-engine.md`

##### Technical Root Cause
The original PRD-2026-09-25 (FR-4) and ADR-2026-09-25 specified that when viewing an email, a floating decision action bar using Liquid Glass styling should be anchored to the bottom of the message view. During implementation, the triage action was intentionally elevated into the primary application navigation surface—specifically, the sparkles toolbar button in `MailDetailView` and the "Triage All" button in `MailListView`. A floating bottom bar is redundant and detracts from message reading viewport space.

##### Remediation Plan
1. **Retain Main Toolbar Triage Architecture (No UI Code Changes)**: The triage action belongs in the main toolbar (which is already implemented via the sparkles button in `MailDetailView` toolbar and "Triage All" in `MailListView`). DO NOT modify UI code to force a bottom bar.
2. **Update PRD Specifications**: Update the PRDs (`docs/mail-triage-prd.md` and `docs/prd/PRD-2026-09-25-mail-triage-system-one-engine.md`) to formally align with this architectural decision, establishing the main toolbar as the standard interaction locus for triage.

##### Verification Steps
- Verify `docs/mail-triage-prd.md` and `docs/prd/PRD-2026-09-25-mail-triage-system-one-engine.md` are updated to document the toolbar triage action pattern instead of a floating bottom bar.
- Verify `MailDetailView` sparkles button and `MailListView` "Triage All" toolbar button function as expected.

##### 🗳️ User Decision
- [ ] **Approve (Proceed with implementation)**
- [x] **Modify (See notes below)**
- [ ] **Defer (Postpone to future milestone)**
- [ ] **Reject (Skip / Do not implement)**

**Decision Notes / Specific Instructions**:
> The triage action belongs in the main toolbar (which is already implemented via the sparkles button in `MailDetailView` toolbar and "Triage All" in `MailListView`). DO NOT modify UI code to force a bottom bar. Instead, update the PRDs (`docs/mail-triage-prd.md` and `docs/prd/PRD-2026-09-25-mail-triage-system-one-engine.md`) to align with this architectural decision.

---

#### PRD-2: Fix Inverted Urgency Score Rubric in `MailDetailView`

- **Identifier**: `PRD-2`
- **Severity**: **High** (UI State Contradiction / Data Representation Bug)
- **File Location**: `Examples/MailTriageApp/apps/apple/Packages/AppUI/Sources/AppUI/Views/MailDetailView.swift`
- **Lines**: 264–278

##### Technical Root Cause
The canonical schema defined in `EmailTriageDecision.swift` and `DecisionActionBarView.swift` specifies:
- `0` = P0 Critical (Outage / Security Blocker)
- `1` = P1 Urgent (High Priority)
- `2` = P2 Medium (Regular Work)
- `3` = P3 Low (Background Informational)

However, `MailDetailView.triageBanner` inverts these values:
```swift
// MailDetailView.swift:264-271
switch score {
case 3: return ("P0 Critical", .red)    // <-- INVERTED: Should be 0
case 2: return ("P1 High", .orange)     // <-- INVERTED: Should be 1
case 1: return ("P2 Medium", .blue)     // <-- INVERTED: Should be 2
default: return ("P3 Low", .secondary)  // <-- INVERTED: Should be 3
}
```
An incoming P0 security alert (score `0`) displays as "P0 Critical" in the action bar, but simultaneously displays as "P3 Low" in the detail view header banner on the exact same screen!

##### Remediation Plan
1. **Centralize Urgency Metadata**: Add an enum or computed extension on `EmailTriageDecision` or `Int` (`urgencyDisplayLabel` & `urgencyDisplayColor`) so the rubric mapping is single-sourced.
2. **Correct Mapping in `MailDetailView`**: Align the `switch` statement with the schema definition (`0` = P0, `1` = P1, `2` = P2, `3` = P3).

##### Verification Steps
- Unit test validating that for score `0`, both `DecisionActionBarView` and `MailDetailView` produce "P0 Critical" with red tinting.

##### 🗳️ User Decision
- [x] **Approve (Proceed with implementation)**
- [ ] **Modify (See notes below)**
- [ ] **Defer (Postpone to future milestone)**
- [ ] **Reject (Skip / Do not implement)**

**Decision Notes / Specific Instructions**:
> _[Fill in your notes, parameters, or custom guidance here]_

---

#### PRD-3: Implement Functional Stubs for Reply, Forward, and Compose

- **Identifier**: `PRD-3`
- **Severity**: **Medium** (Incomplete UI Workflows)
- **File Location**: `Examples/MailTriageApp/apps/apple/Packages/AppUI/Sources/AppUI/Views/MailDetailView.swift`
- **Lines**: 51–74, 318–335

##### Technical Root Cause
The toolbar buttons for **Reply**, **Reply All**, and **Forward** have empty closures `{}`. Clicking them provides no feedback, does not present a compose sheet, and does not update state. `ComposeMessageSheet` also lacks a working send handler.

##### Remediation Plan
1. **Interactive Reply/Forward Sheets**: Bind Reply and Forward buttons to open `ComposeMessageSheet` pre-populated with:
   - Recipient (sender of active email for Reply; all recipients for Reply All).
   - Subject (`Re: <subject>` or `Fwd: <subject>`).
   - Quoted body snippet.
2. **Send Action Integration**: On tapping "Send", add the drafted message to `MailStore.emails` (as an outgoing/sent item) or dismiss with a brief confirmation banner.

##### Verification Steps
- Tap "Reply" in simulator/macOS; verify compose sheet opens with pre-filled recipient and subject.
- Tap "Send" and verify sheet dismisses smoothly.

##### 🗳️ User Decision
- [x] **Approve (Proceed with implementation)**
- [ ] **Modify (See notes below)**
- [ ] **Defer (Postpone to future milestone)**
- [ ] **Reject (Skip / Do not implement)**

**Decision Notes / Specific Instructions**:
> _[Fill in your notes, parameters, or custom guidance here]_

---

#### PRD-4: Multi-Window & Adaptive Resizability Polish

- **Identifier**: `PRD-4`
- **Severity**: **Low** (UI Polish & Layout Boundaries)
- **File Location**: `Examples/MailTriageApp/apps/apple/Packages/AppUI/Sources/AppUI/Views/MailSplitView.swift` & `MailTriageAppApp.swift`

##### Technical Root Cause
1. On macOS, window resizing below 860px width causes toolbar clipping of the backend selector capsule.
2. On iPadOS split-screen (1/3 split view), sidebar list items truncate category badges.

##### Remediation Plan
1. **Window Frame Constraints**: Apply `.windowResizability(.contentSize)` and set `.frame(minWidth: 920, minHeight: 600)` on macOS.
2. **Adaptive Toolbar Capsule**: In narrow horizontal size classes, collapse `ToolbarBackendSelector` into an icon-only menu button.
3. **Contrast Adjustments**: Verify all text elements against WCAG AA standards in both Light and Dark mode appearances.

##### Verification Steps
- Resize macOS window to minimum width and verify no toolbar controls clip or overlap.
- Test iPad split-screen multitasking in simulator.

##### 🗳️ User Decision
- [x] **Approve (Proceed with implementation)**
- [ ] **Modify (See notes below)**
- [ ] **Defer (Postpone to future milestone)**
- [ ] **Reject (Skip / Do not implement)**

**Decision Notes / Specific Instructions**:
> _[Fill in your notes, parameters, or custom guidance here]_

---

### Category 4: Engineering Hygiene & Concurrency Polish

```
┌────────────────────────────────────────────────────────────────────────┐
│                   CATEGORY 4: HYGIENE & CONCURRENCY                    │
│  IMP-1: Migrate @unchecked Sendable      IMP-2: Typed Domain Errors    │
│  IMP-3: Failure Branch Test Coverage                                  │
└────────────────────────────────────────────────────────────────────────┘
```

#### IMP-1: Migrate `@unchecked Sendable` and Manual `NSLock` to Swift 6 Actors

- **Identifier**: `IMP-1`
- **Severity**: **Medium** (Swift 6 Concurrency Compliance)
- **File Location**: `KeychainService.swift` (line 17), `BackendConfigurationStore.swift` (line 7), `TriageEngine.swift` (line 47), `CoreMLModelManager.swift` (line 8)

##### Technical Root Cause
Multiple critical services suppress compiler concurrency checks with `@unchecked Sendable` and rely on manual `NSLock` synchronization. Under heavy concurrent batch triage (e.g. 500 emails evaluated across 8 worker tasks), manual lock synchronization is susceptible to priority inversion, deadlock, or overlooked lock acquisitions when new fields are introduced.

##### Remediation Plan
1. **Actor Isolation**: Convert `KeychainService` to an `actor KeychainService: KeychainServiceProtocol`.
2. **Engine Thread-Safety**: Refactor `cachedCoreMLEngine` in `TriageEngine` into an isolated cache actor or synchronize via `actor`.
3. **MainActor UI Stores**: Ensure `CoreMLModelManager`, `BackendConfigurationStore`, and `MailStore` are explicitly annotated with `@MainActor` for seamless SwiftUI observation without lock primitives.

##### Verification Steps
- Rebuild workspace with `-strict-concurrency=complete`; verify zero concurrency diagnostics or warnings.

##### 🗳️ User Decision
- [x] **Approve (Proceed with implementation)**
- [ ] **Modify (See notes below)**
- [ ] **Defer (Postpone to future milestone)**
- [ ] **Reject (Skip / Do not implement)**

**Decision Notes / Specific Instructions**:
> _[Fill in your notes, parameters, or custom guidance here]_

---

#### IMP-2: Standardize Structured Domain Errors & Localized User Guidance

- **Identifier**: `IMP-2`
- **Severity**: **Medium** (Error Ergonomics & Diagnosability)
- **File Location**: `AppCore/Services/TriageEngine.swift`, `BackendHealthProbeService.swift`, `CoreMLModelManager.swift`

##### Technical Root Cause
Error throwing frequently constructs ad-hoc `NSError(domain: "CoreMLModelManager", code: 401, userInfo: ...)` or wraps arbitrary strings. This makes granular catch blocks impossible and leads to unlocalized error dialogs in UI layers.

##### Remediation Plan
1. **Structured Enums**: Introduce typed Swift error enums conforming to `LocalizedError`:
   ```swift
   public enum CoreMLError: LocalizedError, Sendable {
       case modelNotFound(URL)
       case compilationFailed(underlying: Error)
       case unsupportedFormat(extension: String)
       case hardwareIncompatible
   }
   ```
2. **Standardized Recovery Guidance**: Provide `recoverySuggestion` strings for every case so UI error popovers always present actionable next steps to the user.

##### Verification Steps
- Unit test asserting that thrown errors provide non-empty `errorDescription` and `recoverySuggestion`.

##### 🗳️ User Decision
- [x] **Approve (Proceed with implementation)**
- [ ] **Modify (See notes below)**
- [ ] **Defer (Postpone to future milestone)**
- [ ] **Reject (Skip / Do not implement)**

**Decision Notes / Specific Instructions**:
> _[Fill in your notes, parameters, or custom guidance here]_

---

#### IMP-3: Expand Automated Test Coverage for Negative Paths & Edge Cases

- **Identifier**: `IMP-3`
- **Severity**: **Low** (Quality Assurance Depth)
- **File Location**: `Examples/MailTriageApp/apps/apple/Packages/AppCore/Tests/AppCoreTests/`, `AppUITests/`

##### Technical Root Cause
Existing unit tests focus primarily on happy paths: mock responses, successful batch completions, and valid configurations. Critical real-world failure modes—such as batch cancellation halfway through, network timeout retry exhaustion, corrupted model weights, and locked keychain access—are not covered by automated regression tests.

##### Remediation Plan
1. **Batch Cancellation Test**: Test `triageBatch` cancellation via `Task.cancel()` and assert workers terminate immediately without leaks.
2. **Retry Exhaustion Test**: Verify `TriageEngine` handles HTTP 429/503 exhaustion cleanly.
3. **Corrupted Model Test**: Verify attempting to load a corrupted `.mlmodelc` triggers the newly standardized `CoreMLError` with user guidance.

##### Verification Steps
- Run `swift test` and verify new test suites pass deterministically in offline environments.

##### 🗳️ User Decision
- [x] **Approve (Proceed with implementation)**
- [ ] **Modify (See notes below)**
- [ ] **Defer (Postpone to future milestone)**
- [ ] **Reject (Skip / Do not implement)**

**Decision Notes / Specific Instructions**:
> _[Fill in your notes, parameters, or custom guidance here]_

---

## 5. Implementation Roadmap & Execution Sequence

When approved, the recommended implementation order follows strict architectural dependencies:

```
┌─────────────────────────────────────────────────────────────────────────┐
│                      PHASED EXECUTION PIPELINE                          │
│                                                                         │
│  Phase 1: Security & Credential Isolation (SEC-1, SEC-2, SEC-3, SEC-4) │
│     │                                                                   │
│     ▼                                                                   │
│  Phase 2: Real Inference & Model Validation (SIM-1, SIM-2, SIM-3)      │
│     │                                                                   │
│     ▼                                                                   │
│  Phase 3: PRD Compliance & UI Alignment (PRD-1, PRD-2, PRD-3)          │
│     │                                                                   │
│     ▼                                                                   │
│  Phase 4: Concurrency Actors & Domain Errors (IMP-1, IMP-2, IMP-3)      │
│     │                                                                   │
│     ▼                                                                   │
│  Phase 5: Full QA Verification & Simulator Visual Proof                 │
└─────────────────────────────────────────────────────────────────────────┘
```

1. **Phase 1: Security Hardening (SEC-1 – SEC-4)**:
   - Implement Keychain migration, eliminate `UserDefaults` secrets, ensure `.env` is gitignored with `.env.example` checked in, enforce environment variable precedence in tests, remove `.env` crawling in release builds, and sanitize Hugging Face tokens and URLs.
2. **Phase 2: Inference Integrity (SIM-1 – SIM-3)**:
   - Strip silent mock closures from `TriageEngine`, reject invalid `.safetensors` files in `CoreMLModelManager`, and enforce model package integrity.
3. **Phase 3: UI & PRD Integration (PRD-1 – PRD-4)**:
   - Update PRDs for toolbar triage action alignment (PRD-1, no UI code changes), correct the urgency score rubric (PRD-2), and connect toolbar action buttons (PRD-3).
4. **Phase 4: Concurrency & Error Polish (IMP-1 – IMP-3)**:
   - Modernize services to actors, standardize domain error enums, and expand test coverage for negative failure modes.
5. **Phase 5: Final Verification Gate**:
   - Re-run test suites across all packages, re-compile with FlowDeck CLI, and capture updated simulator screenshots proving live triage operation.

---

## 6. Verification & Quality Gates

Any work completed under this remediation plan must satisfy the following strict criteria before closing:

1. **Compiler Diagnostics Gate**:
   - Clean build across macOS and iOS Simulator targets with `flowdeck build`.
   - Zero errors, zero compiler warnings under Swift 6 strict concurrency (`-strict-concurrency=complete`).
2. **Automated Testing Gate**:
   - 100% pass rate across all test targets (`SystemOneFoundationModels`, `AppCore`, `AppUI`).
   - If required API keys are absent from `ProcessInfo.processInfo.environment`, tests requiring them fail explicitly rather than falling back to fake mocks.
   - No offline tests may make live network requests without explicit configuration.
3. **Security Audit Gate**:
   - Verify `UserDefaults.standard.dictionaryRepresentation()` contains zero API keys or bearer tokens.
   - Run Mach-O binary strings inspection confirming zero developer source machine paths (`#filePath`).
   - Verify `.env` is gitignored and `.env.example` exists.
4. **Visual & Simulator Proof Gate**:
   - Verify the main toolbar triage action button executes triage and transitions state properly.
   - Capture video or step-by-step logs demonstrating the transition from Untriaged to Triaged state upon tapping toolbar triage.
5. **Documentation Sync Gate**:
   - Update `docs/mail-triage-prd.md` and `docs/prd/PRD-2026-09-25-mail-triage-system-one-engine.md` to reflect the main toolbar triage action design.
   - Update `tech-notes/` with any discoveries regarding Core ML model management or Swift 6 actor migrations.
   - Log completion in `docs/journal/` and synchronize `README.md`.

---

## 7. Approval Sign-Off Gate

Please indicate your overall sign-off and selection below:

```markdown
### 📋 Stakeholder Sign-Off
- [x] **Approved to Proceed with Customized Decisions**
- [ ] **Revisions Requested (See comments below)**

**Approved By**: User / Stakeholder
**Date**: 2026-09-25
**Selected Execution Bundle**: Customized (Approved with modifications on SEC-1, SEC-2, PRD-1; Approved SEC-3..4, SIM-1..3, PRD-2..4, IMP-1..3)

**General Feedback / Special Instructions**:
> User reviewed and approved the plan with customized guidance:
> 1. **SEC-1**: Ensure `.env` is gitignored, provide a `.env.example` sample file to check in. Write strictly into Keychain and NOT into UserDefaults.
> 2. **SEC-2**: If the required API keys are present in the environment (`ProcessInfo.processInfo.environment`), use them, otherwise fail the respective test.
> 3. **PRD-1**: The triage action belongs in the main toolbar (which is already implemented via the sparkles button in `MailDetailView` toolbar and "Triage All" in `MailListView`). DO NOT modify UI code to force a bottom bar. Instead, update the PRDs (`docs/mail-triage-prd.md` and `docs/prd/PRD-2026-09-25-mail-triage-system-one-engine.md`) to align with this architectural decision.
```
```

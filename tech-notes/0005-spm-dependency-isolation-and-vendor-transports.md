# 0005 — SPM Dependency Isolation & Decoupling Vendor Transports

- **Date**: 2026-09-22
- **Author**: Peter Friese
- **Framework**: `Swift Package Manager`, `FoundationModels` (iOS 27.0+, macOS 27.0+)
- **Upstream**: Firebase App Check, Apple App Attest, TypeSafe AI Jev

---

## Context

As `JevFoundationModels` introduced support for hardware-attested transports (such as `FirebaseAppCheckTransport`), an architectural question emerged:

> *Since `FirebaseAppCheckTransport` provides a flexible, production-ready implementation supporting both cached and single-use tokens, should it be migrated from `Integrations/` directly into the core `Sources/JevFoundationModels` library?*

A frequent assumption is that wrapping the transport in `#if canImport(FirebaseAppCheck)` would allow it to reside within the core package, compiling only for application targets that link the Firebase SDK.

This tech note examines the mechanics of Swift Package Manager module isolation, root dependency graph resolution, and why keeping vendor transports decoupled preserves the architectural integrity of the core library.

---

## Findings

### 1. The SPM `canImport` Isolation Sandbox
In Swift Package Manager, compilation occurs in strictly isolated target sandboxes:
- When a client application adds `JevFoundationModels` and `FirebaseAppCheck` to its project, SPM compiles `JevFoundationModels` **solely against the dependencies declared in `JevFoundationModels`'s own `Package.swift`**.
- SPM does **not** expose dependencies from consumer applications or sibling packages downward into library targets during compilation.
- Consequently, `#if canImport(FirebaseAppCheck)` evaluated inside `Sources/JevFoundationModels` **always resolves to `false`**, regardless of whether the consuming Xcode project imports Firebase.

The transport would either silently compile dead code (the empty `#else` branch, resulting in missing token headers and runtime `401 Unauthorized` errors) or fail to build.

### 2. Root Manifest Dependency Graph Cascades
To make `canImport(FirebaseAppCheck)` evaluate to `true` within `Sources/`, `firebase-ios-sdk` would have to be declared in `Package.swift`.

Even if segregated into a separate library product or target (e.g., `JevFirebase`):
- **Universal Package Resolution:** SPM resolves, downloads, and caches all package repositories listed in the root `Package.swift` dependencies array, even if a consumer's target only links the core `JevFoundationModels` library product.
- **Dependency Bloat:** Pulling in `firebase-ios-sdk` forces every consumer to clone and resolve large transitive dependencies, including Google C++ utilities, Protobuf, LevelDB, and BoringSSL.
- **Build Time Impact:** `JevFoundationModels` currently builds cleanly in **~1.0 second** and runs full automated test suites in **~0.2 seconds**. Introducing Firebase increases clean checkout and compilation times by 30 to 60 seconds.

### 3. Preserving Zero Runtime Dependencies
A founding tenet of `JevFoundationModels` is **Zero External Third-Party Runtime Dependencies**.
- The core package relies exclusively on native Apple platform frameworks (`FoundationModels`, `UniformTypeIdentifiers`, `URLSession`).
- This design maximizes platform portability, minimizes vulnerability surfaces, and eliminates dependency version locks across diverse Apple platforms (iOS 27+, macOS 27+, visionOS 27+).

### 4. SDK Churn & API Evolution in Security Features
Hardware attestation and replay protection features (such as Firebase limited-use tokens with `{ consume: true }`) are subject to active platform refinements.
- Providing `FirebaseAppCheckTransport.swift` as a reference drop-in file empowers application engineers to tailor error propagation, token retries, and network telemetry to match their specific application architecture without requiring semver updates in the core bridge.

---

## Implications

1. **Keep Vendor Transports Decoupled:**
   Vendor-specific transports (Firebase App Check, Cloudflare Turnstile, AWS Cognito, etc.) must remain outside the core `Package.swift` dependency tree.
2. **Drop-In Reference Pattern:**
   The `Integrations/` directory serves as the official distribution channel for reference transports and proxy infrastructure. Developers copy the single Swift file directly into their app target where their vendor SDK is already linked.
3. **Future Extensibility (Post-1.0 Companion Repositories):**
   If community demand for pre-packaged vendor transports grows, they should be released as dedicated companion repositories (e.g., `jev-foundation-models-firebase`) that depend on both `jev-foundation-models` and the respective vendor SDK, keeping the primary repository completely pure.

---

## Sources & References

- Swift.org: [Swift Package Manager Target Dependency Isolation](https://www.swift.org/package-manager/)
- Apple Developer: [Swift Compiler Directives (`canImport`)](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/statements/#Conditional-Compilation-Block)
- Firebase iOS SDK: [Firebase App Check Documentation](https://firebase.google.com/docs/app-check/ios)
- Jev Foundation Models: [Mobile Security Guide](../docs/mobile-security.md)

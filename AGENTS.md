# Workspace Agent Rules: Jev Foundation Models

## Purpose & Scope
This repository (`jev-foundation-models`) is a Swift 6 package providing a native bridge between **Apple's Foundation Models framework** (`LanguageModel`, `LanguageModelExecutor`, `@Generable`) and **TypeSafe AI's Jev** System One decision model.

It allows developers on Apple platforms (iOS 27+, macOS 27+, visionOS 27+) to evaluate strongly typed `@Generable` structs and enums against application state using fast, calibrated decision models instead of text-generating LLMs.

---

## Architectural Principles & Standards

### 1. Apple-Native Foundation Models Ergonomics
- The primary developer experience must use standard Apple Foundation Models APIs:
  ```swift
  let session = LanguageModelSession(model: JevLanguageModel(apiKey: "..."))
  let response = try await session.respond(to: stateText, generating: MyDecision.self)
  ```
- No proprietary wrapper syntax or non-standard session classes. Conformance to `LanguageModel` and `LanguageModelExecutor` is mandatory.

### 2. Swift 6 Concurrency & Stratos Compliance
- Complete strict concurrency checking (`-strict-concurrency=complete`).
- Value types must naturally conform to `Sendable`.
- Avoid `@unchecked Sendable` unless wrapping proven thread-safe primitives (with explicit comments).
- Do not introduce blocking operations in async contexts.
- Follow **Call-Site First** design (`stratos-swift`): demonstrate the ideal call-site before writing implementation code.

### 3. Jev Decision Primitives Mapping
The bridge translates Foundation Models generation schemas to TypeSafe System One questions:
- `Bool` properties $\to$ Jev **`noul`** (0.0 – 1.0 probability of truth).
- `enum` properties / `anyOf` $\to$ Jev **`choice`** (discrete categorical selection).
- `@Guide(description: "...")` $\to$ question **`instructions`**.
- `@Guide(.range(...))` $\to$ Jev **`score`** (ordinal rubric scoring).
- Bounded decision outputs only: unstructured prose requests without a `@Generable` schema must throw an informative, typed error (`JevError.structuredOutputRequired`).

### 4. Zero External Third-Party Runtime Dependencies
- Keep the library core lightweight.
- Use native `URLSession`, `JSONDecoder`, and `JSONSerialization` for networking. Do not introduce heavy third-party HTTP clients.

### 5. Deterministic, Offline-First Automated Testing
- All core unit tests must be executable without requiring a live `TYPESAFE_API_KEY`.
- Provide a `MockJevTransport` / `MockJevExecutor` to test schema translation, error handling, and JSON response synthesis offline.
- Use modern **Swift Testing** (`@Test`, `#expect`) instead of legacy XCTest.

### 6. Tech Note Curation
- Any time an Apple Foundation Models SDK quirk, undocumented behavior, compilation discrepancy, platform restriction, or serialization nuance is discovered or required debugging, immediately document it in `tech-notes/`.
- **File Naming & Structure**:
  - File path: `tech-notes/NNNN-kebab-slug.md` (sequential `max + 1`, e.g. `0005-my-finding.md`).
  - Standard Template:
    - `# NNNN — Short Title`
    - Metadata: Date (`YYYY-MM-DD`), Author, Framework (`FoundationModels`), Upstream.
    - Sections: `## Context`, `## Findings`, `## Implications`, `## Evidence / Sources`.
- **Index & Cross-Referencing**:
  - Always update the index table in `tech-notes/README.md`.
  - Embed inline code comments in relevant Swift files: `// See tech-notes/NNNN-short-title.md`.

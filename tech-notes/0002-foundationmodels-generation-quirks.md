# 0002 — Apple Foundation Models Generation Nuances & Single-Frame Stream Delimiters

- **Date**: 2026-09-21
- **Author**: Peter Friese
- **Framework**: `FoundationModels` (iOS 27.0+, macOS 27.0+)
- **Upstream**: TypeSafe AI Jev (System One)

---

## Context
While implementing the native bridge between Apple's Foundation Models framework and TypeSafe AI's Jev System One decision model, several SDK quirks, API shape nuances, and serialization expectations were identified in Xcode 27 Beta (macOS 27.0+).

---

## Findings

### 1. Root Enum vs Struct Decoding Delimiters
When `session.respond(to: ..., generating: MyType.self)` is invoked, Apple's internal decoding engine processes the synthesized text emitted into `LanguageModelExecutorGenerationChannel`. The format expected by the engine differs depending on whether the root `@Generable` type is a Swift `struct` or `enum`:

- **Root Struct (`@Generable struct`)**:
  The framework expects standard serialized JSON object syntax:
  ```json
  {"isUrgent": true, "department": "billing"}
  ```
- **Root Enum (`@Generable enum: String`)**:
  The framework expects the **bare unquoted case string**:
  ```text
  billing
  ```
  Delivering JSON-quoted strings (e.g. `"\"billing\""`) causes a fatal decoding exception:
  `Fatal error: Unexpected rawValue "\"billing\"" for MyEnum`.

`ResponseSynthesizer` distinguishes between `.object` and `.choice` root layouts to emit bare strings for root enums and formatted JSON objects for structs.

### 2. `LanguageModelCapabilities` Initialization
Unlike earlier conceptual drafts, `LanguageModelCapabilities` does not accept boolean keyword arguments (`supportsTools: Bool, supportsStructuredOutput: Bool`). Instead, capabilities are configured using a collection of `Capability` values:
```swift
public var capabilities: LanguageModelCapabilities {
    LanguageModelCapabilities([.guidedGeneration])
}
```
Available capabilities include `.guidedGeneration`, `.vision`, `.reasoning`, and `.toolCalling`. Callers test capabilities via `model.capabilities.contains(.guidedGeneration)`.

### 3. Channel Response Action Text Emission
In `LanguageModelExecutorGenerationChannel.Response.Action`, text streaming is performed using:
```swift
Action.appendText(_ text: String, segmentID: String? = nil, tokenCount: Int)
```
rather than `.text(String)`. `ResponseSynthesizer` feeds the complete single-frame payload into `.appendText(synthesizedText, tokenCount: tokenCount)` with the output token count from Jev's usage metadata.

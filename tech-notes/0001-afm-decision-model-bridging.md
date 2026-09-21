# 0001 — Bridging Decision Models into Apple Foundation Models via Channel Synthesis

- **Date**: 2026-09-21
- **Author**: Peter Friese
- **Framework**: `FoundationModels` (iOS 27.0+, macOS 27.0+)
- **Upstream**: TypeSafe AI Jev (System One)

---

## Context
Apple's Foundation Models framework was designed primarily for generative LLMs that produce streaming text deltas via `LanguageModelExecutorGenerationChannel.send(.response(entryID: ..., action: .text(chunk)))`.

Decision models like TypeSafe's Jev operate under a different paradigm: they take application state and a set of typed questions, evaluate them concurrently in a single feed-forward pass, and return calibrated probabilities and discrete categorical decisions in 40–150ms.

---

## Findings

### 1. Single-Frame JSON Delivery
When `session.respond(to: ..., generating: MyType.self)` is called, the framework attaches a `GenerationSchema` to `LanguageModelExecutorGenerationRequest.schema`.
The framework's internal decoding engine expects the generation channel to stream text representing valid JSON matching the schema.

Because decision models return answers instantaneously as discrete values, we do not need incremental token streaming. The executor synthesizes the complete JSON representation in a single string and delivers it in one event:
```swift
await channel.send(.response(entryID: entryID, action: .text(synthesizedJSON)))
```
The framework immediately finishes generation and decodes the object into `MyType`.

### 2. Preserving Calibrated Probabilities in Metadata
Unlike LLMs where confidence must be approximated through logprobs, Jev directly outputs calibrated probability distributions and confidence scores for each question.
We can preserve these rich decision analytics by emitting a metadata update event before channel completion:
```swift
await channel.send(.response(entryID: entryID, action: .updateMetadata([
    "model": jevResponse.model,
    "probabilities": jevResponse.probabilitiesJSON,
    "confidence": jevResponse.confidenceJSON
])))
```
Callers can access these values on `response.metadata`.

### 3. Rejecting Unstructured Text Requests Early
Because Jev is a System One decision model, requesting free-form text without a `@Generable` schema (e.g. `session.respond(to: "Tell me a joke")`) is invalid. If `request.schema == nil`, the executor should fail fast with a clear error:
```swift
guard let schema = request.schema else {
    throw JevError.structuredOutputRequired
}
```
This prevents meaningless API requests and guides developers toward type-safe usage.

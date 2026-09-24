# 0007 — Pluggable System One Backends & Wire Compatibility with Laya HTTP Serving

- **Date**: 2026-09-24
- **Author**: Peter Friese
- **Framework**: `FoundationModels` (iOS 27.0+, macOS 27.0+), `SystemOneCore`
- **Upstream**: NandhaKishorM/laya (PR #31), TypeSafe AI Jev

---

## Context

The initial bridge in this package was tailored specifically to TypeSafe AI's Jev System One cloud API. However, non-autoregressive decision models are increasingly self-hosted or deployed across heterogeneous environments.

In `NandhaKishorM/laya`, PR #31 introduced `laya-serve`—a high-performance HTTP server exposing `POST /v1/systemone` that speaks the exact wire protocol of TypeSafe Jev. Rather than creating disjoint packages or fragmented client abstractions, the architecture needed to evolve into a unified, pluggable System One engine while preserving 100% backwards compatibility for existing `JevFoundationModels` consumers.

This tech note analyzes the wire compatibility characteristics between Jev and `laya-serve`, the pluggable `SystemOneBackend` protocol design, and the mechanics of auth handling and endpoint presets.

---

## Findings

### 1. Wire Schema Parity between Jev and Laya
Laya's internal `predict()` output structure is byte-for-byte schema-identical to TypeSafe Jev's `/v1/systemone` specification:
- Both models return typed questions partitioned into:
  - `choice`: Discrete categorical selection with normalized option keys and probability mass.
  - `score`: Rubric-based ordinal level rating with expected numeric score and level distribution.
  - `noul`: Calibrated truth probability `noul` in `[0.0, 1.0]`.
- Both models return a standardized usage block:
  ```json
  "usage": {
    "input_tokens": 85,
    "output_tokens": 0
  }
  ```
- Because non-autoregressive models execute in a single forward pass, `output_tokens` is either 0 or minimal (metadata frame), unlike autoregressive LLMs.

### 2. Optional Bearer Authentication in `laya-serve`
In `laya/serve.py`, authentication is governed by the `LAYA_API_KEY` environment variable:
- When `LAYA_API_KEY` is **unset** (the default for local container quickstarts and developer environments), the server accepts incoming requests without an `Authorization` header. Sending a `Bearer` token to an unauthenticated server is ignored, but sending requests without an authorization header to an authenticated server returns `401 Unauthorized`.
- When `LAYA_API_KEY` is **set**, clients must supply `Authorization: Bearer <token>`.
- `LayaHTTPBackend` accommodates both paradigms: if `apiKey` is provided and non-empty, the header is attached; if `apiKey` is omitted (`nil`), the header is cleanly excluded.

### 3. Latency Metrics and Gateway Telemetry
Both TypeSafe Jev and `laya-serve` (when behind Envoy, Traefik, or reverse proxies) emit execution metrics:
- Upstream gateways emit the `x-envoy-upstream-service-time` header indicating server-side inference duration in milliseconds.
- `LayaHTTPBackend` extracts this header and populates `response.serverDurationMs`, making latency profiling accessible directly through `LanguageModelSession.Response` telemetry extensions.

### 4. Pluggable `SystemOneBackend` Protocol
By extracting the foundational DTOs and generation pipeline into `SystemOneCore`, the bridge decouples Apple's `LanguageModelExecutor` from the transport:
```swift
public protocol SystemOneBackend: Sendable {
    func evaluate(request: SystemOneRequest) async throws -> SystemOneResponse
}
```
`SchemaTranslator` and `ResponseSynthesizer` operate entirely on `SystemOneRequest` and `SystemOneResponse`. The concrete backend (TypeSafe Jev, `laya-serve`, on-device Core ML, or offline mocks) is simply injected into `SystemOneLanguageModel` or wrapped by dedicated facades (`LayaLanguageModel`, `JevLanguageModel`).

---

## Implications

1. **Zero Call-Site Friction**:
   Developers interact solely with standard Apple `LanguageModelSession` APIs:
   ```swift
   let model = LayaLanguageModel(endpoint: .localDefault)
   let session = LanguageModelSession(model: model)
   let response = try await session.respond(to: text, generating: MyDecision.self)
   ```
2. **Preset Ergonomics**:
   `LayaEndpoint` offers first-class presets for common deployment topologies:
   - `.localDefault`: `http://127.0.0.1:8000/v1/systemone` (standard `laya-serve` port)
   - `.localAlt`: `http://127.0.0.1:8770/v1/systemone` (common multi-service development port)
   - `.hosted`: `https://api.impossibl.com/v1/systemone`
   - `.local(port:)` and `.custom(URL)` for tailored infrastructure.
3. **Full Backwards Compatibility**:
   Existing applications importing `JevFoundationModels` continue to compile without edits:
   `JevLanguageModel` delegates to `SystemOneLanguageModel` with `JevBackend: SystemOneBackend`, and all legacy DTOs are mapped via `@_exported` typealiases.

---

## Sources & References

- GitHub: [NandhaKishorM/laya PR #31: Add self-hostable HTTP server](https://github.com/NandhaKishorM/laya/pull/31)
- TypeSafe AI: [System One Decision Model API Specification](https://docs.typesafe.ai/api.md)
- RFC 6750: [The OAuth 2.0 Authorization Framework: Bearer Token Usage](https://datatracker.ietf.org/doc/html/rfc6750)
- Tech Note 0001: [Bridging Decision Models into Apple Foundation Models via Channel Synthesis](0001-afm-decision-model-bridging.md)

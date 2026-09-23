# 0006 — HTTP Resilience, RFC 9110 Backoff & Calibrated Decision Routing in System One Foundation Models Bridge

- **Date**: 2026-09-23
- **Author**: Peter Friese
- **Framework**: `FoundationModels` (iOS 27.0+, macOS 27.0+, visionOS 27.0+)
- **Upstream**: TypeSafe AI Jev (System One), RFC 9110 HTTP Semantics

---

## Context

Because TypeSafe AI's Jev is a System One decision model evaluating typed `@Generable` schemas in sub-100ms, it is deployed in continuous, high-frequency operational pipelines (interactive UI typing, Safari share extensions, directory batch sorting, transactional triage).

In these operational loops:
1. Network transients and API rate limits (HTTP 429) or gateway saturation (HTTP 529) must be absorbed gracefully without dropping tasks.
2. Cooperative cancellation from Swift 6 structured concurrency (e.g., SwiftUI view dismissal or user cancellation) must terminate immediately without being swallowed by error-mapping catch blocks.
3. The framework must provide a principled bridge from calibrated probabilities to programmatic actions (`.auto`, `.confirm`, `.escalate`).

---

## Findings

### 1. Cooperative Concurrency Cancellation across Sleep and Network Boundaries
Apple's Foundation Models framework executes within Swift 6 structured concurrency tasks (`Task { ... }`).
When a generation task is cancelled, `URLSession.data(for:)` throws `URLError(.cancelled)` or `CancellationError`, and `Task.sleep(for:)` throws `CancellationError`.

A common failure mode in custom transport layers is wrapping all thrown errors in a domain error enum (e.g. `catch { throw JevError.networkError(error.localizedDescription) }`). This breaks cooperative cancellation: the task fails to observe cancellation, causing parent task groups to hang or execute unnecessary retries.

**Solution**:
```swift
do {
    (data, response) = try await session.data(for: urlRequest)
} catch is CancellationError {
    throw CancellationError()
} catch let urlError as URLError where urlError.code == .cancelled {
    throw CancellationError()
} catch {
    throw JevError.transport(error.localizedDescription)
}
```
During backoff delays, `try await sleep(delay)` propagates `CancellationError` directly without catching or retrying.

### 2. Duration Saturation Safety & RFC 9110 Compliance
Calculating exponential backoff requires multiplying Swift `Duration` by floating-point multipliers:
$$\text{delay} = \text{initialDelay} \times \text{multiplier}^{\text{attempt} - 1} \times (1 + \text{jitter} \times (2r - 1))$$

In Swift 6, direct floating-point multiplication on `Duration` is not in the standard library. Scaling nanoseconds naively can overflow 64-bit signed integers if configured with extreme parameters, trapping at runtime.

**Solution**:
We convert seconds and attoseconds into nanoseconds, rounding to keep intermediate representations exact:
```swift
extension Duration {
    public static func * (lhs: Duration, rhs: Double) -> Duration {
        guard rhs.isFinite, rhs > 0 else { return .zero }
        let seconds = Double(lhs.components.seconds) + Double(lhs.components.attoseconds) * 1e-18
        let nanoseconds = (seconds * rhs * 1_000_000_000).rounded()
        guard nanoseconds.isFinite, nanoseconds < Double(Int64.max) else { return .saturated }
        return .nanoseconds(Int64(nanoseconds))
    }

    public static var saturated: Duration { .nanoseconds(Int64.max) }
}
```
For `Retry-After`, RFC 9110 permits both integer seconds (`"12"`) and three HTTP date formats (`IMF-fixdate`, `RFC 850`, and ANSI C `asctime()`). Parsing both and capping with `maxRetryAfter` ensures server instructions are honored accurately without jitter distortion.

### 3. Epistemic Uncertainty vs. Decisiveness in Noul Routing
In LLMs, boolean outputs are binary tokens (`"true"` / `"false"`). In System 1 models, boolean (`noul`) queries yield continuous, calibrated probabilities.

- **A probability near 0.5 communicates maximum uncertainty**, not "half true". A hard $\ge 0.5$ cutoff turns $0.49$ vs. $0.51$ into an arbitrary flip.
- **A probability of 0.03 is a highly decisive "no"**. Adopting a negative answer with confidence is just as actionable as adopting a positive one.

**Solution**:
`RoutingPolicy` introduces an explicit undecided band ($0.35\dots0.65$ by default) where `answer` is `nil` and the decision is `.escalate`. Distance from uncertainty is measured via `decisiveness = max(p, 1 - p)`:
```swift
let judgement = response.judgement(for: "isUrgent", policy: policy)
switch judgement.decision {
case .auto:
    // Decisive true (≥ 0.85) OR decisive false (≤ 0.15)
    if judgement.answer == true { dispatchP0() }
case .confirm:
    // Leaning answer (0.65...0.84 or 0.16...0.34)
    askUser()
case .escalate:
    // Inside undecided band (0.35...0.65) or unanswered
    handToHuman()
}
```

### 4. Telemetry Preservation without Breaking AFM Conventions
Apple's Foundation Models framework expects `@Generable` structs and enums to decode directly from generation channel text. Rather than breaking Apple's standard call site with custom wrapper classes, we emit probabilities, confidence scores, and `ScoreValue` models into `LanguageModelExecutorGenerationChannel` metadata:
```swift
await channel.send(.response(entryID: entryID, action: .updateMetadata([
    "model": GeneratedContent(jevResponse.model),
    "probabilities": GeneratedContent(probsJSON),
    "confidence": GeneratedContent(confJSON),
    "scores": GeneratedContent(scoresJSON)
])))
```
These are accessed idiomatically via `response.probability(for:)`, `response.scoreValue(for:)`, `response.decision(for:)`, and `response.judgement(for:)`.

---

## Implications

1. **Production Reliability**: High-volume applications (e.g., ticket triage and file scanning) survive API gateway pressure without process termination.
2. **Deterministic UI Responsiveness**: Interactive iOS and visionOS applications can cancel in-flight evaluations immediately when views transition.
3. **Safe Automation**: Gating operations on calibrated confidence prevents silent misclassifications.
4. **Zero-Dependency Arch**: All resilience and routing primitives are self-contained in native Swift 6.

---

## Evidence / Sources

- [RFC 9110: HTTP Semantics — Section 10.2.3 (Retry-After)](https://www.rfc-editor.org/rfc/rfc9110.html#section-10.2.3)
- [Apple Developer Documentation: Swift 6 Structured Concurrency](https://developer.apple.com/documentation/swift/concurrency)
- [TypeSafe AI: Jev Confidence Routing Guidance](https://docs.typesafe.ai/)

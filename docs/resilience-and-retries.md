# HTTP Resilience, Retries & Error Handling

System One decision models are deployed in operational event loops and high-throughput ingestion pipelines. `JevFoundationModels` incorporates enterprise-grade network resilience, RFC 9110 retry backoff, and Swift 6 concurrency protections.

---

## 🔁 `RetryPolicy` Architecture

The default `URLSessionTransport` includes an automated retry loop for transient failures:

```swift
let retryPolicy = RetryPolicy(
    maxAttempts: 3,                          // Initial attempt + up to 2 retries
    initialDelay: .milliseconds(500),         // First retry delay
    multiplier: 2.0,                         // Doubles backoff for subsequent attempts
    jitter: 0.2,                             // Multiplies delay by random factor in 0.8...1.2
    retryableStatuses: [429, 529],           // Single source of truth for retryable status codes
    maxRetryAfter: .seconds(60)              // Maximum ceiling for server-supplied Retry-After
)

let model = JevLanguageModel(apiKey: apiKey, retryPolicy: retryPolicy)
let session = LanguageModelSession(model: model)
```

### 1. Exponential Backoff with Jitter
To prevent the "thundering herd" problem when an upstream gateway becomes overloaded, delays are spread randomly:
$$\text{delay} = \text{initialDelay} \times \text{multiplier}^{\text{attempt} - 1} \times (1 + \text{jitter} \times (2r - 1)), \quad r \in [0, 1]$$

### 2. Duration Saturation Safety
Calculations scale nanoseconds safely and clamp to `.saturated` (`Int64.max` nanoseconds) on floating-point overflow, eliminating runtime traps under extreme configurations.

### 3. RFC 9110 `Retry-After` Adherence
When the TypeSafe AI gateway sends a `Retry-After` header with a 429 response, `RetryPolicy`:
- Supports integer seconds (e.g., `Retry-After: 5`).
- Supports standard RFC 9110 HTTP-dates (IMF-fixdate, RFC 850, and ANSI C `asctime()`).
- Honors the exact server-supplied delay without random jitter, capped at `maxRetryAfter`.

---

## 🛑 Swift Concurrency Cooperative Cancellation

In Swift 6, cooperative cancellation must not be swallowed or converted into generic domain errors:

1. **`CancellationError` is NEVER wrapped in `JevError`:**
   If a task is cancelled while `session.data(for:)` or `Task.sleep` is executing, `CancellationError` propagates directly to the caller.
2. **Immediate Task Halting:**
   Backoff sleeps between retries listen for task cancellation and abort immediately.

```swift
let task = Task {
    try await session.respond(to: ticket, generating: TicketTriage.self)
}

// User navigates away in SwiftUI or dismisses modal:
task.cancel()

do {
    let response = try await task.value
} catch is CancellationError {
    print("Generation cancelled cleanly by user.")
} catch let error as JevError {
    print("Jev failure: \(error)")
}
```

---

## 📑 Error Taxonomy Reference

All failures outside of cooperative cancellation throw strongly typed `JevError` instances:

| `JevError` Case | HTTP Status / Trigger | Retried? | Diagnostic Description |
| :--- | :---: | :---: | :--- |
| `.apiError(statusCode:message:)` | **401, 422, 429, 529, other HTTP errors** | Configurable | Preserves the original status code and server body, including rate-limit `Retry-After` details after retries are exhausted. |
| `.networkError(String)` | Network | ❌ No | URLSession connection drop, invalid HTTP response, or DNS failure (excluding cancellation). |
| `.structuredOutputRequired` | Client | ❌ No | Request called without a `@Generable` schema. |
| `.invalidSchema(String)` | Client | ❌ No | Schema contains unconstrained `String` or unsupported types. |
| `.decodingError(String)` | Client | ❌ No | JSON serialization or schema decoding failure. |

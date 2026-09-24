# Architecture & Execution Pipeline

`JevFoundationModels` implements Apple's Foundation Models provider protocols to present TypeSafe AI's Jev decision model as a first-class `LanguageModel`.

---

## High-Level Sequence Flow

```
┌────────────────────────────────────────────────────────────────────────┐
│                        LanguageModelSession                            │
│  session.respond(to: "...", generating: TicketTriage.self)             │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │
                         passes GenerationRequest
                  (transcript: Transcript, schema: GenerationSchema)
                                    │
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│                             JevExecutor                                │
│                                                                        │
│  1. SchemaTranslator                                                   │
│     Translates GenerationSchema properties to Jev JSON questions       │
│     (Bool -> noul, enum -> choice, range -> score)                     │
│                                                                        │
│  2. JevClient                                                          │
│     POST https://api.typesafe.ai/v1/systemone                          │
│     Payload: { state: "...", questions: { ... } }                      │
│                                                                        │
│  3. ResponseSynthesizer                                                │
│     Converts Jev answers into canonical JSON matching TicketTriage     │
│                                                                        │
│  4. Channel Stream                                                     │
│     channel.send(.response(..., action: .text(synthesizedJSON)))       │
│     channel.send(.response(..., action: .updateMetadata([...])))       │
│     channel.send(.response(..., action: .updateUsage(...)))            │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│              LanguageModelExecutorGenerationChannel                    │
│  Framework decodes synthesized JSON directly into typed TicketTriage   │
└────────────────────────────────────────────────────────────────────────┘
```

---

## Core Components

### 1. `JevLanguageModel`
- Implements `LanguageModel: Sendable`.
- Stores `Configuration` (API key, model alias, endpoint URL).
- Defines `LanguageModelCapabilities(supportsTools: false, supportsStructuredOutput: true)`.

### 2. `JevExecutor`
- Implements `LanguageModelExecutor: Sendable`.
- Bridges `respond(to:model:streamingInto:)` calls.
- Converts the prompt transcript to Jev's `state` string.
- Validates that a non-nil `GenerationSchema` is present; throws `JevError.structuredOutputRequired` otherwise.

### 3. `SchemaTranslator`
- Recursively walks `GenerationSchema.properties`.
- Maps property type semantics to Jev's three decision primitives:
  - `Bool` $\to$ `noul`
  - String / Enums $\to$ `choice`
  - Numerical ranges $\to$ `score`

### 4. `ResponseSynthesizer`
- Jev returns answers under a dictionary keyed by property name (`answers.department.choice`).
- `ResponseSynthesizer` transforms this dictionary into a valid JSON object matching the `@Generable` schema so Apple's internal decoder can instantiate the Swift struct directly.
- Concurrently extracts probability distributions, confidence scores, and `ScoreValue` models into the response metadata.

### 5. `URLSessionTransport` & `RetryPolicy`
- Native HTTP transport providing automated retries for transient status codes (HTTP 429, 529).
- Calculates exponential backoff with random jitter and parses RFC 9110 `Retry-After` headers (both integer seconds and HTTP dates).
- Guarantees cooperative task cancellation: `CancellationError` is never caught or wrapped, allowing interactive UI tasks to terminate immediately.

### 6. `RoutingPolicy` & Telemetry Extensions
- Maps continuous confidence scores and probabilities on `LanguageModelSession.Response` into discrete operational actions (`.auto`, `.confirm`, `.escalate`).
- Implements symmetrical noul gating with an explicit undecided band ($0.35\dots0.65$), safely escalating epistemic uncertainty without arbitrary coin-flips.

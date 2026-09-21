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
- Concurrently extracts probability distributions and confidence scores into the response metadata.

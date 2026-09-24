---
name: system-one-foundation-models
license: Apache-2.0
description: >-
  Evaluate System One decision models (Laya On-Device Core ML, Laya HTTP server, and TypeSafe Jev)
  natively through Apple's Foundation Models framework in Swift 6. Use when building iOS 27+, macOS 27+,
  or visionOS 27+ apps that evaluate strongly-typed @Generable structs and enums using LanguageModelSession,
  running models on-device via Core ML (Apple Neural Engine), connecting to self-hosted laya-serve,
  implementing confidence routing (RoutingPolicy, NoulJudgement, ScoreValue), configuring resilient network
  retries (RetryPolicy), or writing deterministic offline unit tests with MockSystemOneBackend.
metadata:
  author: peterfriese
  version: "2.0"
---

# System One Foundation Models Bridge

This skill guides the design, implementation, and testing of applications integrating **System One decision models** (**Laya On-Device Core ML**, **Laya HTTP Server**, and **TypeSafe Jev**) via **Apple's Foundation Models framework** (`FoundationModels`) in Swift 6.

---

## 1. Core Mental Model: Decisions, Not Chat

System One models are **non-autoregressive decision models**, not text-generating LLMs. They evaluate application state against a set of typed questions in a single forward pass, returning calibrated probabilities and discrete categorical decisions in 15–150ms.

- **Prompt $\to$ Application State**: The text passed to `session.respond(to:)` represents current application context (support tickets, sensor readings, transaction logs, user inputs, or parsed documents).
- **`@Generable` Type $\to$ Decision Questions**: The struct or enum defines the typed questions being asked over that state.
- **Dual Signal Output**:
  1. **The Answer**: *What* the model judged (`response.content` containing typed enum choices, booleans, or rubric scores).
  2. **The Calibrated Confidence / Probability**: *Whether* to automate the action (`response.judgement(...)`, `response.decision(...)`, `response.scoreValue(...)`).

---

## 2. Pluggable Backends

Developers choose between three primary execution backends by passing the appropriate model to `LanguageModelSession`:

### Option A: On-Device Core ML (`LayaOnDevice`)
Runs Laya's 322M (multilingual mmBERT) or 421M (ModernBERT) model directly on the **Apple Neural Engine (ANE)** and GPU. 100% offline, zero network requests, zero secrets:

```swift
import FoundationModels
import LayaOnDevice

let modelURL = Bundle.main.url(forResource: "LayaModernBERT", withExtension: "mlmodelc")!
let engine = try LayaCoreMLEngine(
    modelURL: modelURL,
    tokenizer: ModernBERTTokenizer.defaultTokenizer()
)

let model = LayaOnDeviceLanguageModel(engine: engine)
let session = LanguageModelSession(model: model)
```

### Option B: Self-Hosted or Remote Laya HTTP (`LayaFoundationModels`)
Connects to `laya-serve` (speaking the Jev-compatible `POST /v1/systemone` protocol):

```swift
import FoundationModels
import LayaFoundationModels

// Local server (localhost:8000 or localhost:8770) or hosted endpoint
let model = LayaLanguageModel(endpoint: .localDefault) // or .local(port: 8770) or .hosted
let session = LanguageModelSession(model: model)
```

### Option C: TypeSafe AI Jev Cloud (`JevFoundationModels`)
Connects to TypeSafe AI's hosted decision API with automated HTTP retry resilience and backoff:

```swift
import FoundationModels
import JevFoundationModels

let retryPolicy = RetryPolicy(maxAttempts: 3, initialDelay: .milliseconds(250), jitter: 0.15)
let model = JevLanguageModel(apiKey: apiKey, retryPolicy: retryPolicy)
let session = LanguageModelSession(model: model)
```

---

## 3. `@Generable` Schema Modeling Rules

`SchemaTranslator` maps Apple `@Generable` types directly to System One decision primitives. Follow these mapping rules strictly:

| Swift Type & Annotations | System One Primitive | Question Key Convention | Behavior / Output |
| :--- | :--- | :--- | :--- |
| `Bool` | **`noul`** | Field name (e.g. `"isUrgent"`) or `"root"` | Calibrated probability of truth ($0.0 \dots 1.0$). Decodes to Swift `Bool`. |
| `enum: String` | **`choice`** | Field name (e.g. `"department"`) or `"choice"` | Discrete categorical selection among defined enum cases. |
| `Int` or `Double` + `@Guide(.range(min...max))` | **`score`** | Field name (e.g. `"frustrationLevel"`) or `"root"` | Ordinal rubric scoring mapped to integer/numeric levels with continuous weighting. |
| `@Guide(description: "...")` | **`instructions`** | N/A | Natural language instructions steering judgment. |
| Nested `@Generable struct` | **`nested questions`** | Dot-notation (e.g. `"metadata.priority"`) | Evaluates hierarchical sub-properties concurrently. |

### Negative Constraints (Strictly Forbidden)
- ❌ **No unconstrained `String` properties**: Decision models do not generate free-form text. A `String` property without enum choices throws an invalid schema error.
- ❌ **No unstructured collections**: Arrays of open-ended values (`[String]`) or dictionaries are not supported.
- ❌ **No text generation requests without schemas**: Calling `session.respond(to: "Hello")` without a `generating:` argument throws a structured output required error.
- ❌ **No tool calling**: `LanguageModelCapabilities` for System One only includes `[.guidedGeneration]`.

### Correct Schema Example

```swift
import FoundationModels

@Generable
enum SupportDepartment: String, Sendable {
    case billing
    case technicalSupport
    case sales
}

@Generable
struct TriageDecision: Sendable {
    @Guide(description: "Is this customer inquiry urgent or blocking critical business?")
    var isUrgent: Bool

    @Guide(description: "Which department is best suited to resolve this issue?")
    var department: SupportDepartment

    @Guide(description: "Customer frustration rating on a 0 to 3 scale", .range(0...3))
    var frustrationLevel: Int
}
```

---

## 4. Confidence Routing with `RoutingPolicy`

Never write naive `if prob > 0.5` checks:
- **`0.50` indicates maximum epistemic uncertainty**, not "half true".
- The **undecided band** ($0.35 \dots 0.65$) indicates the model is genuinely undecided (`answer == nil`).
- A probability of `0.05` is a **confident "no"** ($\text{decisiveness} = \max(p, 1 - p) = 0.95$), which routes to `.auto` with `answer: false`.

Use `RoutingPolicy` to map calibrated signals into operational actions (`.auto`, `.confirm`, `.escalate`):

```swift
let policy = RoutingPolicy(
    escalateBelow: 0.60,
    autoAtOrAbove: 0.85,
    undecidedBand: 0.35...0.65
)

// Categorical or Scored Decision (.auto, .confirm, .escalate)
let deptAction = response.decision(for: "department", policy: policy)
switch deptAction {
case .auto:     routeToDepartment(decision.department)
case .confirm:  suggestDepartment(decision.department)
case .escalate: routeToGeneralQueue()
}

// Boolean (Noul) Judgement
let urgencyJudgement = response.judgement(for: "isUrgent", policy: policy)
switch urgencyJudgement.decision {
case .auto:
    if urgencyJudgement.answer == true {
        pageOnCallLead()       // Confident Yes (p >= 0.85)
    } else {
        markStandardPriority() // Confident No (p <= 0.15)
    }
case .confirm:  promptAgentToConfirm() // Leaning
case .escalate: assignManualReview()   // Undecided band (answer is nil)
}
```

---

## 5. Deterministic Offline Testing (`MockSystemOneBackend`)

Always test decision workflows deterministically without live network access or GPU model loading:

```swift
import Testing
import FoundationModels
import SystemOneCore

@Suite("Triage Decision Tests")
struct TriageWorkflowTests {

    @Test("Verifies triage routing and high-probability escalation")
    func testUrgentBillingTriage() async throws {
        let mockBackend = MockSystemOneBackend { request in
            #expect(request.questions.count == 3)
            #expect(request.state.contains("charged $500 twice"))

            return SystemOneResponse(
                model: "mock",
                answers: [
                    "isUrgent": SystemOneAnswer(type: "noul", noul: 0.97, confidence: 0.95),
                    "department": SystemOneAnswer(type: "choice", choice: "billing", confidence: 0.98),
                    "frustrationLevel": SystemOneAnswer(type: "score", score: 2.8, confidence: 0.90)
                ],
                usage: SystemOneUsage(inputTokens: 85, outputTokens: 0)
            )
        }

        let model = SystemOneLanguageModel(backend: mockBackend)
        let session = LanguageModelSession(model: model)

        let response = try await session.respond(
            to: "charged $500 twice",
            generating: TriageDecision.self
        )

        #expect(response.content.isUrgent == true)
        #expect(response.content.department == .billing)
        #expect(response.content.frustrationLevel == 3)
    }
}
```

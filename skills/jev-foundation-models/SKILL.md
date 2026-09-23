---
name: jev-foundation-models
license: Apache-2.0
description: >-
  Evaluate TypeSafe Jev System One decision models natively through Apple's Foundation
  Models framework in Swift 6. Use when building iOS 27+, macOS 27+, or visionOS 27+
  apps that evaluate strongly-typed @Generable structs and enums using LanguageModelSession,
  accessing calibrated decision probabilities, configuring JevTransport for App Check,
  or writing offline unit tests with MockJevTransport.
metadata:
  author: peterfriese
  version: "1.0"
---

# Jev Foundation Models Bridge

This skill guides the design, implementation, and testing of applications integrating **TypeSafe AI's Jev System One decision model** via **Apple's Foundation Models framework** (`FoundationModels`) in Swift 6.

---

## 1. Core Mental Model: Decisions, Not Chat

Jev is a **System One decision model**, not a text-generating LLM. It evaluates application state against a set of typed questions in a single forward pass, returning calibrated probabilities and discrete categorical decisions in 40–150ms.

- **Prompt $\to$ Application State**: The text passed to `session.respond(to:)` represents current application context (support tickets, sensor readings, transaction logs, user inputs, or parsed documents).
- **`@Generable` Type $\to$ Decision Questions**: The struct or enum defines the typed questions being asked over that state.
- **Output $\to$ Calibrated Decisions & Telemetry**: Strongly typed values delivered instantly (single-frame delivery), with exact probability distributions accessible via response metadata extensions.

---

## 2. `@Generable` Schema Modeling Rules

`SchemaTranslator` maps Apple `@Generable` types directly to Jev decision primitives. Follow these mapping rules strictly:

| Swift Type & Annotations | Jev Primitive | Behavior / Output |
| :--- | :--- | :--- |
| `Bool` | **`noul`** | Calibrated probability of truth (0.0 – 1.0). Decodes to Swift `true` / `false`. |
| `enum: String` | **`choice`** | Discrete categorical selection among defined enum cases. |
| `Int` or `Double` + `@Guide(.range(min...max))` | **`score`** | Ordinal rubric scoring mapped to integer/numeric levels. |
| `@Guide(description: "...")` | **`instructions`** | Natural language instructions steering Jev's judgment. |
| Nested `@Generable struct` | **`nested questions`** | Evaluates hierarchical sub-properties concurrently. |

### Negative Constraints (Strictly Forbidden)
- ❌ **No unconstrained `String` properties**: Jev does not generate free-form text. A `String` property without enum choices throws `JevError.invalidSchema`.
- ❌ **No unstructured collections**: Arrays of open-ended values (`[String]`) or dictionaries are not supported.
- ❌ **No text generation requests without schemas**: Calling `session.respond(to: "Hello")` without a `generating:` argument throws `JevError.structuredOutputRequired`.
- ❌ **No tool calling**: `LanguageModelCapabilities` for Jev only includes `[.guidedGeneration]`. It does not support `Tool` execution.

### Correct Schema Example

```swift
import FoundationModels

@Generable
enum SupportDepartment: String {
    case billing
    case technicalSupport
    case sales
}

@Generable
struct TriageDecision {
    @Guide(description: "Is this customer inquiry urgent or blocking critical business?")
    var isUrgent: Bool

    @Guide(description: "Which department is best suited to resolve this issue?")
    var department: SupportDepartment

    @Guide(description: "Customer frustration rating on a 0 to 3 scale", .range(0...3))
    var frustrationLevel: Int
}
```

---

## 3. Canonical Call-Site & Telemetry Access

Always use standard Apple Foundation Models APIs (`LanguageModelSession`)—do not introduce proprietary session wrappers:

```swift
import FoundationModels
import JevFoundationModels

// 1. Initialize the model provider
let model = JevLanguageModel(apiKey: apiKey)
let session = LanguageModelSession(model: model)

// 2. Evaluate state against the @Generable schema
let customerTicket = """
Ticket #8491: Urgent! I was charged $500 twice for renewal, and our accounts are locked!
"""

let response = try await session.respond(to: customerTicket, generating: TriageDecision.self)

// 3. Consume strongly typed decision content
let decision: TriageDecision = response.content
print("Department:", decision.department)       // .billing
print("Is Urgent:", decision.isUrgent)           // true
print("Frustration:", decision.frustrationLevel) // 3

// 4. Access calibrated probabilities & confidence (Package Extensions)
if let urgencyProb = response.probability(for: "isUrgent") {
    print("Urgency probability:", urgencyProb) // e.g. 0.96
    if urgencyProb > 0.90 {
        // High-confidence automatic triage
    }
}

if let deptConfidence = response.confidence(for: "department") {
    print("Department selection confidence:", deptConfidence) // 0.0 - 1.0
}
```

---

## 4. Production Mobile Architecture (`JevTransport`)

**Never embed `TYPESAFE_API_KEY` inside client application binaries.** 

In production iOS, macOS, or visionOS apps, route requests through a backend proxy (such as a Firebase Cloud Function, Vapor backend, or Cloudflare Worker) protected by **Apple App Attest / Firebase App Check**:

```swift
import JevFoundationModels

public struct AppCheckTransport: JevTransport, Sendable {
    public init() {}

    public func send(request: JevRequest, endpoint: URL, apiKey: String) async throws -> JevResponse {
        // 1. Fetch hardware-backed App Check token
        let token = try await AppCheck.appCheck().token(forcingRefresh: false)
        
        // 2. Route to your backend proxy endpoint
        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue(token.token, forHTTPHeaderField: "X-Firebase-AppCheck")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)

        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        // Check HTTP status and decode JevResponse...
        return try JSONDecoder().decode(JevResponse.self, from: data)
    }
}

// Configuration with custom transport:
let model = JevLanguageModel(
    apiKey: "", // Key is managed securely on your backend proxy
    endpoint: URL(string: "https://your-cloud-function.cloudfunctions.net/triageProxy")!,
    transport: AppCheckTransport()
)
```

---

## 5. Offline Testing with Swift Testing (`@Test`)

Always test decision workflows deterministically without requiring a live internet connection or API keys using `MockJevTransport`:

```swift
import Testing
import FoundationModels
@testable import JevFoundationModels

@Suite("Triage Decision Tests")
struct TriageWorkflowTests {

    @Test("Verifies triage routing and high-probability escalation")
    func testUrgentBillingTriage() async throws {
        let mockTransport = MockJevTransport { request in
            #expect(request.questions.count == 3)
            #expect(request.state.contains("charged $500 twice"))

            return JevResponse(
                model: "jev-mock",
                answers: [
                    "isUrgent": JevAnswer(type: "noul", noul: 0.97, confidence: 0.95),
                    "department": JevAnswer(type: "choice", choice: "billing", confidence: 0.98),
                    "frustrationLevel": JevAnswer(type: "score", score: 3.0)
                ],
                usage: JevUsage(inputTokens: 85, outputTokens: 10)
            )
        }

        let model = JevLanguageModel(apiKey: "mock-key", transport: mockTransport)
        let session = LanguageModelSession(model: model)

        let response = try await session.respond(
            to: "charged $500 twice",
            generating: TriageDecision.self
        )

        #expect(response.content.isUrgent == true)
        #expect(response.content.department == .billing)
        #expect(response.content.frustrationLevel == 3)
        #expect(response.probability(for: "isUrgent") == 0.97)
    }
}
```

---

## 6. Implementation Nuances & Troubleshooting

| Issue / Error | Cause | Resolution |
| :--- | :--- | :--- |
| `JevError.invalidSchema` | `@Generable` type contains an unconstrained `String` or unsupported collection. | Convert `String` to `enum: String`, `Bool`, or numeric `@Guide(.range(...))`. |
| `JevError.structuredOutputRequired` | `session.respond(to:)` was called without a `generating:` schema. | Always pass a `@Generable` type to `generating:`. |
| Root Enum Decoding (`Fatal error: Unexpected rawValue`) | Apple Foundation Models expects bare strings for root `@Generable enum`s (e.g. `billing`), not JSON quotes (`"\"billing\""`). | Handled automatically by `ResponseSynthesizer` (Tech Note 0002). |
| Probabilities Dictionary Empty | Question key does not match property name. | Use property names as keys: `response.probability(for: "propertyName")`. |

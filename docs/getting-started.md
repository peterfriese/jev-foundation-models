# Getting Started with Jev Foundation Models

This guide walks you through integrating Jev into your Apple platform application using the native Foundation Models framework.

---

## 1. Requirements

- Xcode 27+ / Swift 6.0+
- Deployment Targets: iOS 27.0+, macOS 27.0+, visionOS 27.0+
- A TypeSafe AI API Key ([console.typesafe.ai](https://console.typesafe.ai/keys))

> [!WARNING]
> **API Key Security in Mobile Apps**
> Never embed or hardcode your `TYPESAFE_API_KEY` into mobile application bundles (iOS, iPadOS, visionOS). Client application bundles can be easily inspected or decompiled. For mobile clients, forward requests through a secure server proxy that injects the key (see the [Mobile Security Guide](mobile-security.md) for a complete Apple App Attest / Firebase App Check implementation), or use this package directly in backend services, macOS tools, and server-side Swift.

---

## 2. Add Package Dependency

### In `Package.swift`
```swift
dependencies: [
    .package(url: "https://github.com/peterfriese/jev-foundation-models.git", from: "0.1.0")
]
```

### In Xcode
Go to **File > Add Package Dependencies...** and enter the repository URL.

---

## 3. Define Your Decision Schema

Use standard Foundation Models `@Generable` and `@Guide` annotations:

```swift
import FoundationModels

@Generable
struct TicketTriage {
    @Guide(description: "Is this ticket urgent or time-sensitive?")
    var isUrgent: Bool

    @Guide(description: "Which department should handle this request?")
    var department: Department

    @Guide(description: "Customer frustration level", .range(0...2))
    var frustration: Int
}

@Generable
enum Department {
    case billing
    case technical
    case sales
}
```

---

## 4. Evaluate with LanguageModelSession

```swift
import FoundationModels
import JevFoundationModels

// 1. Initialize the Jev model
let jev = JevLanguageModel(apiKey: ProcessInfo.processInfo.environment["TYPESAFE_API_KEY"]!)

// 2. Create standard Apple FoundationModels session
let session = LanguageModelSession(model: jev)

// 3. Prompt the session
let ticket = "I was charged twice for my subscription this morning and need this fixed immediately!"
let response = try await session.respond(to: ticket, generating: TicketTriage.self)

// 4. Consume typed decision
let triage = response.content
print("Urgent: \(triage.isUrgent)")             // true
print("Department: \(triage.department)")       // .billing
print("Frustration Score: \(triage.frustration)") // 2

// 5. Inspect calibrated probabilities and confidence
if let confidence = response.metadata["confidence"] {
    print("Confidence: \(confidence)")
}
```

---

## 5. Configuring Resilience (`RetryPolicy`)

For production workloads, configure network retries for transient gateway overload (HTTP 429 / 529):

```swift
let retryPolicy = RetryPolicy(
    maxAttempts: 3,
    initialDelay: .milliseconds(250),
    multiplier: 2.0,
    jitter: 0.15,
    retryableStatuses: [429, 529]
)

let jev = JevLanguageModel(apiKey: apiKey, retryPolicy: retryPolicy)
let session = LanguageModelSession(model: jev)
```

If the API returns HTTP 429 with `Retry-After: 5`, `URLSessionTransport` automatically sleeps for the requested delay and retries, without dropping the request or failing your application flow.

---

## 6. Routing Decisions on Calibrated Confidence

In System One models, the answer tells you *what* the model judged, but the calibrated confidence tells you **whether to act on it automatically**:

```swift
let policy = RoutingPolicy(escalateBelow: 0.60, autoAtOrAbove: 0.85)

// (a) Categorical routing:
switch response.decision(for: "department", policy: policy) {
case .auto:
    routeTicketDirectly(to: response.content.department)
case .confirm:
    suggestDepartmentToAgent(response.content.department)
case .escalate:
    assignToHumanSupervisor()
}

// (b) Boolean routing with undecided band (0.35...0.65):
let judgement = response.judgement(for: "isUrgent", policy: policy)
switch judgement.decision {
case .auto:
    if judgement.answer == true { dispatchP0Alert() }
case .confirm:
    flagForReview()
case .escalate:
    // Inside 0.35...0.65: model is genuinely undecided, judgement.answer is nil
    assignToHumanSupervisor()
}

// (c) Continuous rubric score inspection:
if let score = response.scoreValue(for: "frustration") {
    print("Weighted: \(score.value) | Discrete Level: \(score.rounded) | Normalized: \(score.normalized ?? 0)")
}
```

For more in-depth guidance, see:
* [Confidence & Noul Routing Guide](confidence-routing.md)
* [HTTP Resilience & Retries Guide](resilience-and-retries.md)

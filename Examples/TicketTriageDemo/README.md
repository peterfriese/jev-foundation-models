# Ticket Triage Demo 🎫⚡️

Demonstrates multi-primitive System One evaluation with Apple's **Foundation Models** framework, incorporating **HTTP resilience**, **RFC 9110 retry backoff**, and **operational confidence routing**.

---

## 🎯 What This Sample Does

1. **Defines `@Generable` Decision Schema**:
   Uses standard Apple Foundation Models macros (`@Generable`, `@Guide`) to specify:
   - `department`: Categorical choice (`.billing`, `.engineering`, `.sales`)
   - `isUrgent`: Boolean `noul` question
   - `frustrationLevel`: 3-level rubric `score` (`.range(0...2)`)
2. **Configures Network Resilience (`RetryPolicy`)**:
   Guards against transient API rate limits (HTTP 429) or gateway overloads (HTTP 529) using exponential backoff, random jitter, and RFC 9110 `Retry-After` parsing.
3. **Executes Confidence & Noul Routing (`RoutingPolicy`)**:
   Translates raw model probabilities and confidence scores into programmatic actions:
   - **Categorical routing**: Direct auto-routing ($\ge 85\%$), human agent suggestion ($60\dots84\%$), or supervisor escalation ($< 60\%$).
   - **Boolean routing with undecided band**: Recognizes when the model is genuinely undecided ($0.35\dots0.65$) and prevents arbitrary flipping around $0.5$.
   - **Rubric scoring**: Inspects probability-weighted scores, rounded discrete levels, and normalized scales ($0.0\dots1.0$).

---

## 🚀 Running the Demo

Ensure `TYPESAFE_API_KEY` is exported or placed in a local `.env` file:

```bash
export TYPESAFE_API_KEY="your-api-key"
swift run ticket-triage-demo
```

Or provide a custom ticket inquiry via arguments:

```bash
swift run ticket-triage-demo "We have a critical outage on our production database and users cannot sign in."
```

---

## 💡 How Key Features Work in Code

### 1. Resilient HTTP Transport Configuration

```swift
let retryPolicy = RetryPolicy(
    maxAttempts: 3,
    initialDelay: .milliseconds(250),
    multiplier: 2.0,
    jitter: 0.15,
    retryableStatuses: [429, 529]
)

let model = JevLanguageModel(apiKey: apiKey, retryPolicy: retryPolicy)
let session = LanguageModelSession(model: model)
```

If the TypeSafe AI gateway returns HTTP 429 with `Retry-After: 3`, `URLSessionTransport` automatically sleeps for the requested delay and retries, without dropping the user's ticket or failing the request.

### 2. Confidence Routing on Categorical Choices

```swift
let routingPolicy = RoutingPolicy(escalateBelow: 0.60, autoAtOrAbove: 0.85)

switch response.decision(for: "department", policy: routingPolicy) {
case .auto:
    // High confidence: Route ticket directly to department inbox
    assignTicket(to: response.content.department)
case .confirm:
    // Moderate confidence: Present as recommendation for human triage agent
    suggestDepartment(response.content.department)
case .escalate:
    // Low confidence or missing answer: Escalate to supervisor review
    routeToSupervisor()
}
```

### 3. Noul Gating & The Undecided Band ($0.35\dots0.65$)

For boolean properties like `isUrgent`, a simple `if response.content.isUrgent` can misinterpret maximum uncertainty ($p = 0.51$) as a confirmed positive. Using `judgement(for:)`:

```swift
let judgement = response.judgement(for: "isUrgent", policy: routingPolicy)

switch judgement.decision {
case .auto:
    if judgement.answer == true {
        pageOnCallEngineeringP0()
    } else {
        routeToStandardSLA()
    }
case .confirm:
    flagForPriorityVerification()
case .escalate:
    // Model probability fell within 0.35...0.65 (undecided): judgement.answer is nil
    flagForManualUrgencyTriage()
}
```

### 4. Continuous Rubric Inspection with `ScoreValue`

```swift
if let score = response.scoreValue(for: "frustrationLevel") {
    print("Continuous Weighted Value: \(score.value)")     // e.g. 1.72
    print("Discrete Level:            \(score.rounded)")   // 2 (Hostile)
    print("Normalized Scale (0...1):   \(score.normalized)")// 0.86
}
```

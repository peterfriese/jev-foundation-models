# Confidence & Noul Routing Guide

In TypeSafe AI's System One architecture, an evaluation returns two key signals:
1. **The Answer**: *What* the model judged (the discrete enum choice, boolean state, or rubric position).
2. **The Calibrated Probability / Confidence**: *How certain* the model is in its judgment.

The answer tells your application what to do; the confidence tells your application **whether to do it automatically**.

---

## 🧭 The Three Operational Decisions

A `RoutingPolicy` maps continuous confidence scores ($0.0 \dots 1.0$) into three actionable outcomes:

```swift
public enum Decision: String, Sendable, Hashable, Codable, CaseIterable {
    case auto      // High confidence: Execute programmatically without prompting
    case confirm   // Moderate confidence: Present as a suggestion, ask user/agent to confirm
    case escalate  // Low confidence / undecided: Route to human supervisor or fallback queue
}
```

### Threshold Defaults

By default:
- **`autoAtOrAbove: 0.85`**: Scores $\ge 0.85$ are executed automatically (`.auto`).
- **`escalateBelow: 0.60`**: Scores $< 0.60$ escalate to human review (`.escalate`).
- **Middle range ($0.60 \dots 0.84$)**: Requires user confirmation (`.confirm`).

> **Best Practice: Policy per Action**
> 
> Hold a policy per action rather than one globally: the confidence that is plenty for tagging an article or filing an expense under $10 is not enough to execute a wire transfer or dispatch emergency crews.

```swift
let readPolicy = RoutingPolicy(escalateBelow: 0.50, autoAtOrAbove: 0.75)
let writePolicy = RoutingPolicy(escalateBelow: 0.70, autoAtOrAbove: 0.95)
```

---

## ⚖️ Noul Gating: Handling the Undecided Band ($0.35\dots0.65$)

In generative LLMs, boolean outputs are binary tokens (`true` or `false`).
In Jev System One, boolean (`noul`) queries yield continuous probabilities ($0.0 \dots 1.0$).

### 1. 0.50 Means Maximum Uncertainty
A probability near $0.50$ communicates that the model is **genuinely undecided**—not that the statement is "half true". A hard cutoff at $\ge 0.50$ would turn $0.49$ vs. $0.51$ into a flipped boolean decision that the caller makes rather than one the model expressed.

### 2. Confident "No" is Fully Actionable
A probability of $0.05$ is a confident "no" ($95\%$ probability of false). In Jev:
$$\text{decisiveness} = \max(p, 1 - p)$$
A probability of $0.05$ has a decisiveness of $0.95$, which routes to `.auto` with `answer: false`. This allows safe programmatic adoption of negative decisions without false alarms.

### 3. The Undecided Band Curve

```
Probability (p):
0.00 ──────── 0.15 ──────── 0.35 ════════ 0.50 ════════ 0.65 ──────── 0.85 ──────── 1.00
[  .auto (No)  ] [  .confirm  ] [   UNDECIDED BAND (.escalate)   ] [  .confirm  ] [  .auto (Yes) ]
                                [   answer == nil                ]
```

### 4. Code Example

```swift
let policy = RoutingPolicy.default
let judgement = response.judgement(for: "isUrgent", policy: policy)

switch judgement.decision {
case .auto:
    if judgement.answer == true {
        pageOnCallEngineering() // Confident Yes (p ≥ 0.85)
    } else {
        routeToStandardQueue()  // Confident No (p ≤ 0.15)
    }
case .confirm:
    promptUserToVerifyUrgency() // Leaning (0.16...0.34 or 0.65...0.84)
case .escalate:
    // Inside 0.35...0.65 undecided band: judgement.answer is nil
    assignToManualTriageQueue()
}
```

---

## 📊 Rubric Scoring with `ScoreValue`

When querying `@Guide(.range(...))` score properties, Jev returns probability-weighted positions across rubric levels:

```swift
if let score = response.scoreValue(for: "frustrationLevel") {
    // 1. Continuous weighted value (e.g., 1.30 = level 1 leaning toward level 2)
    print("Weighted Score: \(score.value)")

    // 2. Nearest whole integer level
    print("Discrete Level: \(score.rounded)")

    // 3. Normalized score (0.0 ... 1.0 across total rubric levels)
    if let normalized = score.normalized {
        print("Normalized:     \(normalized)")
    }

    // 4. Probability distribution across levels
    for (level, prob) in score.probabilities.sorted(by: { $0.key < $1.key }) {
        print("  Level \(level): \(prob * 100)%")
    }
}
```

---

## 🛡️ Safe Escalation for Unanswered or Mismatched Questions

If an answer is missing from the response, or if the question type did not match the expected primitive:
- `response.decision(for: "unanswered")` returns `.escalate`.
- `response.judgement(for: "unanswered")` returns `NoulJudgement(answer: nil, decisiveness: 0.0, decision: .escalate)`.

The framework **never guesses or substitutes defaults** when evaluating confidence.

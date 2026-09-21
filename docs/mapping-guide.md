# Type Mapping Guide: @Generable to Jev Primitives

This document specifies the exact mapping between Apple Foundation Models `@Generable` types and TypeSafe AI System One primitives.

---

## Mapping Summary

| Swift / `@Generable` Type | Jev Primitive | Question Configuration | Response Extraction |
| :--- | :--- | :--- | :--- |
| **`Bool`** | `noul` | `"type": "noul"`, `instructions: <Guide description>` | Evaluated probability $> 0.5 \implies \text{true}$ |
| **`enum` (String / RawRepresentable)** | `choice` | `"type": "choice"`, `criteria: { caseName: caseDescription }` | Selected string key $\implies$ enum case |
| **`Int` / `Double` with `@Guide(.range(A...B))`** | `score` | `"type": "score"`, `criteria: [rubric0, rubric1, ...]` | Selected level $\implies$ integer/number value |

---

## 1. Boolean Propositions (`noul`)

A `noul` question asks whether a statement holds true given the state.

### Swift Code:
```swift
@Generable
struct Decision {
    @Guide(description: "Does the user intend to cancel their account?")
    var wantsCancellation: Bool
}
```

### Generated Jev Request:
```json
{
  "questions": {
    "wantsCancellation": {
      "type": "noul",
      "instructions": "Does the user intend to cancel their account?"
    }
  }
}
```

### Jev Response:
```json
{
  "answers": {
    "wantsCancellation": {
      "type": "noul",
      "noul": 0.94
    }
  }
}
```

### Synthesized Swift Output:
```json
{
  "wantsCancellation": true
}
```
*(Probability `0.94` is also recorded under `metadata["probabilities"]["wantsCancellation"]`)*

---

## 2. Categorical Enums (`choice`)

A `choice` question selects one option from a mutually exclusive list of criteria.

### Swift Code:
```swift
@Generable
enum RoutingTarget {
    @Guide(description: "Payments, invoices, or charges")
    case billing
    @Guide(description: "Bugs, crashes, or API errors")
    case engineering
    @Guide(description: "Enterprise inquiries or licensing")
    case sales
}

@Generable
struct Router {
    @Guide(description: "Where to dispatch this message")
    var target: RoutingTarget
}
```

### Generated Jev Request:
```json
{
  "questions": {
    "target": {
      "type": "choice",
      "instructions": "Where to dispatch this message",
      "criteria": {
        "billing": "Payments, invoices, or charges",
        "engineering": "Bugs, crashes, or API errors",
        "sales": "Enterprise inquiries or licensing"
      }
    }
  }
}
```

---

## 3. Scored Ranges (`score`)

A `score` evaluates state against an ordered rubric from low to high.

### Swift Code:
```swift
@Generable
struct Review {
    @Guide(description: "Customer hostility level", .range(0...2))
    var hostility: Int
}
```

### Generated Jev Request:
```json
{
  "questions": {
    "hostility": {
      "type": "score",
      "instructions": "Customer hostility level",
      "criteria": [
        "Calm or polite",
        "Annoyed or impatient",
        "Aggressive or hostile language"
      ]
    }
  }
}
```

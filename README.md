# Jev for Apple Foundation Models 🧠⚡️

[![Swift 6](https://img.shields.io/badge/Swift-6.0-orange.svg?style=flat&logo=swift)](https://developer.apple.com/swift/)
[![Xcode 27](https://img.shields.io/badge/Xcode-27.0+-blue.svg?style=flat&logo=xcode)](https://developer.apple.com/xcode/)
[![iOS 27.0+](https://img.shields.io/badge/iOS-27.0+-black.svg?style=flat&logo=apple)](https://developer.apple.com/ios/)
[![macOS 27.0+](https://img.shields.io/badge/macOS-27.0+-black.svg?style=flat&logo=apple)](https://developer.apple.com/macos/)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fpeterfriese%2Fjev-foundation-models%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/peterfriese/jev-foundation-models)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fpeterfriese%2Fjev-foundation-models%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/peterfriese/jev-foundation-models)
[![License: Apache-2.0](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)

A lightweight, native Swift 6 bridge integrating **TypeSafe AI's Jev** System One decision model into Apple's **Foundation Models** framework.

Evaluate strongly typed `@Generable` structs and enums against application state in **40–150ms** with zero hallucinations, calibrated probabilities, and full Apple Intelligence API compatibility.

> [!WARNING]
> **Security Advisory: Never Embed API Keys in Mobile Apps**
> TypeSafe AI API keys (`TYPESAFE_API_KEY`) must **never** be hardcoded or bundled inside client-side iOS, iPadOS, watchOS, or visionOS application binaries. Anyone can inspect or decompile mobile apps to extract embedded secrets.
>
> **Safe Deployment Patterns:**
> - **Backend / Server / CLI**: Use this library directly in server-side Swift services, macOS backend daemons, developer tools, or CLI applications where environment variables are kept server-side.
> - **Mobile Applications**: Route mobile requests through your own authenticated backend gateway or proxy service that securely manages the TypeSafe API key (see [Mobile Security Guide](docs/mobile-security.md) for a ready-to-use Firebase App Check & Apple App Attest architecture).

---

## 💡 Why Decision Models in Apple Foundation Models?

Traditional Large Language Models (LLMs) are generative text engines: coercing them into producing deterministic structured decisions requires constrained token sampling or prompt-and-parse pipelines.

**Jev** (by [TypeSafe AI](https://typesafe.ai)) is a **System One decision model**. Rather than generating prose word-by-word, Jev evaluates typed questions directly against state in a single feed-forward pass:

| Apple Foundation Models (`@Generable`) | Jev System One Primitive | Behavior |
| :--- | :--- | :--- |
| `Bool` | **`noul`** | Binary judgment with calibrated probability of truth |
| `enum` / String | **`choice`** | Categorical selection across discrete options |
| `@Guide(description: "...")` | **`instructions`** | Semantic criteria evaluated against state |
| `@Guide(.range(...))` | **`score`** | Bounded ordinal rubric scoring |
| `Response.metadata` | **`confidence` & `probabilities`** | Direct access to model uncertainty |

---

## 🚀 Quick Start

### 1. Add Package Dependency

Add `jev-foundation-models` to your `Package.swift` or via Xcode (**File > Add Package Dependencies...**):

```swift
dependencies: [
    .package(url: "https://github.com/peterfriese/jev-foundation-models.git", from: "0.1.0")
]
```

### 2. Define Your Decision Type

```swift
import FoundationModels

@Generable
struct CustomerTriage {
    @Guide(description: "Is this inquiry urgent or time-sensitive?")
    var isUrgent: Bool

    @Guide(description: "Which team should handle this request?")
    var department: Department

    @Guide(description: "Customer frustration score", .range(0...2))
    var frustration: Int
}

@Generable
enum Department {
    case billing
    case technical
    case account
}
```

### 3. Evaluate with `LanguageModelSession`

```swift
import FoundationModels
import JevFoundationModels

// 1. Create the model with optional resilience policy
let retryPolicy = RetryPolicy(maxAttempts: 3, initialDelay: .milliseconds(250), jitter: 0.15)
let jev = JevLanguageModel(apiKey: ProcessInfo.processInfo.environment["TYPESAFE_API_KEY"]!, retryPolicy: retryPolicy)

// 2. Initialize native Apple FoundationModels session
let session = LanguageModelSession(model: jev)

// 3. Evaluate state
let ticket = "My account was double charged this morning! Please fix this ASAP."
let response = try await session.respond(to: ticket, generating: CustomerTriage.self)

// 4. Access typed results
let triage = response.content
print("Urgent: \(triage.isUrgent)")             // true
print("Route: \(triage.department)")           // .billing
print("Frustration: \(triage.frustration)")    // 2

// 5. Route decisions with calibrated confidence
let policy = RoutingPolicy(escalateBelow: 0.60, autoAtOrAbove: 0.85)
switch response.decision(for: "department", policy: policy) {
case .auto:     print("Auto-routed to \(triage.department)")
case .confirm:  print("Suggesting \(triage.department) for confirmation")
case .escalate: print("Escalated to human supervisor")
}

let judgement = response.judgement(for: "isUrgent", policy: policy)
if judgement.decision == .auto && judgement.answer == true {
    print("Urgency: Decisive True -> Page on-call engineering P0")
}
```

---

## 🏗️ Architecture

`jev-foundation-models` conforms directly to Apple's public provider protocols:

```
┌────────────────────────────────────────────────────────────────────────┐
│                        LanguageModelSession                            │
│  session.respond(to: "...", generating: CustomerTriage.self)           │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │ passes Request (Transcript + Schema)
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│                             JevExecutor                                │
│  • SchemaTranslator: maps @Generable schema to Jev questions (noul/choice)
│  • JevClient: POST https://api.typesafe.ai/v1/systemone (40-150ms)     │
│  • ResponseSynthesizer: converts Jev answers into canonical JSON       │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │ yields via Channel
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│              LanguageModelExecutorGenerationChannel                    │
│  • .text(synthesizedJSON) -> decoded directly into CustomerTriage      │
│  • .updateMetadata(probabilities, confidence)                          │
└────────────────────────────────────────────────────────────────────────┘
```

For more in-depth documentation, see:
* [Confidence & Noul Routing Guide](docs/confidence-routing.md)
* [HTTP Resilience & Retries Guide](docs/resilience-and-retries.md)
* [Architecture Guide](docs/architecture.md)
* [Mobile Security Guide](docs/mobile-security.md)
* [Type Mapping Guide](docs/mapping-guide.md)
* [Tech Notes](tech-notes/README.md)

---

## 🛡️ Production Mobile Security: Apple App Attest & Firebase App Check

Because `TYPESAFE_API_KEY` cannot be embedded inside client-side iOS or visionOS apps, this repository provides a complete, production-ready reference architecture in [`Integrations/FirebaseAppCheckProxy`](Integrations/FirebaseAppCheckProxy):

```
┌─────────────────────────────────┐
│     Client App (iOS 27+)        │
│  • Apple App Attest / Enclave   │
│  • FirebaseAppCheckTransport    │
└────────────────┬────────────────┘
                 │ POST /systemone (Header: X-Firebase-AppCheck)
                 ▼
┌─────────────────────────────────┐
│  Cloud Function (2nd Gen Proxy) │
│  • Token Verification           │
│  • Replay Protection (Optional) │
│  • Injects TYPESAFE_API_KEY     │
└────────────────┬────────────────┘
                 │ POST https://api.typesafe.ai/v1/systemone
                 ▼
┌─────────────────────────────────┐
│        TypeSafe AI (Jev)        │
└─────────────────────────────────┘
```

- **Hardware-Attested Client Transport**: A drop-in Swift transport (`FirebaseAppCheckTransport.swift`) bridging the `FirebaseAppCheck` SDK to `JevTransport` with support for both:
  - `.cached` (default): In-memory token lookup with `< 1 ms` overhead, designed for interactive UI and continuous decision loops.
  - `.singleUse`: One-time consumable tokens with server-side replay protection for sensitive actions.
- **Serverless Reverse Proxy**: A ready-to-deploy Firebase Cloud Function (2nd Gen) that validates App Check tokens, guards against replayed requests, injects the API key from Google Secret Manager, and forwards evaluations with a 15-second timeout.
- **Keeps Core Library Pure**: Distributed as an unbundled recipe so `JevFoundationModels` retains its zero-dependency guarantee, avoiding pulling hundreds of megabytes of Firebase dependencies into projects that don't need them.

For complete setup and deployment instructions, see the **[Mobile Security Guide](docs/mobile-security.md)** and **[Integrations/FirebaseAppCheckProxy](Integrations/FirebaseAppCheckProxy/README.md)**.

---

## 🤖 Agent Skill

If you are using AI coding agents (Claude Code, OpenCode, Cursor, Windsurf, etc.), install the companion agent skill to equip your agent with the `@Generable` schema mapping rules, probability telemetry extensions, custom transport patterns, and offline test harnesses:

```bash
npx skills add peterfriese/jev-foundation-models
```

---

## 🧪 Testing

This package includes a full offline mock transport for deterministic testing without hitting live APIs:

```bash
swift test
```

---

## 📱 Sample Applications

### 1. Duplicate Article Detection ([`duplicate-article-demo`](Examples/DuplicateArticleDemo/README.md))

Demonstrates a two-layer deduplication system for read-it-later and knowledge-management apps:
- **Layer 1 (Deterministic)**: Catches identical URLs and matching title/byline pairs instantly at 0ms and zero token cost.
- **Layer 2 (Jev System One via Foundation Models)**: Evaluates rewritten wire stories and syndicated news (different URL, headline, byline) with calibrated probabilities.
- **Confidence & Noul Routing**: Symmetrical decisiveness gating with the undecided band ($0.35\dots0.65$) and cooperative cancellation.

```bash
# Run the 4-scenario deduplication & cancellation walkthrough
swift run duplicate-article-demo
```

### 2. Ticket Triage ([`ticket-triage-demo`](Examples/TicketTriageDemo/README.md))

Demonstrates multi-field `@Generable` evaluation with `Bool`, `enum`, and `@Guide(.range(...))` score:
- **Resilient HTTP Transport**: `RetryPolicy` with exponential backoff, jitter, and RFC 9110 `Retry-After` adherence.
- **Operational Confidence Routing**: Routes categorical choices (`.auto`, `.confirm`, `.escalate`), gates boolean urgency, and inspects rubric scores.

```bash
# Run with default sample ticket
swift run ticket-triage-demo

# Or evaluate custom text
swift run ticket-triage-demo "Our server deployment failed with error 500."
```

### 3. Smart Directory Organizer with Dynamic Profiles ([`file-organizer-demo`](Examples/FileOrganizerDemo/README.md))

Demonstrates Apple Foundation Models **Dynamic Profiles** (`LanguageModelSession.DynamicProfile`), runtime state adaptation with `@SessionPropertyEntry`, turn isolation via `.historyTransform`, and multi-primitive Jev System One triage:
- **Dynamic Profile Adaptation**: Switches between Semantic Domain and Actionable Workflow triaging by modifying session properties in-place without rebuilding the session.
- **Sensitive Content Quarantine**: Flags credentials, API keys, and secrets via `noul` and quarantines them into `Quarantine_Vault/`.
- **Review Queue for Low-Confidence Items**: Calibrated `score` routes uncertain content to `Review_Queue/` for human verification.
- **Turn Isolation**: Uses `.historyTransform` to prune prior file turns from the transcript, keeping batch evaluations stateless and token-efficient.

```bash
# Run the interactive sandbox walkthrough
swift run file-organizer-demo --demo

# Organize any directory with dry-run preview (or add --apply to execute moves)
swift run file-organizer-demo --path ~/Downloads --strategy domain
```

---

## 📄 License

This project is licensed under the Apache License, Version 2.0. See [LICENSE](LICENSE) for details.

# System One for Apple Foundation Models 🧠⚡️

[![Swift 6](https://img.shields.io/badge/Swift-6.0-orange.svg?style=flat&logo=swift)](https://developer.apple.com/swift/)
[![Xcode 27](https://img.shields.io/badge/Xcode-27.0+-blue.svg?style=flat&logo=xcode)](https://developer.apple.com/xcode/)
[![iOS 27.0+](https://img.shields.io/badge/iOS-27.0+-black.svg?style=flat&logo=apple)](https://developer.apple.com/ios/)
[![macOS 27.0+](https://img.shields.io/badge/macOS-27.0+-black.svg?style=flat&logo=apple)](https://developer.apple.com/macos/)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fpeterfriese%2Fjev-foundation-models%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/peterfriese/jev-foundation-models)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fpeterfriese%2Fjev-foundation-models%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/peterfriese/jev-foundation-models)
[![License: Apache-2.0](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)

A lightweight, native Swift 6 bridge integrating **System One decision models** into Apple's **Foundation Models** framework (`LanguageModel`, `LanguageModelExecutor`, `@Generable`).

Evaluate strongly typed `@Generable` structs and enums against application state in **15–150ms** with zero hallucinations, calibrated probabilities, and full Apple Intelligence API compatibility across:
- **On-Device Core ML (`LayaOnDevice`)**: Run Laya's 322M (multilingual mmBERT) and 421M (English/typed-decisions ModernBERT) parameter models locally on the Apple Neural Engine and GPU with zero network calls.
- **Self-Hosted HTTP (`LayaFoundationModels`)**: Connect to `laya-serve` (PR #31 merged into `NandhaKishorM/laya`) speaking the Jev-compatible `POST /v1/systemone` protocol with presets for `localhost:8000`, `localhost:8770`, and hosted `api.impossibl.com`.
- **TypeSafe AI Cloud (`JevFoundationModels`)**: Full backwards-compatible support for hosted TypeSafe Jev endpoints with automated HTTP retries (`RetryPolicy`), cooperative cancellation, and confidence routing (`RoutingPolicy`).

> [!WARNING]
> **Security Advisory: Never Embed API Keys in Mobile Apps**
> Cloud API keys (`TYPESAFE_API_KEY`) must **never** be hardcoded or bundled inside client-side iOS, iPadOS, watchOS, or visionOS application binaries. Anyone can inspect or decompile mobile apps to extract embedded secrets.
>
> **Safe Deployment Patterns:**
> - **On-Device Core ML (`LayaOnDevice`)**: Run models locally on hardware with 100% offline privacy and zero secrets required.
> - **Backend / Server / CLI**: Use `LayaLanguageModel` or `JevLanguageModel` directly in server-side Swift services or CLI tools where environment variables remain server-side.
> - **Mobile Applications with Cloud APIs**: Route mobile requests through your own authenticated reverse proxy protected by Apple App Attest and Firebase App Check (see [Mobile Security Guide](docs/mobile-security.md)).

---

## 💡 Why Decision Models in Apple Foundation Models?

Traditional Large Language Models (LLMs) are generative text engines: coercing them into producing deterministic structured decisions requires constrained token sampling or prompt-and-parse pipelines.

**System One decision models** evaluate typed questions directly against state in a single feed-forward pass:

| Apple Foundation Models (`@Generable`) | System One Decision Primitive | Behavior |
| :--- | :--- | :--- |
| `Bool` | **`noul`** | Binary judgment with calibrated probability of truth |
| `enum` / String | **`choice`** | Categorical selection across discrete options |
| `@Guide(description: "...")` | **`instructions`** | Semantic criteria evaluated against state |
| `@Guide(.range(...))` | **`score`** | Bounded ordinal rubric scoring |
| `Response.metadata` | **`confidence` & `probabilities`** | Direct access to model uncertainty |

---

## 🚀 Quick Start

### 1. Add Package Dependency

Add `SystemOneFoundationModels` to your `Package.swift` or via Xcode (**File > Add Package Dependencies...**):

```swift
dependencies: [
    .package(url: "https://github.com/peterfriese/jev-foundation-models.git", from: "0.2.0")
]
```

### 2. Choose Your Execution Backend

#### Option A: On-Device Core ML (Zero Network, Air-Gapped Privacy)
```swift
import FoundationModels
import LayaOnDevice

// 1. Initialize on-device engine with compiled Core ML model
let engine = try LayaCoreMLEngine(
    modelURL: Bundle.main.url(forResource: "LayaModernBERT", withExtension: "mlmodelc")!,
    tokenizer: ModernBERTTokenizer.defaultTokenizer()
)

// 2. Initialize native Apple Foundation Models session
let session = LanguageModelSession(model: LayaOnDeviceLanguageModel(engine: engine))
```

#### Option B: Self-Hosted or Remote Laya HTTP (`laya-serve`)
```swift
import FoundationModels
import LayaFoundationModels

// 1. Connect to local laya-serve (localhost:8000 or localhost:8770) or hosted endpoint
let model = LayaLanguageModel(endpoint: .localDefault) // or .local(port: 8770) or .hosted

// 2. Initialize native Apple Foundation Models session
let session = LanguageModelSession(model: model)
```

#### Option C: TypeSafe AI Jev Cloud with Resilience
```swift
import FoundationModels
import JevFoundationModels

// 1. Connect to TypeSafe AI API with automated retry resilience
let retryPolicy = RetryPolicy(maxAttempts: 3, initialDelay: .milliseconds(250), jitter: 0.15)
let jev = JevLanguageModel(apiKey: ProcessInfo.processInfo.environment["TYPESAFE_API_KEY"]!, retryPolicy: retryPolicy)

// 2. Initialize native Apple Foundation Models session
let session = LanguageModelSession(model: jev)
```

### 3. Define Your Decision Type & Evaluate

```swift
import FoundationModels

@Generable
struct CustomerTriage: Sendable {
    @Guide(description: "Is this inquiry urgent or time-sensitive?")
    var isUrgent: Bool

    @Guide(description: "Which team should handle this request?")
    var department: Department

    @Guide(description: "Customer frustration score", .range(0...2))
    var frustration: Int
}

@Generable
enum Department: String, Sendable {
    case billing
    case technical
    case account
}

// Evaluate state
let ticket = "My account was double charged this morning! Please fix this ASAP."
let response = try await session.respond(to: ticket, generating: CustomerTriage.self)

// Access typed results
let triage = response.content
print("Urgent: \(triage.isUrgent)")             // true
print("Route: \(triage.department)")           // .billing
print("Frustration: \(triage.frustration)")    // 2

// Confidence routing with RoutingPolicy
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

`SystemOneFoundationModels` conforms directly to Apple's public provider protocols (`LanguageModel`, `LanguageModelExecutor`):

```
┌────────────────────────────────────────────────────────────────────────┐
│                        LanguageModelSession                            │
│  session.respond(to: "...", generating: CustomerTriage.self)           │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │ passes Request (Transcript + Schema)
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│                        SystemOneExecutor                               │
│  • SchemaTranslator: maps @Generable schema to System One questions    │
│  • SystemOneBackend (Pluggable Execution Engine):                      │
│     ├── LayaOnDeviceBackend: Core ML on Apple Neural Engine / GPU      │
│     ├── LayaHTTPBackend: POST http://localhost:8000/v1/systemone       │
│     └── JevBackend: POST https://api.typesafe.ai/v1/systemone          │
│  • ResponseSynthesizer: converts answers into canonical JSON / enums   │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │ yields via Channel
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│              LanguageModelExecutorGenerationChannel                    │
│  • .appendText(synthesizedJSON) -> decoded into CustomerTriage         │
│  • .updateMetadata(probabilities, confidence, scores, duration)        │
│  • .updateUsage(inputTokens, outputTokens)                             │
└────────────────────────────────────────────────────────────────────────┘
```

For more in-depth documentation, see:
* [Architecture Decision Record (ADR)](docs/architecture/ADR-2026-09-25-mail-triage-system-one-engine.md)
* [Product Requirements Document (PRD)](docs/prd/PRD-2026-09-25-mail-triage-system-one-engine.md)
* [CLI & Server Deployment Guide](docs/laya-cli-guide.md)
* [Mobile Deployment & Core ML Guide](docs/laya-mobile-guide.md)
* [Confidence Routing Guide](docs/confidence-routing.md)
* [Resilience & Retries Guide](docs/resilience-and-retries.md)
* [Mobile Security Guide (App Check)](docs/mobile-security.md)
* [Type Mapping Guide](docs/mapping-guide.md)
* [Tech Notes Index](tech-notes/README.md)

---

## 📄 License

This project is licensed under the Apache License, Version 2.0. See [LICENSE](LICENSE) for details.

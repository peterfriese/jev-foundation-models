# Examples & Reference Applications 📱💻

This directory contains reference applications, production examples, and runnable command-line demos showcasing **System One decision models** integrated natively into Apple's **Foundation Models framework** (`LanguageModelSession`, `@Generable`, `@Guide`).

---

## 🧭 Demos & Reference Implementations Comparison

| Demo / Application | Format | Target / Backend | API Key Required? | Primary Concepts Demonstrated |
| :--- | :--- | :--- | :---: | :--- |
| [**MailTriageApp**](MailTriageApp/README.md) | Full macOS & iOS SwiftUI App | Pluggable (Core ML, Local/Remote Laya, Jev Cloud, Mock) | Optional (Keychain managed) | Flagship 3-pane email triage, 5 selectable backends, FactoryKit DI, Liquid Glass UI, urgency priority tokens, batch triage with cancellation. |
| [**LayaDemo**](LayaDemo/README.md) | CLI Executable | `LayaFoundationModels` (`POST /v1/systemone`) | ❌ No API key | 100% free local evaluation against `laya-serve` on `localhost:8000` or custom endpoint. Zero cloud accounts required. |
| [**TicketTriageDemo**](TicketTriageDemo/README.md) | CLI Executable | `JevFoundationModels` | ✅ Yes (`TYPESAFE_API_KEY`) | Customer support ticket routing, RFC 9110 HTTP retry resilience (`RetryPolicy`), multi-primitive `@Generable` schema, confidence routing. |
| [**FileOrganizerDemo**](FileOrganizerDemo/README.md) | CLI Executable | `JevFoundationModels` | Optional (`--demo` offline mode) | Foundation Models **Dynamic Profiles**, runtime session adaptation (`@SessionPropertyEntry`), turn isolation (`.historyTransform`), sensitive file quarantine. |
| [**DuplicateArticleDemo**](DuplicateArticleDemo/README.md) | CLI Executable | `JevFoundationModels` | Optional (Built-in offline mode) | Two-layer content deduplication (exact fast-path + semantic decision), calibrated Noul undecided band ($0.35\dots0.65$), cooperative Swift 6 task cancellation. |

---

## 🏃 Running Each Example

### 1. MailTriageApp (Flagship Native macOS & iOS App)

A complete native application with multi-window support, Liquid Glass visual hierarchy, and 5 hot-swappable backends:

```bash
# Option A: Open directly in Xcode GUI
open Examples/MailTriageApp/apps/apple/MailTriageApp.xcodeproj

# Option B: Build & test via FlowDeck CLI
cd Examples/MailTriageApp
flowdeck build -w apps/apple/MailTriageApp.xcodeproj -s MailTriageApp
flowdeck test -w apps/apple/MailTriageApp.xcodeproj -s MailTriageApp

# Option C: Build from repository root using just
just mail-build
just mail-test
```

For complete documentation, see [Examples/MailTriageApp/README.md](MailTriageApp/README.md).

---

### 2. LayaDemo (Zero-Key Local Evaluation)

Evaluates customer inquiries against a local or remote `laya-serve` instance:

```bash
# 1. Start laya-serve in background or separate terminal
laya-serve
# (or via Docker: docker run -p 8000:8000 ghcr.io/nandhakishorm/laya:latest)

# 2. Run the demo against default sample inquiry
swift run laya-demo

# 3. Evaluate custom inquiry text from CLI
swift run laya-demo "The app crashes immediately upon opening account settings on iOS 27."

# 4. Point to custom or hosted endpoint
LAYA_ENDPOINT="http://127.0.0.1:8770/v1/systemone" swift run laya-demo "Cancel my subscription"
```

For complete documentation, see [Examples/LayaDemo/README.md](LayaDemo/README.md).

---

### 3. TicketTriageDemo (Network Resilience & Confidence Routing)

Demonstrates production network resilience and calibrated confidence routing against TypeSafe AI:

```bash
# 1. Export your API key
export TYPESAFE_API_KEY="your-api-key"

# 2. Run default billing ticket evaluation
swift run ticket-triage-demo

# 3. Evaluate custom ticket inquiry
swift run ticket-triage-demo "Production database latency spiked to 45 seconds, all checkouts failing."
```

For complete documentation, see [Examples/TicketTriageDemo/README.md](TicketTriageDemo/README.md).

---

### 4. FileOrganizerDemo (Dynamic Profiles & Session Properties)

Classifies and organizes files into semantic directories using Apple Foundation Models dynamic profiles:

```bash
# 1. Run simulated sandbox walkthrough (no API key required)
swift run file-organizer-demo --demo

# 2. Preview organization of an actual folder in dry-run mode
swift run file-organizer-demo --path ~/Downloads --strategy domain

# 3. Apply changes to disk using live TypeSafe AI API
export TYPESAFE_API_KEY="your-api-key"
swift run file-organizer-demo --path ~/Downloads --strategy workflow --apply
```

For complete documentation, see [Examples/FileOrganizerDemo/README.md](FileOrganizerDemo/README.md).

---

### 5. DuplicateArticleDemo (Two-Layer Deduplication & Cancellation)

Demonstrates two-layer content deduplication (deterministic exact-matching layer followed by semantic System One evaluation) and cooperative cancellation:

```bash
# 1. Run simulated walkthrough (no API key required)
swift run duplicate-article-demo

# 2. Run with live TypeSafe AI API evaluation
export TYPESAFE_API_KEY="your-api-key"
swift run duplicate-article-demo
```

For complete documentation, see [Examples/DuplicateArticleDemo/README.md](DuplicateArticleDemo/README.md).

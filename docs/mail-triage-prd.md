# Product Requirements Document (PRD): MailTriage App 📬⚡️

- **Status**: Draft / Ready for Implementation
- **Target Branch**: `feature/mail-triage-redesign`
- **Frameworks**: `FoundationModels` (Apple Foundation Models, Swift 6), `SwiftUI`, `CoreML`
- **Platforms**: macOS 27.0+, iOS 27.0+

---

## 1. Executive Summary & Pedagogical Purpose

`MailTriage` is a flagship reference application designed to teach developers how to integrate **System One decision models** (Laya and TypeSafe Jev) natively into **Apple's Foundation Models framework** (`LanguageModel`, `LanguageModelSession`, `@Generable`).

### 🎓 Critical Architectural Mandate: Pedagogical Clarity
The code that interfaces with the model is the **primary instructional asset** of this repository. It must be:
1. **Crystal Clear & Easy to Understand**: A developer reading the source must immediately grasp how to use Apple's `LanguageModelSession` with strongly typed `@Generable` schemas.
2. **Minimal Indirection & Zero Boilerplate**: Avoid hiding the Foundation Models API behind complex wrapper protocols or convoluted abstraction layers. The literal call-site must shine:
   ```swift
   let session = LanguageModelSession(model: selectedModel)
   let response = try await session.respond(to: emailText, generating: EmailTriageDecision.self)
   ```
3. **Dual Signal Education**: Clearly demonstrate the two distinct outputs of a decision model:
   - **The Answer**: What the model decided (`response.content.category`, `response.content.requiresAction`).
   - **The Calibrated Confidence**: Whether the system should automate the action (`response.decision(...)`, `response.judgement(...)`).

---

## 2. High-Level Functional Requirements

### A. The 5 Connection Architectures
The application must demonstrate and allow comparing all ways of calling decision models through Apple Foundation Models:

1. **Embedding (On-Device Core ML)**:
   - Powered by `LayaOnDeviceLanguageModel` and `LayaCoreMLEngine`.
   - Runs directly on the **Apple Neural Engine (ANE)** and GPU.
   - 100% offline, zero network requests, zero secrets, absolute data privacy.
2. **Hosting Locally (`laya-serve`)**:
   - Powered by `LayaFoundationModels` (`LayaLanguageModel(endpoint: .localDefault)`).
   - Connects to a self-hosted `laya-serve` instance on `127.0.0.1:8000` with zero API keys.
3. **Remotely Hosted (Private VPC)**:
   - Powered by `LayaFoundationModels` (`LayaLanguageModel(endpoint: .hosted)`).
   - Connects to enterprise clusters (e.g. `api.impossibl.com`) with optional Bearer token auth.
4. **Cloud API (TypeSafe Jev Cloud)**:
   - Powered by `JevFoundationModels` (`JevLanguageModel(apiKey: ..., retryPolicy: ...)`).
   - Demonstrates automated network resilience (exponential backoff, jitter, RFC 9110 `Retry-After`).
5. **Generative Baseline (Apple Intelligence On-Device LLM)**:
   - Powered by Apple's default `LanguageModelSession()`.
   - Evaluates the exact same `@Generable` schema using Apple's on-device ~3B generative model to highlight the latency, token economics, and throughput differences between autoregressive LLMs and single-pass decision models.

---

### B. Decision Modeling (`@Generable` Schema)
The schema must model real-world triage decisions across all three System One primitives:
- **`requiresAction: Bool`**: Mapped to `noul` (calibrated probability of truth in $0.0\dots1.0$).
- **`category: EmailCategory`**: Mapped to `choice` (discrete categorical classification across security alerts, billing/finance, work/tasks, meetings, newsletters, and spam/phishing).
- **`urgencyScore: Int`**: Mapped to `score` with `@Guide(.range(0...3))` (rubric rating from P0 critical to P3 low).
- **`suggestedAction: TriageAction`**: Mapped to `choice` (actionable workflows: immediate alert, quarantine threat, schedule task, draft reply, auto-archive, or move to inbox).

---

### C. Operational Confidence Routing (`RoutingPolicy`)
The application must demonstrate policy-based decision gating rather than naive binary checks:
- **`.auto` ($\ge 85\%$)**: High confidence allows autonomous execution (e.g. automatically quarantining phishing or archiving newsletters).
- **`.confirm` ($60\%\dots84.9\%$)**: Moderate confidence presents a 1-click suggested action.
- **`.escalate` ($< 60\%$ or inside $0.35\dots0.65$ undecided band)**: Epistemic uncertainty routes safely to the human inbox without guessing.

---

### D. Realistic Enterprise Inbox Dataset (500+ Emails)
The inbox must reflect a realistic developer/Googler mail stream:
- CI/CD build breaks (Sponge, Bazel, GitHub Actions) and infrastructure alerts (PagerDuty P0).
- Code reviews (Critique, Gerrit, GitHub PRs with Principal/Staff engineers).
- Apple purchases, subscriptions, and Developer Program / TestFlight notices.
- Colleague 1:1 syncs, sprint planning, and on-call swap requests.
- Cloud invoices (Google Cloud Platform TPU v5e statements, Stripe, SaaS tools).
- Security notices (mandatory training, Okta MFA, confidential wire transfer phishing).
- Newsletters and technical digests (Swift Weekly, ByteByteGo, ArXiv).
- Dynamic count tracking (e.g. `504 messages, 181 unread`).

---

## 3. User Experience & Design Guidelines

### A. Apple Mail Familiarity
- **Multi-Pane Structure**: Classic three-pane layout (Navigation sidebar, Message list, Message reader).
- **Sidebar Navigation**:
  - Top window traffic lights cleanly aligned.
  - Sidebar toggle button permanently visible in the top-left toolbar regardless of collapsed state.
  - Clean System One mailboxes: Favorites (Inbox, VIPs, Flagged, Drafts, Sent) and Decision Categories (Security Alerts, Billing, Work, Meetings, Newsletters, Quarantined, Archive).
  - Calm status footer (no infinite spinning indicators when idle).
- **Message List**:
  - Dynamic count header (`Inbox — 504 messages, 181 unread`).
  - Search field and unread-only filter toggle.
  - Apple Mail 3-line rows (blue unread dot, bold sender, timestamp, subject, body preview snippet, and subtle status pill).
- **Message Reader**:
  - Full email body, contact avatar monogram, headers, and formatted date.
  - Centered *"No Message Selected"* empty state when unselected.

### B. Tasteful Liquid Glass Design & Toolbar Triage Ergonomics
- Strictly follow Apple's Liquid Glass guidelines (`swiftui-liquid-glass`) and native Apple Mail design patterns:
  - **Toolbar Backend Selector**: Compact, elegant Liquid Glass grouped capsule (`GlassEffectContainer`) centered in the toolbar that does not crowd out standard mail action buttons.
  - **Primary Toolbar Triage**: Single-email triage is triggered directly from the primary navigation toolbar (via the dedicated sparkles "Triage Message" button in the toolbar). Batch triage is triggered via the toolbar "Triage All" button in the message list.
  - **Triage Outcome Header Banner**: Triage outcome metadata (category pill, urgency score badge, suggested action, and confidence) is cleanly presented in the email header banner of `MailDetailView` and in the message list rows, preserving standard Apple Mail reading ergonomics without obstructing content or requiring a floating bottom action drawer.
  - **Zero Glass Inside Lists**: List and scroll view rows use high-performance system materials to guarantee 120Hz ProMotion scrolling.

### C. Fluid Animations & Motion
- **Row Transitions**: Rows smoothly glide in from the top on addition, and glide out horizontally to the trailing edge on deletion, archiving, or quarantine.
- **State Changes**: All model mutations wrapped in fluid spring physics (`.spring(response: 0.32, dampingFraction: 0.82)`).

### D. Batch Triage Summary Dialog
- Clicking **"Triage All"** categorizes the entire inbox concurrently.
- Upon completion, a dedicated Liquid Glass modal sheet surfaces:
  - Total messages triaged and total batch elapsed time.
  - Throughput (messages/sec) and average latency per message.
  - Breakdown grid of automated actions taken (Alerts, Quarantines, Work tasks, Meetings, Archives, Escalations).

---

## 4. Xcode & Tooling Integration
- **Project Format**: Native Xcode 27.2 JSON project file (`MailTriage.xcodeproj/project.xcproj`).
- **Location**: `Examples/MailTriageApp/MailTriage.xcodeproj`.
- **Target & Scheme**: Configured with shared scheme `MailTriage.xcscheme` targeting `MailTriage.app` as the primary runnable.
- **Native Process Identity**: Sets `NSApplication.shared.setActivationPolicy(.regular)`, process name `MailTriage`, and high-resolution Mail Dock icon.
- **CLI & FlowDeck Compatibility**: Fully compatible with FlowDeck, SPM (`swift test`, `swift run`), and Xcode build/run (Cmd+R).

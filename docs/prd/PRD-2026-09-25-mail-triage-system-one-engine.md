# PRD: System One Decision Model Engine & Live Triage Experience in MailTriage

- **Document ID**: `PRD-2026-09-25-mail-triage-system-one-engine`
- **Date**: 2026-09-25
- **Status**: Draft / Ready for Architectural Review
- **Owner**: Product Manager Agent
- **Architect**: Senior Architect Agent
- **Target Branch**: `feature/mail-triage-system-one-engine`
- **Target Release**: MailTriage 1.1.0 (iOS 27.0+, macOS 27.0+)
- **Upstream / Specs**: Apple Foundation Models Framework, TypeSafe AI Jev, Laya On-Device Core ML

---

## 1. Problem Statement & Pedagogical Context

Modern mobile applications are inundated with unstructured input—emails, notifications, customer messages, logs—that require instantaneous, accurate, and high-volume classification and routing. 

Today, developers face three compounding dilemmas when attempting to automate email triage:
1. **Generative LLM Overkill & Latency**: Sending high-volume transactional tasks (e.g. classifying incoming emails, detecting urgent P0 outages, quarantining phishing attacks) to autoregressive ~3B–70B parameter Large Language Models (LLMs) incurs massive latency (>800ms–2000ms per item), unpredictable token expenses, and generative hallucination risks.
2. **Lack of Calibrated Confidence**: Generative chat models output unstructured text and cannot provide mathematically grounded, calibrated Bayesian confidence scores. Systems are forced to guess or parse arbitrary percentages from markdown, making safe automation impossible.
3. **Architectural Lock-In & Deployment Rigidity**: Developers often struggle to evaluate tradeoffs between on-device inference (offline, zero-cost, private), self-hosted containers (VPC, data sovereignty), managed cloud APIs, and system-provided generative models.

### The Pedagogical Purpose of MailTriage
`MailTriage` is the flagship reference application for the **System One Foundation Models** bridge. It teaches engineers how to utilize Apple's native **Foundation Models** framework (`LanguageModel`, `LanguageModelSession`, `@Generable`, `@Guide`) alongside **System One decision models** (TypeSafe Jev and Laya). 

The primary instructional mandate is **call-site clarity with zero framework boilerplate**:
```swift
let session = LanguageModelSession(model: selectedModel)
let response = try await session.respond(to: emailText, generating: EmailTriageDecision.self)

// Dual Signal Evaluation:
let decision = response.content                  // The Answer (requiresAction, category, urgency, action)
let routing = routingPolicy.decide(decision)     // The Calibrated Confidence (.auto, .confirm, .escalate)
```

This PRD formalizes the end-to-end user requirements, schema definitions, operational confidence routing policies, multi-backend selector architecture, and interactive macOS/iOS user experiences for live email triage.

---

## 2. User Personas & User Stories

### User Personas
1. **Alex (iOS / Apple Platform Architect)**: Wants to see idiomatic Swift 6 and modern SwiftUI implementations using standard Apple Foundation Models APIs without proprietary vendor wrappers. Needs clear benchmarks comparing on-device Core ML decision models against Apple Intelligence LLMs.
2. **Taylor (Enterprise Security & Systems Engineer)**: Demands zero-data-leakage triage for confidential enterprise email. Requires 100% offline on-device processing via the Apple Neural Engine (ANE) or dedicated private VPC connectivity with strict routing policies.
3. **Jordan (Power User / Executive Inbox Zero Specialist)**: Receives 500+ messages per day across build failures, security alerts, calendar requests, and invoices. Needs 1-click or automated triage with transparent confidence indicators so they never miss critical P0 issues.

### User Stories

- **US-1 (Decision Model Schema & Extraction)**:
  - **As an** Apple developer,
  - **I want to** define an `EmailTriageDecision` struct using standard `@Generable` and `@Guide` macros,
  - **So that** I can leverage native Foundation Models code generation to extract structured triage categories, urgency scores, and recommended actions in a single model pass.

- **US-2 (Multi-Backend Switching & Benchmarking)**:
  - **As an** evaluator of System One technology,
  - **I want to** switch seamlessly between 5 distinct backend architectures (On-Device Core ML, Local `laya-serve`, Hosted VPC, Cloud API, and Apple Intelligence LLM) directly from the application toolbar,
  - **So that** I can observe and benchmark their runtime latency, privacy boundaries, and behavior differences on identical data.

- **US-3 (Calibrated Confidence Routing & Guardrails)**:
  - **As an** enterprise mail user,
  - **I want** the system to automatically quarantine phishing threats or archive spam only when calibrated confidence is $\ge 85\%$, while presenting suggested actions for confirmation at $60\%\dots84.9\%$, and escalating undecided decisions to my inbox,
  - **So that** I can benefit from automated triage without fear of silent false positives or erroneous deletions.

- **US-4 (Single-Email Interactive Triage UI & Toolbar Actions)**:
  - **As an** end user reading an email,
  - **I want to** trigger triage directly from the primary navigation toolbar via a dedicated sparkles button and view the triage outcome metadata (category pill, urgency score badge, suggested action, and confidence) presented cleanly in the email header banner and message list rows,
  - **So that** I can review, verify, or execute the recommended triage action effortlessly while preserving standard Apple Mail reading ergonomics without obstructing content.

- **US-5 (Batch "Triage All" & Performance Analytics)**:
  - **As a** developer benchmarking model performance,
  - **I want to** execute a concurrent "Triage All" batch run across my entire 500+ message inbox and inspect an analytical performance summary sheet,
  - **So that** I can visually prove the ~50x speedup (<15ms vs >800ms) and zero token economics of System One decision models over generative LLMs.

---

## 3. Functional Requirements

### FR-1: Strongly-Typed Decision Schema (`@Generable`)
1. The system shall provide a native `@Generable` schema struct `EmailTriageDecision` conforming to `Sendable`, `Hashable`, `Codable`:
   - `requiresAction: Bool`: Translates to a System One `noul` question with a calibrated Bayesian probability of truth ($0.0\dots1.0$).
   - `category: EmailCategory`: Translates to a System One `choice` question mapping to 6 discrete categorical buckets (`securityAlerts`, `billing`, `work`, `meetings`, `newsletters`, `quarantine`).
   - `urgencyScore: Int`: Annotated with `@Guide(.range(0...3))` and translating to a System One `score` question (rubric rating from P0 Critical to P3 Low).
   - `suggestedAction: TriageAction`: Translates to a System One `choice` question mapping to 6 actionable workflows:
     - `immediateAlert`: Trigger push/desktop alert and mark urgent.
     - `quarantineThreat`: Isolate suspicious/phishing emails to Quarantine mailbox.
     - `scheduleTask`: Convert into a work task / calendar follow-up.
     - `draftReply`: Prepare a context-aware response draft.
     - `autoArchive`: Archive low-priority read/notification items.
     - `moveToInbox`: Safe routing to normal Inbox view.
2. The schema definitions shall reside in `AppCore` and conform strictly to Apple's `FoundationModels` module standards.

### FR-2: Five-Backend Connection Architecture
The engine shall support dynamic selection and runtime execution across five distinct backend configurations:
1. **Backend 1: Embedding (On-Device Core ML)**:
   - Powered by `LayaOnDeviceLanguageModel` and `LayaCoreMLEngine`.
   - Executes directly on the Apple Neural Engine (ANE) and GPU via Core ML (`.mlmodelc` / `.mlpackage`).
   - 100% offline, zero network requests, zero API keys or credentials, absolute privacy.
2. **Backend 2: Local Hosting (`laya-serve`)**:
   - Powered by `LayaFoundationModels` (`LayaLanguageModel(endpoint: .localDefault)`).
   - Connects over HTTP to a local `laya-serve` daemon running on `http://127.0.0.1:8000/v1` with zero authentication required.
3. **Backend 3: Remote VPC (Self-Hosted Private Cloud)**:
   - Powered by `LayaFoundationModels` (`LayaLanguageModel(endpoint: .hosted)`).
   - Connects to an enterprise Laya deployment (e.g. `https://api.impossibl.com/v1`) with optional Bearer token authentication and App Check proxying.
4. **Backend 4: Cloud API (TypeSafe Jev Cloud)**:
   - Powered by `JevFoundationModels` (`JevLanguageModel(apiKey: ..., retryPolicy: ...)`).
   - Integrates `RetryPolicy` supporting jittered exponential backoff and RFC 9110 `Retry-After` header parsing.
5. **Backend 5: Generative Baseline (Apple Intelligence On-Device LLM)**:
   - Powered by standard Apple `LanguageModelSession()` with default system parameters.
   - Evaluates the identical `EmailTriageDecision` schema via Apple's native ~3B on-device autoregressive LLM to serve as the baseline comparison for latency, token economics, and resource utilization.

### FR-3: Calibrated Confidence Routing & Automated Policy Gating
1. The engine shall integrate `RoutingPolicy` from `SystemOneCore` with configurable thresholds:
   - **Autonomous Execution (`Decision.auto`)**: Calibration confidence $\ge 0.85$ (or `noul` decisiveness $\ge 0.85$ outside the undecided band). Allows direct automated mailbox mutation (e.g., auto-archiving newsletters, moving verified threats to quarantine).
   - **Interactive Confirmation (`Decision.confirm`)**: Calibration confidence between $0.60$ and $0.849$. Surfaced to the user in the UI as a 1-click suggested action.
   - **Safe Escalation (`Decision.escalate`)**: Calibration confidence $< 0.60$ or boolean probability inside the undecided epistemic band ($0.35\dots0.65$). The system leaves the message in the inbox and tags it for human review without automated state change.
2. For boolean `requiresAction` (`noul`), routing decisiveness must be calculated as $\max(p, 1 - p)$, honoring high-confidence negative decisions ($p \le 0.15 \implies \text{decisiveness} \ge 0.85 \implies \text{.auto}$ with `requiresAction = false`).

### FR-4: Interactive User Experience (Toolbar Triage Actions & Header Banner)
1. **Unified Toolbar Backend Selector & Primary Triage Actions**:
   - A compact, polished capsule picker (`Picker("Backend", selection: $selectedBackend)`) embedded directly in the macOS / iOS unified navigation toolbar.
   - Visually indicates the active backend with distinctive icons (e.g., `cpu.fill` for On-Device Core ML, `network` for `laya-serve`, `cloud.fill` for Jev Cloud, `apple.intelligence` for Apple LLM).
   - Dynamically reconfigures the active `LanguageModelSession` without requiring an application restart.
   - **Single-Email Toolbar Trigger**: Single-email triage is triggered directly from the primary navigation toolbar in `MailDetailView` via a dedicated sparkles "Triage Message" button (`Image(systemName: "sparkles")`), displaying a compact progress indicator during model inference.
   - **Batch Triage Toolbar Trigger**: Batch triage of all inbox messages is triggered via the dedicated toolbar "Triage All" sparkles button in `MailListView`, showing live processing count progress during execution.
2. **Triage Outcome Header Banner & Message Rows**:
   - Eliminates floating bottom action drawers anchored via `.safeAreaInset(edge: .bottom)` to preserve standard Apple Mail reading ergonomics without obstructing content.
   - Triage outcome metadata is cleanly presented directly in the email header banner of `MailDetailView` (positioned between sender metadata and the message body) and in the message list rows:
     - Triage Category pill with dedicated SF Symbol icon (e.g., Security Alerts, Billing, Work, Meetings, Newsletters, Quarantined).
     - Urgency Score badge (P0 Critical in red, P1 High in orange, P2 Medium in blue, P3 Low in gray).
     - Calibrated Confidence pill and routing status (`AUTO`, `CONFIRM`, `ESCALATE`).
     - Suggested Action display (e.g., sparkles indicator with "Suggested: [Action]") and contextual execution controls (e.g., "Move to Inbox" or mailbox routing buttons).

### FR-5: Concurrent Batch "Triage All" Engine & Performance Summary Modal
1. **Concurrent Inbox Processing**:
   - The user can trigger "Triage All" from the toolbar or mailbox header.
   - The engine processes untriaged emails concurrently using a task group with bounded parallelism (concurrency limit = 8) to avoid memory or GPU exhaustion.
   - Progress is reflected in real-time in the mailbox header (e.g., `Triaging 142/504...`).
2. **Performance Summary Modal Sheet**:
   - Upon batch completion, the app displays a modern Liquid Glass modal sheet containing:
     - **Hero Metrics**: Total messages triaged, total elapsed time, aggregate throughput (messages/sec), and average latency per message (ms).
     - **Action Breakdown Grid**: Counts and percentages of emails categorized into Immediate Alerts, Quarantined Threats, Tasks, Meetings, Archives, and Escalated Human Reviews.
     - **Engine Benchmark Comparison**: Side-by-side comparison table contrasting System One Decision Models (<15ms per message, 0 tokens) against the Generative LLM Baseline (>800ms per message, ~500 tokens/msg), highlighting speedup factor (~53x) and estimated API cost savings.
     - **Export / Dismiss Actions**: Button to close the modal or copy benchmark metrics to clipboard.

---

## 4. Acceptance Criteria

### AC-1: Generable Schema Conformance & Mapping (Given / When / Then)
- **Scenario 1.1**: Synthesizing Schema Translation
  - **Given** an instance of `EmailTriageDecision` with `requiresAction: true`, `category: .quarantine`, `urgencyScore: 0`, and `suggestedAction: .quarantineThreat`,
  - **When** `SchemaTranslator` evaluates the type against `SystemOneCore`,
  - **Then** the translated schema shall define exactly one `noul` question for `requiresAction`, one `score` question bounded to $[0, 3]$ for `urgencyScore`, and two `choice` questions for `category` and `suggestedAction`.
- **Scenario 1.2**: Bounded Decision Validation
  - **Given** an invalid urgency score outside $0\dots3$,
  - **When** the schema decoder parses the response,
  - **Then** it shall throw a `FoundationModels` decoding error and fail safely to human escalation.

### AC-2: Backend Switching & Offline Execution
- **Scenario 2.1**: Zero-Network On-Device Core ML Execution
  - **Given** the user selects the "On-Device Core ML" backend in the toolbar capsule selector,
  - **When** the device is completely offline (Airplane mode / network disabled) and a message is triaged,
  - **Then** the evaluation completes successfully via `LayaOnDeviceLanguageModel`, returning an `EmailTriageDecision` with inference latency under 20ms and zero network requests emitted.
- **Scenario 2.2**: Seamless Backend Switching
  - **Given** an open email in `MailDetailView`,
  - **When** the user changes the backend selector from "On-Device Core ML" to "Local laya-serve",
  - **Then** subsequent triage requests route to `http://127.0.0.1:8000/v1` without recreating the view hierarchy or losing selection state.

### AC-3: Confidence Routing Policy Adherence
- **Scenario 3.1**: High-Confidence Auto-Quarantine
  - **Given** an email evaluated as `suggestedAction: .quarantineThreat` with a calibrated choice confidence of $0.92$,
  - **When** `RoutingPolicy.default.decide(confidence: 0.92)` is applied,
  - **Then** the decision resolves to `.auto`, the email's mailbox is automatically transitioned to `.quarantine`, and the UI reflects "Quarantined automatically".
- **Scenario 3.2**: Mid-Confidence Interactive Confirmation
  - **Given** an email evaluated as `suggestedAction: .autoArchive` with confidence $0.74$,
  - **When** `RoutingPolicy.default.decide(confidence: 0.74)` is applied,
  - **Then** the decision resolves to `.confirm`, the email remains in `.inbox`, and the email header banner presents the suggested action for confirmation.
- **Scenario 3.3**: Undecided / Ambiguous Email Escalation
  - **Given** an email with boolean `requiresAction` probability of $0.52$ (within the $0.35\dots0.65$ undecided band),
  - **When** `RoutingPolicy.default.decide(probability)` is evaluated,
  - **Then** `NoulJudgement.decision` returns `.escalate`, the email remains in `.inbox`, and the UI displays an amber "Human Review Required" tag.

### AC-4: Toolbar Action Execution & Triage Header Banner
- **Scenario 4.1**: Primary Toolbar Triage Execution & Unobstructed Reading
  - **Given** an untriaged email open in `MailDetailView`,
  - **When** the user taps the dedicated sparkles "Triage Message" button in the primary navigation toolbar,
  - **Then** single-email triage executes with the active backend, showing an inline progress spinner, and populates the triage header banner without obscuring message body content or requiring a floating bottom drawer.
- **Scenario 4.2**: Triage Outcome Metadata in Header Banner
  - **Given** an email triaged with a suggested action (e.g. `scheduleTask` or mailbox relocation),
  - **When** the outcome metadata is rendered,
  - **Then** the triage outcome metadata (category pill, urgency score badge, suggested action, and confidence) is cleanly presented in the email header banner of `MailDetailView` and in the message list rows, preserving standard Apple Mail reading ergonomics, with contextual action execution (e.g., "Move to Inbox") updating state immediately with smooth spring physics (`.spring(response: 0.32, dampingFraction: 0.82)`).
- **Scenario 4.3**: Message List Batch Toolbar Action
  - **Given** untriaged emails in the inbox list (`MailListView`),
  - **When** the user taps the toolbar "Triage All" button in the message list,
  - **Then** batch triage processes concurrently, updating row metadata (category pills, urgency badges) and displaying live progress in the toolbar.

### AC-5: Batch "Triage All" & Analytical Summary Modal
- **Scenario 5.1**: Concurrency & Progress
  - **Given** 500 untriaged emails in the inbox dataset,
  - **When** the user clicks "Triage All",
  - **Then** the application processes messages concurrently with bounded parallelism ($\le 8$), updating the header progress indicator smoothly without freezing the main thread.
- **Scenario 5.2**: Modal Analytical Breakdown
  - **Given** the batch triage operation finishes for 500 emails,
  - **When** the batch completes,
  - **Then** the Performance Summary Modal presents:
    1. Total count = 500,
    2. Elapsed time in seconds (e.g. $<10$s on Core ML),
    3. Throughput $> 50$ emails/sec,
    4. Categorized action grid summing to 500,
    5. Baseline comparison displaying $>50\times$ speedup over the Apple Intelligence LLM baseline.

---

## 5. Non-Functional Requirements

### Performance & Latency
- **Inference Speed**:
  - On-Device Core ML (`LayaCoreMLEngine` on ANE/GPU): $\le 15$ ms per message average inference latency.
  - Local `laya-serve` (HTTP loopback): $\le 25$ ms per message average latency.
  - Remote Cloud (Jev Cloud / VPC): $\le 250$ ms (network roundtrip dependent).
  - Apple Intelligence On-Device Generative Baseline: $\ge 800$ ms per message.
- **Rendering & ProMotion**:
  - The UI must maintain 120Hz / 60Hz smooth scrolling throughout message navigation.
  - List and scroll rows must use lightweight system backgrounds without heavy blur stacks or runtime glass effects inside `List` cells to prevent GPU overdraw.
- **Memory Footprint**:
  - The on-device Core ML model package shall occupy $< 200$ MB of storage/RAM.
  - Batch execution over 500+ messages must not leak memory or exceed a 350 MB resident memory footprint.

### Concurrency & Architecture (Swift 6 & Stratos)
- **Strict Concurrency**:
  - Compiled with `-strict-concurrency=complete` in Swift 6. Zero concurrency warnings or data races.
  - All shared models (`Email`, `EmailTriageDecision`, `Mailbox`, `RoutingPolicy`) must conform naturally to `Sendable`.
  - All UI state stores (`MailStore`) must be isolated to `@MainActor` using the `@Observable` macro (no deprecated `ObservableObject`).
- **Dependency Injection**:
  - FactoryKit registration in `Container+AppCore.swift` for all language model providers, stores, and triage engines.
  - Full support for mock providers (`MockSystemOneBackend`, `MockJevTransport`) enabling 100% offline unit tests without external network or API keys.

### Security & Data Privacy
- **Zero Data Ingress/Egress on On-Device Core ML**: When using Backend 1, zero byte transmissions must occur over the network.
- **Credential Storage**: API keys for Jev Cloud or Bearer tokens for hosted Laya VPC must be stored securely in the system Keychain or resolved via environment variables; never hardcoded in repository source.
- **Network Resilience**: HTTP backends must honor standard HTTP 429 / 503 response headers (`Retry-After`) with randomized jitter backoff.

### Accessibility & Platform Polish
- **VoiceOver & Assistive Tech**: All interactive elements (backend capsule buttons, triage execution buttons, category pills) must include descriptive accessibility labels and traits.
- **Dynamic Type**: All font sizes in the Triage Header Banner, Toolbar controls, and Summary Modal must scale with system Dynamic Type.
- **Liquid Glass Integration**: Adhere to Apple's Liquid Glass ergonomics (`GlassEffectContainer`) on toolbar controls and modal sheets while preserving high contrast text readability and native Apple Mail layout cleanliness.

---

## 6. Edge Cases & Error Handling

1. **Model Offline / Daemon Unreachable**:
   - If the user selects "Local laya-serve" but `127.0.0.1:8000` is not running, the system must fail gracefully with a specific, friendly error banner (`"Cannot connect to laya-serve at 127.0.0.1:8000. Is the daemon running?"`) and offer a 1-click fallback to "On-Device Core ML".
2. **Network Timeouts & Flaky Connectivity**:
   - For Jev Cloud and Remote VPC backends, network failures must trigger up to 3 automatic retries with exponential backoff before surfacing a retry button.
3. **Truncated or Malformed Email Content**:
   - Emails with empty bodies, missing subject lines, or >100KB payload bodies must be cleanly sanitized and truncated (first 2,000 characters) before sending to the model tokenizer to prevent buffer overflow or token limit exceptions.
4. **Epistemic Indecision (Boundary Scores)**:
   - When the model returns a score exactly on the decision boundary or a noul probability between $0.48\dots0.52$, the system must strictly route to `.escalate` and mark the decision as "Ambiguous - User Review Recommended".
5. **Batch Cancellation**:
   - If the user switches mailboxes or dismisses the batch modal during "Triage All", the background `TaskGroup` must handle cooperative cancellation immediately (`Task.isCancelled`), preserving any already-triaged email states.

---

## 7. Out of Scope

1. **Full IMAP/MAPI/SMTP Sync Engine**:
   - Connecting to live third-party email accounts (e.g., Gmail OAuth, Exchange, Fastmail) is out of scope. The app operates on the realistic 500+ enterprise developer seed dataset (`InboxData.swift`).
2. **Generative Draft Reply Composition**:
   - While `suggestedAction: .draftReply` will flag the email for reply, full multi-paragraph generative email synthesis via chat completion is out of scope for this decision model release.
3. **On-Device Core ML Model Fine-Tuning**:
   - Training or fine-tuning weights directly on the iOS/macOS device is out of scope; the app bundles pre-compiled, temperature-calibrated Core ML artifacts.
4. **Multi-Account User Profiles**:
   - Multi-tenant mailbox management and multi-account switching are deferred to future milestones.

---

## 8. Handoff & Next Steps

This PRD is submitted for Phase 2 of the Full Spec-Driven Pipeline.
- **Assigned Architect**: Senior Architect Agent (`@senior-architect`)
- **Next Deliverable**: Architectural Decision Record (`ADR-2026-09-25-mail-triage-system-one-engine.md`) detailing data structures, Factory registrations, Core ML engine invocation, and SwiftUI view hierarchy.
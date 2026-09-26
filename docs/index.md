# System One for Apple Foundation Models Documentation 📚🧠

Welcome to the comprehensive documentation for **System One for Apple Foundation Models**, the Swift 6 library that bridges Apple's native Foundation Models framework (`LanguageModelSession`, `@Generable`, `@Guide`) with **System One decision models**—supporting on-device Core ML on Apple Neural Engine (**Laya**), local/remote self-hosted servers (**`laya-serve`**), and hosted cloud endpoints (**TypeSafe Jev**).

---

## 🧭 Guides & Specifications

* [**Getting Started**](getting-started.md): "Choose Your Path" onboarding, target selection guide, installation, and running your first query across Core ML, Laya HTTP, and Jev Cloud.
* [**CLI & Server Deployment Guide**](laya-cli-guide.md): Developing CLI developer tools with `laya-serve` and bundling standalone Core ML binaries.
* [**Mobile & On-Device Deployment Guide**](laya-mobile-guide.md): On-Device Core ML on Apple Neural Engine, SwiftUI Canvas preview mocking, and Xcode On-Demand Resources (ODR).
* [**Confidence & Noul Routing**](confidence-routing.md): Operational decision gating (`.auto`, `.confirm`, `.escalate`), epistemic uncertainty in the undecided band ($0.35\dots0.65$), and rubric scoring.
* [**HTTP Resilience & Retries**](resilience-and-retries.md): Configurable `RetryPolicy`, exponential backoff with jitter, RFC 9110 `Retry-After`, and cooperative Swift Concurrency cancellation.
* [**Mobile Security Guide**](mobile-security.md): Deploying securely to iOS/visionOS using Firebase App Check, Apple App Attest, and Cloud Function proxies.
* [**Architecture Decision Record (ADR)**](architecture/ADR-2026-09-25-mail-triage-system-one-engine.md): Architectural decisions, multi-backend System One execution, and confidence routing.
* [**Product Requirements Document (PRD)**](prd/PRD-2026-09-25-mail-triage-system-one-engine.md): Product requirements and UX specifications for the MailTriage reference application.
* [**Type Mapping Guide**](mapping-guide.md): Comprehensive reference mapping `@Generable` Swift types (`Bool`, `enum`, ranges) to System One primitives (`noul`, `choice`, `score`).
* [**Contributing Guide**](../CONTRIBUTING.md): Setup, offline testing protocol, coding standards, and Tech Note curation for contributors.

---

## 📱 Sample Applications & Reference Demos

* [**Examples Catalog (`Examples/README.md`)**](../Examples/README.md): Comprehensive comparison and run instructions for all 5 reference applications and CLI tools.
* [**MailTriageApp (`Examples/MailTriageApp/`)**](../Examples/MailTriageApp/README.md): **Flagship Reference App** for macOS and iOS. Features 3-pane split view, 5 selectable execution backends (Core ML, Local Laya, Remote Laya, Jev Cloud, Mock), urgency priority tokens, batch triage with cancellation, and pre-seeded reference truth benchmarks.
* [**Local Laya Demo (`Examples/LayaDemo/`)**](../Examples/LayaDemo/README.md): Zero-key CLI tool connecting to local or remote `laya-serve` instances via `POST /v1/systemone`.
* [**Ticket Triage Demo (`Examples/TicketTriageDemo/`)**](../Examples/TicketTriageDemo/README.md): Customer inquiry routing with `RetryPolicy` resilience, multi-primitive `@Generable` schema, and confidence-gated operations.
* [**Duplicate Article Detection (`Examples/DuplicateArticleDemo/`)**](../Examples/DuplicateArticleDemo/README.md): Two-layer deduplication engine using deterministic checks, System One semantic evaluation, and cooperative cancellation.
* [**Directory Organizer (`Examples/FileOrganizerDemo/`)**](../Examples/FileOrganizerDemo/README.md): Declarative Dynamic Profiles (`LanguageModelSession.DynamicProfile`), reactive state adaptation with `@SessionPropertyEntry`, and turn isolation.

---

## 🔧 Tools & Integrations

* [**Core ML Converter (`Tools/CoreMLConverter/`)**](../Tools/CoreMLConverter/README.md): Python scripts using `coremltools` to convert Hugging Face Laya checkpoints (`ModernBERT` 421M and `mmBERT` 322M) into Apple Neural Engine-optimized `.mlpackage` bundles.
* [**Firebase App Check Proxy (`Integrations/FirebaseAppCheckProxy/`)**](../Integrations/FirebaseAppCheckProxy/README.md): Reference zero-trust mobile proxy architecture using Firebase App Check and Apple App Attest to protect cloud endpoints from unauthorized API access.

---

## 🛠️ Field Notes & Trajectory

* [**Tech Notes (`tech-notes/`)**](../tech-notes/README.md): Curated technical findings, Foundation Models SDK quirks, and runtime observations.
* [**Engineering Journal (`docs/journal/`)**](journal/OVERVIEW.md): Chronological daily engineering trajectory, decisions, and remediation milestones.

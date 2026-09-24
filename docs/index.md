# Jev Foundation Models Documentation

Welcome to the documentation for **Jev Foundation Models**, the Swift 6 library that bridges Apple's Foundation Models framework with TypeSafe AI's Jev System One decision models.

---

## 📚 Guides & Specifications

* [**Getting Started**](getting-started.md): Installation, setting up your TypeSafe API key, and running your first decision query with `LanguageModelSession`.
* [**CLI & Server Deployment Guide**](laya-cli-guide.md): Developing CLI developer tools with `laya-serve` and bundling standalone Core ML binaries.
* [**Mobile & On-Device Deployment Guide**](laya-mobile-guide.md): On-Device Core ML on Apple Neural Engine, SwiftUI Canvas preview mocking, and Xcode On-Demand Resources (ODR).
* [**Confidence & Noul Routing**](confidence-routing.md): Operational decision gating (`.auto`, `.confirm`, `.escalate`), epistemic uncertainty in the undecided band ($0.35\dots0.65$), and rubric scoring.
* [**HTTP Resilience & Retries**](resilience-and-retries.md): Configurable `RetryPolicy`, exponential backoff with jitter, RFC 9110 `Retry-After`, and cooperative Swift Concurrency cancellation.
* [**Mobile Security Guide**](mobile-security.md): Deploying securely to iOS/visionOS using Firebase App Check, Apple App Attest, and Cloud Function proxies.
* [**Architecture & Execution Flow**](architecture.md): Deep-dive into how `LanguageModelSession`, `JevExecutor`, and `LanguageModelExecutorGenerationChannel` interact.
* [**Type Mapping Guide**](mapping-guide.md): Comprehensive reference mapping `@Generable` Swift types (`Bool`, `enum`, ranges) to Jev primitives (`noul`, `choice`, `score`).

---

## 📱 Sample Applications

* [**Ticket Triage Demo (`ticket-triage-demo`)**](../Examples/TicketTriageDemo/README.md): Customer inquiry routing with `RetryPolicy` resilience, multi-primitive `@Generable` schema, and confidence-gated operations.
* [**Duplicate Article Detection (`duplicate-article-demo`)**](../Examples/DuplicateArticleDemo/README.md): Two-layer deduplication engine using deterministic checks, Jev Foundation Models semantic evaluation, and cooperative cancellation.
* [**Directory Organizer (`file-organizer-demo`)**](../Examples/FileOrganizerDemo/README.md): Declarative Dynamic Profiles (`LanguageModelSession.DynamicProfile`), reactive state adaptation with `@SessionPropertyEntry`, and turn isolation.

---

## 🛠️ Field Notes

* [**Tech Notes (`tech-notes/`)**](../tech-notes/README.md): Documented technical findings, SDK quirks, and runtime observations.

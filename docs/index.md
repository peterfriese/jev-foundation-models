# Jev Foundation Models Documentation

Welcome to the documentation for **Jev Foundation Models**, the Swift 6 library that bridges Apple's Foundation Models framework with TypeSafe AI's Jev System One decision models.

---

## 📚 Guides & Specifications

* [**Getting Started**](getting-started.md): Installation, setting up your TypeSafe API key, and running your first decision query with `LanguageModelSession`.
* [**Mobile Security Guide**](mobile-security.md): Deploying securely to iOS/visionOS using Firebase App Check, Apple App Attest, and Cloud Function proxies.
* [**Architecture & Execution Flow**](architecture.md): Deep-dive into how `LanguageModelSession`, `JevExecutor`, and `LanguageModelExecutorGenerationChannel` interact.
* [**Type Mapping Guide**](mapping-guide.md): Comprehensive reference mapping `@Generable` Swift types (`Bool`, `enum`, ranges) to Jev primitives (`noul`, `choice`, `score`).
* [**Mobile Application Blueprints**](example-app-ideas.md): Production-ready mobile application blueprints demonstrating Jev's sub-100ms decision capabilities across iOS, watchOS, and visionOS.

---

## 🛠️ Field Notes

* [**Tech Notes (`tech-notes/`)**](../tech-notes/README.md): Documented technical findings, SDK quirks, and runtime observations.

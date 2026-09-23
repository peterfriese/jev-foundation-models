# Tech Notes

> Implementation findings, SDK quirks, and platform observations captured while developing the Jev Foundation Models bridge.

| # | Title | What it covers |
|---|-------|----------------|
| [0001](0001-afm-decision-model-bridging.md) | Bridging Decision Models into Apple Foundation Models via Channel Synthesis | How non-streaming decision models interface with `LanguageModelExecutorGenerationChannel`, single-frame JSON delivery, and injecting probability distributions into `LanguageModelSession.Response` metadata. |
| [0002](0002-foundationmodels-generation-quirks.md) | Apple Foundation Models Generation Nuances & Single-Frame Stream Delimiters | SDK nuances in `LanguageModelCapabilities`, `appendText` streaming action, and root `@Generable enum` bare-string decoding expectations. |
| [0003](0003-foundationmodels-dynamic-profiles.md) | Declarative Dynamic Profiles & Session Adaptation in Apple Foundation Models | SDK architecture of `LanguageModelSession.DynamicProfile`, `DynamicProfileBuilder` single-active-profile constraint, `@SessionPropertyEntry` reactive state, and turn isolation via `.historyTransform`. |
| [0004](0004-secure-mobile-transport-appcheck.md) | Secure Mobile Transport with Firebase App Check & Apple App Attest | Production mobile architecture securing TypeSafe API keys via Apple Secure Enclave hardware attestation, Firebase Cloud Function proxy, and `JevTransport`. |
| [0005](0005-spm-dependency-isolation-and-vendor-transports.md) | SPM Dependency Isolation & Decoupling Vendor Transports | Why vendor-specific transports remain decoupled reference implementations rather than core dependencies, analyzing SPM target sandboxing and dependency tree cascades. |
| [0006](0006-http-resilience-and-confidence-routing.md) | HTTP Resilience, RFC 9110 Backoff & Calibrated Decision Routing in System One Foundation Models Bridge | Cooperative cancellation preservation, Duration saturation safety, RFC 9110 Retry-After parsing, epistemic uncertainty in the undecided band (0.35...0.65), and metadata telemetry. |

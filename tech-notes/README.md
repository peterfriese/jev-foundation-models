# Tech Notes

> Implementation findings, SDK quirks, and platform observations captured while developing the Jev Foundation Models bridge.

| # | Title | What it covers |
|---|-------|----------------|
| [0001](0001-afm-decision-model-bridging.md) | Bridging Decision Models into Apple Foundation Models via Channel Synthesis | How non-streaming decision models interface with `LanguageModelExecutorGenerationChannel`, single-frame JSON delivery, and injecting probability distributions into `LanguageModelSession.Response` metadata. |
| [0002](0002-foundationmodels-generation-quirks.md) | Apple Foundation Models Generation Nuances & Single-Frame Stream Delimiters | SDK nuances in `LanguageModelCapabilities`, `appendText` streaming action, and root `@Generable enum` bare-string decoding expectations. |

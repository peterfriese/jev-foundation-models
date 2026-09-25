# MailTriageApp

`MailTriageApp` is a flagship reference application demonstrating native integration of **System One decision models** (Laya and TypeSafe Jev) into Apple's **Foundation Models framework** (`LanguageModel`, `LanguageModelSession`, `@Generable`) on macOS 27+ and iOS 27+.

## Project Structure

```text
apps/
└── apple/
    ├── MailTriageApp.xcodeproj    # Main Xcode project
    ├── MailTriageApp/             # App entrypoint and views
    └── Packages/
        ├── AppCore/               # Domain models, DI, triage engines
        └── AppUI/                 # Declarative SwiftUI views
```

## Building & Testing

Using [FlowDeck](https://flowdeck.dev):

```bash
# Build app
flowdeck build -w apps/apple/MailTriageApp.xcodeproj -s MailTriageApp

# Test app
flowdeck test -w apps/apple/MailTriageApp.xcodeproj -s MailTriageApp

# Test AppCore package
flowdeck test --package-path apps/apple/Packages/AppCore
```

Or using `just` from repository root:

```bash
just mail-build
just mail-test
just mail-test-core
```

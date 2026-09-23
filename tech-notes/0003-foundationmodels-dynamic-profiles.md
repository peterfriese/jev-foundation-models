# 0003 — Declarative Dynamic Profiles & Session Adaptation in Apple Foundation Models

- **Date**: 2026-09-23
- **Author**: Peter Friese
- **Framework**: `FoundationModels` (iOS 27.0+, macOS 27.0+)
- **Upstream**: TypeSafe AI Jev (System One)

---

## Context

In macOS 27 and iOS 27, Apple's `FoundationModels` framework introduced declarative profiles via `LanguageModelSession.DynamicProfile`. Similar to SwiftUI's `View` hierarchy, dynamic profiles allow developers to define model instructions, execution parameters, and event modifiers declaratively.

When integrating TypeSafe AI's Jev System One decision models into directory parsing, batch triage, or multi-mode agents, dynamic profiles provide runtime adaptability without tearing down and reallocating `LanguageModelSession` instances.

---

## Findings

### 1. The Single Active Profile Rule in `DynamicProfileBuilder`

Unlike SwiftUI's `ViewBuilder` (which produces `TupleView`) or `DynamicInstructionsBuilder` (which produces `TupleDynamicInstructions`), `DynamicProfileBuilder` enforces that a profile's body must evaluate to **exactly one active profile**:

```swift
@_functionBuilder public struct DynamicProfileBuilder {
    // Allowed: single content
    public static func buildBlock<T>(_ content: T) -> T where T: DynamicProfile

    // Allowed: conditional branches
    public static func buildEither<TrueContent, FalseContent>(first: TrueContent) -> ConditionalDynamicProfile<TrueContent, FalseContent>
    public static func buildEither<TrueContent, FalseContent>(second: FalseContent) -> ConditionalDynamicProfile<TrueContent, FalseContent>

    // Explicitly unavailable: multiple profiles in a sequence
    @available(*, unavailable, message: "The body of a 'DynamicProfile' must evaluate to a single active profile")
    public static func buildBlock<each Content>(_ contents: repeat each Content) -> Never
}
```

Attempting to place two profiles sequentially inside `body` produces a compile-time fatal diagnostic. All multi-profile structures must branch via `if/else` or `switch` statements.

### 2. Reactive Session Properties with `@SessionPropertyEntry`

Apple provides an observation-backed property store on `LanguageModelSession.properties` (`SessionPropertyValues`). New session properties are defined as extensions on `SessionPropertyValues`:

```swift
extension SessionPropertyValues {
    @SessionPropertyEntry
    public var organizationStrategy: OrganizationStrategy = .domain

    @SessionPropertyEntry
    public var quarantineSensitive: Bool = true
}
```

Inside a `DynamicProfile`, properties are declared using the `@LanguageModelSession.SessionProperty` property wrapper:

```swift
public struct DirectoryOrganizerProfile: LanguageModelSession.DynamicProfile {
    @LanguageModelSession.SessionProperty(\.organizationStrategy) var strategy: OrganizationStrategy
    let model: JevLanguageModel

    public var body: some LanguageModelSession.DynamicProfile {
        if strategy == .workflow {
            LanguageModelSession.Profile {
                Instructions("Prioritize actionability: Action Required, Reference, Archive.")
            }
            .model(model)
        } else {
            LanguageModelSession.Profile {
                Instructions("Prioritize domain: Finance, Engineering, Legal, Docs, Personal.")
            }
            .model(model)
        }
    }
}
```

Updating `session.properties.organizationStrategy = .workflow` in application code causes the session to re-evaluate the profile body and inject updated instructions without reallocating the session.

### 3. Turn Isolation via `.historyTransform`

When batch processing discrete tasks (such as inspecting 50 files in a folder), `LanguageModelSession` by default appends each prompt and response into the session transcript. This causes token usage to grow quadratically and risks prior file contents biasing subsequent classifications.

The `.historyTransform` modifier on `DynamicProfile` allows selective pruning before each generation pass:

```swift
.historyTransform { entries in
    // Keep top-level system instructions
    let instructions = entries.filter {
        if case .instructions = $0 { return true }
        return false
    }
    // Retain only the active prompt for the file currently being evaluated
    if let last = entries.last, case .prompt = last {
        return instructions + [last]
    }
    return entries
}
```

This delivers stateless per-turn execution semantics while retaining a persistent, observable session.

### 4. Custom Profile Modifiers

Reusable logging, auditing, and telemetry hooks can be encapsulated via `LanguageModelSession.DynamicProfileModifier`:

```swift
public struct TelemetryAuditModifier: LanguageModelSession.DynamicProfileModifier, Sendable {
    public func body(content: Content) -> some LanguageModelSession.DynamicProfile {
        content
            .onPrompt { prompt in
                // Hook fired before request translation
            }
            .onResponse { response in
                // Hook fired after Jev response synthesis
            }
    }
}
```

And applied cleanly with `.modifier(TelemetryAuditModifier())`.

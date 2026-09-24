# Developer Guide: Building CLI Tools with Laya & Foundation Models

This guide demonstrates how to build and deploy fast, deterministic command-line interface (CLI) applications and macOS developer daemons using **Laya** and **Apple Foundation Models**.

---

## 1. Development Workflow: Local `laya-serve`

During development, you want rapid iteration without waiting for Core ML model weights to compile or load into memory on every execution of your tool.

### Step 1: Start `laya-serve` in Terminal or Docker

Install the optional HTTP server dependencies and run the server:

```bash
# Option A: Direct Python installation
pip install "laya[serve]"
laya-serve

# Option B: Docker
docker run -p 8000:8000 ghcr.io/nandhakishorm/laya:latest
```

The server binds `0.0.0.0:8000` and speaks the standard `POST /v1/systemone` protocol.

### Step 2: Implement Your CLI Tool

In your Swift CLI target:

```swift
import Foundation
import FoundationModels
import LayaFoundationModels

@Generable
enum CodeReviewPriority: String, Sendable {
    case urgent
    case routine
    case nitpick
}

@Generable
struct CodeReviewDecision: Sendable {
    @Guide(description: "Does this diff introduce breaking security regressions?")
    var hasSecurityRisk: Bool

    @Guide(description: "Review priority based on architectural impact")
    var priority: CodeReviewPriority
}

@main
struct ReviewCLI {
    static func main() async throws {
        guard let diffText = CommandLine.arguments.dropFirst().first else {
            print("Usage: review-cli \"<git diff>\"")
            return
        }

        // Connect directly to local development server at localhost:8000
        let model = LayaLanguageModel(endpoint: .localDefault)
        let session = LanguageModelSession(model: model)

        let response = try await session.respond(to: diffText, generating: CodeReviewDecision.self)
        let decision = response.content

        print("Security Risk:", decision.hasSecurityRisk ? "🚨 YES" : "✅ NO")
        print("Priority:", decision.priority.rawValue.uppercased())
        if let riskProb = response.probability(for: "hasSecurityRisk") {
            print(String(format: "Risk Probability: %.1f%%", riskProb * 100))
        }
    }
}
```

---

## 2. Deployment Workflows

For shipping your CLI tool to end users or running it in automated CI/CD pipelines, choose between two deployment strategies:

### Strategy A: Self-Contained Standalone Binary with Core ML (`LayaOnDevice`)

Bundle the compiled `.mlmodelc` directly with your executable. Your tool runs natively on Apple Silicon with zero network access and zero external runtime dependencies (no Python, no PyTorch, no Docker):

1. **Compile Core ML Model**:
   ```bash
   python Tools/CoreMLConverter/convert_laya_to_coreml.py \
       --model convaiinnovations/laya \
       --output LayaModernBERT.mlpackage \
       --quantize 8bit

   xcrun coremlcompiler compile LayaModernBERT.mlpackage Resources/
   ```

2. **Embed in `Package.swift`**:
   ```swift
   .executableTarget(
       name: "review-cli",
       dependencies: ["LayaOnDevice"],
       resources: [.copy("Resources/LayaModernBERT.mlmodelc")]
   )
   ```

3. **Runtime Execution**:
   ```swift
   import FoundationModels
   import LayaOnDevice

   let modelURL = Bundle.module.url(forResource: "LayaModernBERT", withExtension: "mlmodelc")!
   let engine = try LayaCoreMLEngine(
       modelURL: modelURL,
       tokenizer: ModernBERTTokenizer.defaultTokenizer()
   )
   let session = LanguageModelSession(model: LayaOnDeviceLanguageModel(engine: engine))
   let response = try await session.respond(to: diffText, generating: CodeReviewDecision.self)
   ```

### Strategy B: Microservice-Backed CLI (`LayaFoundationModels`)

Keep the CLI binary lean (< 15 MB) and connect to a hosted enterprise Laya instance or internal company VPC:

```swift
let endpoint: LayaEndpoint = ProcessInfo.processInfo.environment["LAYA_ENDPOINT"].map {
    .custom(URL(string: $0)!)
} ?? .hosted

let model = LayaLanguageModel(
    endpoint: endpoint,
    apiKey: ProcessInfo.processInfo.environment["LAYA_API_KEY"]
)
let session = LanguageModelSession(model: model)
```

---

## 3. Deterministic Offline Testing

Test your CLI tools without live network connections or model weight loading using `MockSystemOneBackend`:

```swift
import Testing
import FoundationModels
import SystemOneCore

@Test func testCodeReviewDecision() async throws {
    let mock = MockSystemOneBackend { request in
        SystemOneResponse(
            model: "mock-v1",
            answers: [
                "hasSecurityRisk": SystemOneAnswer(type: "noul", noul: 0.98),
                "priority": SystemOneAnswer(type: "choice", choice: "urgent")
            ]
        )
    }

    let model = SystemOneLanguageModel(backend: mock)
    let session = LanguageModelSession(model: model)

    let response = try await session.respond(to: "API key leaked in diff", generating: CodeReviewDecision.self)
    #expect(response.content.hasSecurityRisk == true)
    #expect(response.content.priority == .urgent)
}
```

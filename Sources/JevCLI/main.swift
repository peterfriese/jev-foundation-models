import Foundation
import FoundationModels
import JevFoundationModels

print("=== Jev for Apple Foundation Models CLI Demo ===")

// Quick demo check
guard let apiKey = ProcessInfo.processInfo.environment["TYPESAFE_API_KEY"] else {
    print("Notice: TYPESAFE_API_KEY environment variable is not set.")
    print("To test against the live TypeSafe API, run:")
    print("  export TYPESAFE_API_KEY=your_key_here")
    print("  swift run jev-cli")
    exit(0)
}

print("Initializing JevLanguageModel with API key...")
let model = JevLanguageModel(apiKey: apiKey)
print("LanguageModel configured: \(model.executorConfiguration.modelID)")
print("Capabilities: supportsStructuredOutput=\(model.capabilities.supportsStructuredOutput), supportsTools=\(model.capabilities.supportsTools)")
print("Done.")

import Foundation
import FoundationModels
import JevFoundationModels

// MARK: - JevLanguageModel Resolution Extension (Matching CLI Ergonomics)

extension JevLanguageModel {
    /// Resolves the TypeSafe API key by checking launch arguments (-TYPESAFE_API_KEY <key>),
    /// UserDefaults, environment variables, or explicit parameter.
    public static func resolveAPIKey(explicitKey: String? = nil) -> String? {
        if let key = explicitKey, !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return key.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // 1. Check UserDefaults (populated by standard iOS launch args: -TYPESAFE_API_KEY <key> or -apiKey <key>)
        if let key = UserDefaults.standard.string(forKey: "TYPESAFE_API_KEY"), !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return key.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let key = UserDefaults.standard.string(forKey: "apiKey"), !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return key.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // 2. Parse ProcessInfo launch arguments: --api-key <key>, -apiKey <key>, -TYPESAFE_API_KEY <key>, or --api-key=<key>
        let args = ProcessInfo.processInfo.arguments
        for i in 0..<args.count {
            let arg = args[i]
            if arg == "--api-key" || arg == "-apiKey" || arg == "-TYPESAFE_API_KEY" || arg == "-key" {
                if i + 1 < args.count {
                    let next = args[i + 1]
                    if !next.hasPrefix("-") && !next.isEmpty {
                        return next.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                }
            } else if arg.hasPrefix("--api-key=") {
                let val = String(arg.dropFirst("--api-key=".count))
                if !val.isEmpty {
                    return val.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }

        // 3. Check environment variables
        if let key = ProcessInfo.processInfo.environment["TYPESAFE_API_KEY"], !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return key.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return nil
    }

    /// Default JevLanguageModel instance, resolving credentials automatically.
    public static var `default`: JevLanguageModel {
        let key = resolveAPIKey() ?? ""
        return JevLanguageModel(apiKey: key)
    }
}

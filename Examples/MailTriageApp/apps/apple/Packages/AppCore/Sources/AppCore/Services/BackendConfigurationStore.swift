import Foundation
import Observation
import FactoryKit

/// Observable configuration manager for System One endpoints and credentials.
@Observable
public final class BackendConfigurationStore: @unchecked Sendable {
    private let userDefaults: UserDefaults
    private let lock = NSLock()

    @ObservationIgnored
    @Injected(\.keychainService) private var keychain

    public static let defaultJevCloudURL = "https://api.typesafe.ai/v1/systemone"
    public static let defaultLocalServeURL = "http://127.0.0.1:8000/v1/systemone"
    public static let defaultHostedVpcURL = "https://api.impossibl.com/v1/systemone"
    public static let defaultCoreMLDownloadURL = "https://huggingface.co/aac6fef/laya-mlx/resolve/main/model.safetensors"

    /// Normalizes System One endpoint URLs to ensure they target the `/v1/systemone` route (SEC-4).
    /// - Rejects non-HTTP/HTTPS schemes (`file://`, `javascript:`, etc.) and returns the fallback URL.
    /// - Requires HTTPS for remote network endpoints. Permissive unencrypted HTTP is restricted strictly to loopback addresses (`127.0.0.1`, `localhost`, `::1`). Remote HTTP endpoints are automatically promoted to HTTPS.
    /// - If the input ends in `/v1`, appends `/systemone`.
    /// - If the input ends in port `:8000` or root host, appends `/v1/systemone`.
    public static func normalizeSystemOneEndpoint(_ urlString: String, defaultURL: String) -> URL {
        let fallback = URL(string: defaultURL) ?? URL(string: defaultLocalServeURL)!
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return fallback }

        guard var components = URLComponents(string: trimmed),
              let scheme = components.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              let host = components.host,
              !host.isEmpty else {
            return fallback
        }

        let isLoopback = ["localhost", "127.0.0.1", "::1", "[::1]"].contains(host.lowercased())
        if scheme == "http" && !isLoopback {
            components.scheme = "https"
        }

        var path = components.path
        while path.hasSuffix("/") && path.count > 1 {
            path.removeLast()
        }

        if path.isEmpty || path == "/" {
            components.path = "/v1/systemone"
        } else if path.hasSuffix("/systemone") {
            components.path = path
        } else if path.hasSuffix("/v1") {
            components.path = path + "/systemone"
        } else {
            components.path = path + "/v1/systemone"
        }

        return components.url ?? fallback
    }

    private enum Keys {
        static let jevCloudURL = "ai.typesafe.mailtriage.jevCloudURL"
        static let localServeURL = "ai.typesafe.mailtriage.localServeURL"
        static let hostedVpcURL = "ai.typesafe.mailtriage.hostedVpcURL"
        static let coreMLDownloadURL = "ai.typesafe.mailtriage.coreMLDownloadURL"
    }

    public var jevCloudURL: String {
        didSet { userDefaults.set(jevCloudURL, forKey: Keys.jevCloudURL) }
    }

    public var localServeURL: String {
        didSet { userDefaults.set(localServeURL, forKey: Keys.localServeURL) }
    }

    public var hostedVpcURL: String {
        didSet { userDefaults.set(hostedVpcURL, forKey: Keys.hostedVpcURL) }
    }

    public var coreMLDownloadURL: String {
        didSet { userDefaults.set(coreMLDownloadURL, forKey: Keys.coreMLDownloadURL) }
    }

    public var typesafeApiKey: String {
        get {
            if keychain is MockKeychainService {
                return keychain.typesafeApiKey ?? ""
            }
            if let envKey = ProcessInfo.processInfo.environment["TYPESAFE_API_KEY"], !envKey.isEmpty {
                keychain.typesafeApiKey = envKey
                return envKey
            }
            let key = keychain.typesafeApiKey ?? ""
            if !key.isEmpty { return key }
            if let dotEnvKey = Self.loadKeyFromDotEnv("TYPESAFE_API_KEY"), !dotEnvKey.isEmpty {
                keychain.typesafeApiKey = dotEnvKey
                return dotEnvKey
            }
            return ""
        }
        set { keychain.typesafeApiKey = newValue.trimmingCharacters(in: .whitespacesAndNewlines) }
    }

    /// In DEBUG builds, attempts to load a key from a `.env` file located in the bundle or current working directory (SEC-2).
    /// Never crawls parent directories or references `#filePath` to avoid path leakage into compiled binaries
    /// and sandbox violations. In non-DEBUG builds, returns `nil`.
    public static func loadKeyFromDotEnv(_ key: String) -> String? {
        #if DEBUG
        var candidateURLs: [URL] = [
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(".env")
        ]
        if let resourceURL = Bundle.main.resourceURL {
            candidateURLs.append(resourceURL.appendingPathComponent(".env"))
        }

        for dotEnvURL in candidateURLs {
            if FileManager.default.fileExists(atPath: dotEnvURL.path) {
                if let value = parseDotEnvFile(at: dotEnvURL, key: key) {
                    return value
                }
            }
        }
        return nil
        #else
        return nil
        #endif
    }

    /// Parses a `.env` file at the specified URL for a given key.
    public static func parseDotEnvFile(at url: URL, key: String) -> String? {
        guard let data = try? Data(contentsOf: url),
              let content = String(data: data, encoding: .utf8) else {
            return nil
        }
        return parseDotEnvContent(content, key: key)
    }

    /// Parses the content of a `.env` file for a given key (`KEY=VALUE` or `KEY="VALUE"` or `KEY='VALUE'`).
    public static func parseDotEnvContent(_ content: String, key: String) -> String? {
        let lines = content.components(separatedBy: .newlines)
        for rawLine in lines {
            var line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty || line.hasPrefix("#") {
                continue
            }
            if line.hasPrefix("export ") {
                line = String(line.dropFirst("export ".count)).trimmingCharacters(in: .whitespaces)
            }
            guard let equalsIndex = line.firstIndex(of: "=") else {
                continue
            }
            let lineKey = String(line[..<equalsIndex]).trimmingCharacters(in: .whitespaces)
            guard lineKey == key else {
                continue
            }
            var val = String(line[line.index(after: equalsIndex)...]).trimmingCharacters(in: .whitespaces)
            if (val.hasPrefix("\"") && val.hasSuffix("\"") && val.count >= 2) ||
               (val.hasPrefix("'") && val.hasSuffix("'") && val.count >= 2) {
                val = String(val.dropFirst().dropLast())
            }
            let trimmed = val.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed
            }
        }
        return nil
    }

    public var hostedVpcToken: String {
        get { keychain.hostedVpcToken ?? "" }
        set { keychain.hostedVpcToken = newValue.trimmingCharacters(in: .whitespacesAndNewlines) }
    }

    public var huggingFaceToken: String {
        get { keychain.huggingFaceToken ?? "" }
        set { keychain.huggingFaceToken = newValue.trimmingCharacters(in: .whitespacesAndNewlines) }
    }

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.jevCloudURL = userDefaults.string(forKey: Keys.jevCloudURL) ?? Self.defaultJevCloudURL

        // Migration and normalization for local serve URL
        let storedLocal = userDefaults.string(forKey: Keys.localServeURL)
        if storedLocal == "http://127.0.0.1:8000/v1" || storedLocal == "http://127.0.0.1:8000" {
            self.localServeURL = Self.defaultLocalServeURL
            userDefaults.set(Self.defaultLocalServeURL, forKey: Keys.localServeURL)
        } else if let storedLocal, !storedLocal.isEmpty {
            let normalized = Self.normalizeSystemOneEndpoint(storedLocal, defaultURL: Self.defaultLocalServeURL).absoluteString
            self.localServeURL = normalized
            if normalized != storedLocal {
                userDefaults.set(normalized, forKey: Keys.localServeURL)
            }
        } else {
            self.localServeURL = Self.defaultLocalServeURL
        }

        // Migration and normalization for hosted VPC URL
        let storedVPC = userDefaults.string(forKey: Keys.hostedVpcURL)
        if storedVPC == "https://api.impossibl.com/v1" || storedVPC == "https://api.impossibl.com" {
            self.hostedVpcURL = Self.defaultHostedVpcURL
            userDefaults.set(Self.defaultHostedVpcURL, forKey: Keys.hostedVpcURL)
        } else if let storedVPC, !storedVPC.isEmpty {
            let normalized = Self.normalizeSystemOneEndpoint(storedVPC, defaultURL: Self.defaultHostedVpcURL).absoluteString
            self.hostedVpcURL = normalized
            if normalized != storedVPC {
                userDefaults.set(normalized, forKey: Keys.hostedVpcURL)
            }
        } else {
            self.hostedVpcURL = Self.defaultHostedVpcURL
        }

        let storedCoreML = userDefaults.string(forKey: Keys.coreMLDownloadURL)
        if storedCoreML == nil
            || storedCoreML?.contains("typesafe/laya-421m-coreml") == true
            || storedCoreML?.contains("LayaModernBERT.mlmodelc.zip") == true
            || storedCoreML == "https://huggingface.co/aac6fef/laya-mlx"
            || storedCoreML == "https://huggingface.co/aac6fef/laya-mlx/" {
            self.coreMLDownloadURL = Self.defaultCoreMLDownloadURL
            if storedCoreML != nil {
                userDefaults.set(Self.defaultCoreMLDownloadURL, forKey: Keys.coreMLDownloadURL)
            }
        } else {
            self.coreMLDownloadURL = storedCoreML!
        }
    }

    public func resetToDefaults() {
        jevCloudURL = Self.defaultJevCloudURL
        localServeURL = Self.defaultLocalServeURL
        hostedVpcURL = Self.defaultHostedVpcURL
        coreMLDownloadURL = Self.defaultCoreMLDownloadURL
        typesafeApiKey = ""
        hostedVpcToken = ""
        huggingFaceToken = ""
    }
}

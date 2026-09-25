import Foundation

/// The five distinct runtime deployment topologies supported by MailTriage.
public enum TriageBackend: String, Sendable, Hashable, Codable, CaseIterable, Identifiable, CodingKeyRepresentable {
    /// Backend 1: Core ML running locally on Apple Silicon ANE/GPU (LayaOnDevice).
    case onDeviceCoreML

    /// Backend 2: Local HTTP server at 127.0.0.1:8000 (LayaFoundationModels).
    case localServe

    /// Backend 3: Enterprise self-hosted VPC at https://api.impossibl.com/v1.
    case hostedVPC

    /// Backend 4: Managed cloud SaaS (TypeSafe Jev Cloud API).
    case cloudAPI

    /// Backend 5: Generative baseline (Apple Intelligence On-Device LLM).
    case generativeBaseline

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .onDeviceCoreML:
            return "On-Device Core ML"
        case .localServe:
            return "Local laya-serve"
        case .hostedVPC:
            return "Hosted VPC"
        case .cloudAPI:
            return "Jev Cloud API"
        case .generativeBaseline:
            return "Generative Baseline"
        }
    }

    public var shortName: String {
        switch self {
        case .onDeviceCoreML:
            return "Core ML"
        case .localServe:
            return "laya-serve"
        case .hostedVPC:
            return "Hosted VPC"
        case .cloudAPI:
            return "Jev Cloud"
        case .generativeBaseline:
            return "Apple LLM"
        }
    }

    public var description: String {
        switch self {
        case .onDeviceCoreML:
            return "Apple Neural Engine (ANE) on-device inference with zero network ingress/egress."
        case .localServe:
            return "Local microservice daemon running on localhost loopback (127.0.0.1:8000)."
        case .hostedVPC:
            return "Private enterprise container deployment behind corporate firewall / VPC."
        case .cloudAPI:
            return "Managed TypeSafe Jev cloud endpoints with automated retries and jitter backoff."
        case .generativeBaseline:
            return "Apple Intelligence on-device ~3B generative LLM baseline comparison."
        }
    }

    public var iconName: String {
        switch self {
        case .onDeviceCoreML:
            return "cpu.fill"
        case .localServe:
            return "network"
        case .hostedVPC:
            return "server.rack"
        case .cloudAPI:
            return "cloud.fill"
        case .generativeBaseline:
            return "sparkles"
        }
    }

    /// Expected typical latency description for display in picker and benchmarks.
    public var latencyDescription: String {
        switch self {
        case .onDeviceCoreML:
            return "5–12 ms"
        case .localServe:
            return "8–15 ms"
        case .hostedVPC:
            return "40–70 ms"
        case .cloudAPI:
            return "60–90 ms"
        case .generativeBaseline:
            return "800–1,200 ms"
        }
    }

    /// Whether this backend operates completely offline without network requests.
    public var isOffline: Bool {
        switch self {
        case .onDeviceCoreML, .generativeBaseline:
            return true
        case .localServe, .hostedVPC, .cloudAPI:
            return false
        }
    }

    /// Whether this backend evaluates a fast non-autoregressive decision model.
    public var isDecisionModel: Bool {
        self != .generativeBaseline
    }
}

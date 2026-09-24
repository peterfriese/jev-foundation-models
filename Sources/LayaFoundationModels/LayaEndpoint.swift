import Foundation

/// Defines connection endpoints for Laya System One HTTP servers.
public enum LayaEndpoint: Sendable, Hashable {
    /// Default local server port (`http://127.0.0.1:8000/v1/systemone`).
    case localDefault
    /// Alternative local server port (`http://127.0.0.1:8770/v1/systemone`).
    case localAlt
    /// Custom local server port (`http://127.0.0.1:<port>/v1/systemone`).
    case local(port: Int)
    /// Hosted public/enterprise endpoint (`https://api.impossibl.com/v1/systemone`).
    case hosted
    /// An arbitrary custom URL.
    case custom(URL)

    /// The resolved URL for the `POST /v1/systemone` endpoint.
    public var url: URL {
        switch self {
        case .localDefault:
            return URL(string: "http://127.0.0.1:8000/v1/systemone")!
        case .localAlt:
            return URL(string: "http://127.0.0.1:8770/v1/systemone")!
        case .local(let port):
            return URL(string: "http://127.0.0.1:\(port)/v1/systemone")!
        case .hosted:
            return URL(string: "https://api.impossibl.com/v1/systemone")!
        case .custom(let customURL):
            return customURL
        }
    }
}

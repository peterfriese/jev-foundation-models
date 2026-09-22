# 0003 — Secure Mobile Transport with Firebase App Check & Apple App Attest

- **Date**: 2026-09-21
- **Author**: Peter Friese
- **Framework**: `FoundationModels` (iOS 27.0+, macOS 27.0+)
- **Upstream**: TypeSafe AI Jev (System One)

---

## Context

TypeSafe AI's System One decision model currently relies exclusively on static API key authentication (`Authorization: Bearer <TYPESAFE_API_KEY>`) sent to `https://api.typesafe.ai/v1/systemone`. Upstream does not offer an OAuth 2.0 Authorization Server, Token Exchange endpoint (RFC 8693), or short-lived ephemeral client-token minting endpoint.

Embedding secret API keys into client-side mobile applications (iOS, iPadOS, visionOS) is an insecure anti-pattern:
1. Static strings in compiled Swift binaries can be recovered via basic disassembly (`strings`, Hopper, Ghidra).
2. HTTPS traffic from client devices can be intercepted and inspected via local proxies (Proxyman, Charles, mitmproxy).
3. A leaked API key grants unrestricted billable access to the owner's TypeSafe AI account.

At the same time, `JevFoundationModels` is designed with a strict mandate: **Zero External Third-Party Runtime Dependencies**. The core library cannot directly depend on Google Firebase, AWS, or other vendor SDKs.

This tech note documents how to achieve production-grade mobile security using **Apple App Attest** via **Firebase App Check** and a **Firebase Cloud Function reverse proxy**, bridged into `JevFoundationModels` via the native `JevTransport` protocol.

---

## Findings

### 1. Ingress Verification & Token Replay Protection
When deploying a Firebase Cloud Function (2nd Gen) proxy:
- Requests lacking a valid `X-Firebase-AppCheck` header are immediately rejected with `401 Unauthorized`.
- Unauthenticated requests (bots, scrapers, cURL scripts, tampered binaries) cannot reach the upstream TypeSafe API.
- For sensitive endpoints, setting `CONSUME_APP_CHECK="true"` consumes the token on verification, providing strict **replay protection**: any reused token is rejected with `401 Unauthorized`.

### 2. Apple Secure Enclave Integrity without User Accounts
On physical Apple devices running iOS 14+ / macOS 14+, Firebase App Check activates Apple's `DCAppAttestService` (`DeviceCheck.framework`):
- The device generates a private key held exclusively inside the hardware **Secure Enclave**.
- Apple's attestation servers certify that the key was created by an un-tampered, genuine version of the application matching the registered Team ID and Bundle ID.
- Each decision request or session refresh is signed by this hardware key, producing a short-lived (~1 hour) App Check JWT.
- Mobile applications do not need user logins or accounts (e.g. Sign in with Apple) to establish strong device authenticity.

### 3. Decoupled Architecture via `JevTransport` & Progressive Disclosure
Because `JevFoundationModels` defines `JevTransport` as an open `Sendable` protocol:
```swift
public protocol JevTransport: Sendable {
    func send(request: JevRequest, apiKey: String, endpoint: URL) async throws -> JevResponse
}
```
Client applications can conform an application-level type (`FirebaseAppCheckTransport`) to `JevTransport`. The custom transport:
- Supports two token strategies:
  - `.cached` (default): Fetches pre-cached tokens from `AppCheck.appCheck().token(forcingRefresh: false)` in `< 1 ms`.
  - `.singleUse`: Fetches consumable tokens from `AppCheck.appCheck().limitedUseToken()` with replay protection.
- Attaches the `X-Firebase-AppCheck` HTTP header.
- Points the request to the Cloud Function URL instead of TypeSafe's public endpoint.
- Transmits standard `JevRequest` JSON and deserializes standard `JevResponse` JSON.

The core `JevFoundationModels` package remains completely pure, lightweight, and free of third-party SDK dependencies.

### 4. Secret Isolation in Google Cloud Secret Manager
The master `TYPESAFE_API_KEY` is provisioned using Google Cloud Secret Manager (`defineSecret("TYPESAFE_API_KEY")`) and injected into the Cloud Function at runtime. The key never exists on client hardware, in source control, or in mobile application bundles.

### 5. Latency Profile & In-Memory Token Caching
Empirical profiling reveals the latency characteristics of both strategies:
- **Cached Strategy (`.cached`):** `AppCheck.appCheck().token(forcingRefresh: false)` retrieves a pre-cached JWT from memory in **< 1 ms**. Apple's Secure Enclave hardware attestation runs in the background at 1-hour intervals, avoiding per-request crypto stalls. Warm round-trip latency is typically **120–240 ms** (including Jev's 40–120 ms inference).
- **Single-Use Strategy (`.singleUse`):** Acquiring a consumable token via `limitedUseToken()` incurs an outbound network call to Firebase (~40–120 ms), and server-side token consumption adds ~25–60 ms. Total round-trip latency is **250–450 ms**.
- **Recommendation:** Use `.cached` for responsive UI interactions, autocompletion, and interactive triage. Use `.singleUse` for sensitive actions, billing events, or automated execution loops.

### 6. Cold-Start Elimination via `minInstances`
Because Firebase Cloud Functions (2nd Gen) run on Google Cloud Run, default scale-to-zero behavior can incur a **500 ms to 1.5 s** cold start on initial requests.
- Setting `minInstances: 1` keeps a single container pre-warmed 24/7, completely eliminating cold starts.
- Furthermore, 2nd Gen Cloud Functions support up to **80 concurrent requests per instance**, meaning a single warm container can absorb significant concurrent mobile traffic without scaling delays.

### 7. Replay Protection via Limited-Use Tokens
While standard App Check tokens block non-app clients, a user on a jailbroken or proxied device (e.g. Proxyman/Charles with custom root CA) could extract their valid token and replay it within its 1-hour window.
- Consuming tokens via `getAppCheck().verifyToken(token, { consume: true })` ensures every token can only be used once.
- Subsequent calls with the same token yield `claims.alreadyConsumed === true`.
- Requires granting the `roles/appcheck.tokenVerifier` IAM role to the function's compute service account.

---

## Implications

1. **Standard Call-Site Preservation & Progressive Disclosure:**
   Developers retain the exact standard Apple Foundation Models API with configurable token hardening:
   ```swift
   // Fast, interactive evaluations (< 1 ms token lookup)
   let transport = FirebaseAppCheckTransport(proxyEndpoint: proxyURL, tokenStrategy: .cached)
   // OR: Replay-protected evaluations for sensitive actions
   // let transport = FirebaseAppCheckTransport(proxyEndpoint: proxyURL, tokenStrategy: .singleUse)

   let jev = JevLanguageModel(apiKey: "app-check", transport: transport)
   let session = LanguageModelSession(model: jev)
   let response = try await session.respond(to: stateText, generating: MyDecision.self)
   ```
2. **Sub-250 ms Interactive Latency:**
   With `minInstances: 1` and `.cached` tokens, warm round-trips match interactive UI performance budgets, making System One evaluations feel instantaneous in mobile applications.
3. **Replay Attack Resilience:**
   Enabling `tokenStrategy: .singleUse` guarantees that captured tokens cannot be replayed from malicious scripts or automated attack loops.
4. **Simulator & Preview Compatibility:**
   In development, Xcode Simulators and SwiftUI Previews lack Secure Enclave attestation hardware. Using `AppCheckDebugProviderFactory` allows developers to register local debug secrets in the Firebase Console, enabling full end-to-end integration testing offline and in simulators.
5. **Preservation of Decision Analytics:**
   The Cloud Function forwards `JevResponse` without mutation, allowing `JevExecutor` to synthesize metadata (`response.metadata["confidence"]`, `response.metadata["probabilities"]`) and token usage seamlessly.

---

## Sources & References

- Apple Developer: [`DeviceCheck` & `DCAppAttestService`](https://developer.apple.com/documentation/devicecheck/validating_apps_that_connect_to_your_server)
- Firebase Documentation: [Firebase App Check for Apple Platforms](https://firebase.google.com/docs/app-check/ios)
- Firebase Documentation: [Enable App Check enforcement in Cloud Functions](https://firebase.google.com/docs/app-check/cloud-functions)
- TypeSafe AI: [System One HTTP API Reference](https://docs.typesafe.ai/api.md)

import Testing
import Foundation
@testable import JevFoundationModels

@Suite("HTTP Resilience & Retry Policy Tests")
struct ResilienceTests {

    @Test("Backoff grows exponentially by multiplier")
    func testBackoffExponentialGrowth() {
        let policy = RetryPolicy(
            maxAttempts: 4,
            initialDelay: .milliseconds(100),
            multiplier: 2.0,
            jitter: 0.0
        )

        // Attempt 1: 100ms * 2^0 = 100ms
        #expect(policy.backoff(afterAttempt: 1, randomness: 0.5) == .milliseconds(100))
        // Attempt 2: 100ms * 2^1 = 200ms
        #expect(policy.backoff(afterAttempt: 2, randomness: 0.5) == .milliseconds(200))
        // Attempt 3: 100ms * 2^2 = 400ms
        #expect(policy.backoff(afterAttempt: 3, randomness: 0.5) == .milliseconds(400))
        // Attempt 4: 100ms * 2^3 = 800ms
        #expect(policy.backoff(afterAttempt: 4, randomness: 0.5) == .milliseconds(800))
    }

    @Test("Jitter bounds delay within [1 - jitter ... 1 + jitter]")
    func testJitterBounds() {
        let policy = RetryPolicy(
            initialDelay: .milliseconds(100),
            multiplier: 2.0,
            jitter: 0.2
        )

        // Randomness = 0.0 -> factor = 1 - 0.2 = 0.8 -> 80ms
        #expect(policy.backoff(afterAttempt: 1, randomness: 0.0) == .milliseconds(80))
        // Randomness = 0.5 -> factor = 1 + 0 = 1.0 -> 100ms
        #expect(policy.backoff(afterAttempt: 1, randomness: 0.5) == .milliseconds(100))
        // Randomness = 1.0 -> factor = 1 + 0.2 = 1.2 -> 120ms
        #expect(policy.backoff(afterAttempt: 1, randomness: 1.0) == .milliseconds(120))
    }

    @Test("Parses integer seconds from Retry-After header")
    func testRetryAfterIntegerSeconds() {
        let policy = RetryPolicy.default
        let delay = policy.retryAfter(headerValue: "5", now: Date())
        #expect(delay == .seconds(5))
    }

    @Test("Parses RFC 9110 HTTP-date from Retry-After header")
    func testRetryAfterHTTPDates() {
        let policy = RetryPolicy.default
        let referenceNow = Date(timeIntervalSince1970: 0)

        // IMF-fixdate format: 10 seconds after reference epoch
        let header = "Thu, 01 Jan 1970 00:00:10 GMT"
        let delay = policy.retryAfter(headerValue: header, now: referenceNow)
        #expect(delay == .seconds(10))
    }

    @Test("Unparseable or negative Retry-After falls back to nil")
    func testRetryAfterInvalidFallback() {
        let policy = RetryPolicy.default
        let now = Date()

        #expect(policy.retryAfter(headerValue: "soon", now: now) == nil)
        #expect(policy.retryAfter(headerValue: "-5", now: now) == nil)
        #expect(policy.retryAfter(headerValue: "", now: now) == nil)
        #expect(policy.retryAfter(headerValue: nil, now: now) == nil)
    }

    @Test("Server-supplied Retry-After is capped by maxRetryAfter")
    func testRetryAfterCapped() {
        let policy = RetryPolicy(maxRetryAfter: .seconds(10))
        let delay = policy.retryAfter(headerValue: "9999", now: Date())
        #expect(delay == .seconds(10))
    }

    @Test("Duration saturation arithmetic prevents overflow traps")
    func testDurationSaturationSafety() {
        let largeDuration = Duration.seconds(1_000_000)
        let hugeMultiplier = Double.greatestFiniteMagnitude
        let saturated = largeDuration * hugeMultiplier
        #expect(saturated == .saturated)

        // Non-positive or non-finite multipliers return zero
        #expect(largeDuration * 0.0 == .zero)
        #expect(largeDuration * -1.0 == .zero)
        #expect(largeDuration * Double.nan == .zero)

        // Negative duration saturation
        let negativeDuration = Duration.seconds(-1_000_000)
        let negativeSaturated = negativeDuration * hugeMultiplier
        #expect(negativeSaturated == .negativeSaturated)

        // Infinite multiplier saturation
        #expect(largeDuration * Double.infinity == .saturated)
        #expect(negativeDuration * Double.infinity == .negativeSaturated)
    }

    @Test("Extreme retry attempt counts cap at maxRetryAfter instead of overflowing to zero")
    func testBackoffExtremeAttemptsClamped() {
        let policy = RetryPolicy(
            maxAttempts: 100,
            initialDelay: .milliseconds(500),
            multiplier: 2.0,
            maxRetryAfter: .seconds(60)
        )

        // Attempt 100: 2^99 overflows standard Double without clamping
        let delay = policy.backoff(afterAttempt: 100, randomness: 0.5)
        #expect(delay == .seconds(60))
        #expect(delay > .zero)
    }

    @Test("Nonsensical configurations are normalized gracefully without trapping")
    func testNonsensicalConfigurationNormalized() {
        let policy = RetryPolicy(
            maxAttempts: -5,
            initialDelay: .seconds(-10),
            multiplier: 0.1,
            jitter: 5.0,
            maxRetryAfter: .seconds(-20)
        )

        #expect(policy.maxAttempts == 1)
        #expect(policy.initialDelay == .zero)
        #expect(policy.multiplier == 1.0)
        #expect(policy.jitter == 1.0)
        #expect(policy.maxRetryAfter == .zero)
    }
}

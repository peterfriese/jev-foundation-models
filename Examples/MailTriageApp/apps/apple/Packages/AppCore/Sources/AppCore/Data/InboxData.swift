import Foundation

public enum InboxData {
    public static let sampleEmails: [Email] = generateSampleEmails()

    private static func generateSampleEmails() -> [Email] {
        let referenceDate = Date(timeIntervalSince1970: 1790294400) // Deterministic reference date in 2026

        struct Template {
            let sender: String
            let senderEmail: String
            let subject: String
            let snippet: String
            let body: String
            let category: EmailCategory
            let isVIP: Bool
            let urgencyScore: Int
            let requiresAction: Bool
            let suggestedAction: String
            let defaultMailbox: Mailbox
        }

        let templates: [Template] = [
            // CI/CD & Infrastructure alerts
            Template(
                sender: "Bazel Build Bot",
                senderEmail: "build-bot@infra.internal.corp",
                subject: "[BROKEN] //compiler/xla:neural_engine_codegen target failed on darwin_arm64",
                snippet: "Build failed during invocation sponge2.corp/invocation/948274a1. 14 targets failed compilation.",
                body: """
                Build //compiler/xla:neural_engine_codegen failed at commit a94f28e.

                ERROR: /workspace/compiler/xla/service/darwin/ane_compiler.cc:214:12: error: \
                use of undeclared identifier 'ANE_MAX_CORE_FREQUENCY'
                    214 |   uint64_t freq = ANE_MAX_CORE_FREQUENCY;
                        |                   ^

                Target //compiler/xla:pjrt_c_api was canceled due to upstream target failure.
                Invocation URL: https://sponge2.corp/invocation/948274a1-b841-4ce8-b118-8f59a9e921d0

                Affected branches:
                - main
                - release-26.4-ane

                Please revert the offending CL or push a fix immediately to unblock team CI.
                """,
                category: .work,
                isVIP: false,
                urgencyScore: 3,
                requiresAction: true,
                suggestedAction: "Revert commit a94f28e or patch ANE constant",
                defaultMailbox: .inbox
            ),
            Template(
                sender: "PagerDuty P0",
                senderEmail: "alerts@pagerduty.internal",
                subject: "[CRITICAL] P0 Alert: europe-west4-a TPU Pod Slice degraded (loss rate > 4.2%)",
                snippet: "Incident #94820 assigned to you. Error rate spiked above 4% threshold for 5 consecutive minutes.",
                body: """
                INCIDENT SUMMARY:
                Incident ID: #94820-P0
                Service: TPU Pod Fleet Manager (europe-west4-a)
                Severity: CRITICAL (P0)
                Trigger: Packet loss rate > 4.2% on host-to-host RoCE interconnect

                Metrics Snapshot:
                - Cluster: eu-west4-tpu-slice-08
                - Healthy hosts: 96 / 128 (32 nodes unreachable)
                - Impact: 4 active training jobs stalled

                War Room: https://meet.corp.google.com/p0-tpu-emergency
                Slack Channel: #incident-94820-tpu-roce

                Reply ACK to acknowledge or ESCALATE to secondary on-call.
                """,
                category: .securityAlerts,
                isVIP: true,
                urgencyScore: 3,
                requiresAction: true,
                suggestedAction: "Join war room & acknowledge incident",
                defaultMailbox: .inbox
            ),
            Template(
                sender: "GitHub Actions",
                senderEmail: "notifications@github.com",
                subject: "Run failed: Swift 6 Strict Concurrency Matrix (#2849)",
                snippet: "Job 'macOS-15-arm64 (swift-6.0)' failed in 3m 42s. 2 concurrency violations found.",
                body: """
                GitHub Actions workflow 'Strict Concurrency Matrix' failed for commit 8fb21e0.

                Job summary:
                - Target: Swift 6.0 Complete Concurrency Checking
                - Failures:
                  - MailStore.swift:14:8: error: mutation of non-Sendable type across isolation boundary
                  - DecisionRouting.swift:45:19: warning: capture of 'session' with non-Sendable type in actor closure

                View full workflow logs: https://github.com/typesafe-ai/system-one-foundation-models/actions/runs/1849204

                Commit message: 'Refactor DecisionSession dispatching'
                Author: Peter Friese <peter@apple.com>
                """,
                category: .work,
                isVIP: false,
                urgencyScore: 2,
                requiresAction: true,
                suggestedAction: "Fix Swift 6 concurrency warnings",
                defaultMailbox: .inbox
            ),
            // Code Reviews
            Template(
                sender: "Jeff Dean",
                senderEmail: "jeff@google.com",
                subject: "Review requested: CL/649201948 - Optimize memory layout in TensorBufferAllocator",
                snippet: "Can we avoid this heap allocation in the hot inference loop? Benchmarks look promising overall.",
                body: """
                Hi Peter,

                I looked over CL/649201948:
                "Optimize memory layout in TensorBufferAllocator for ANE hardware alignment."

                Overall the 18% throughput improvement on M4 Max is impressive. One question regarding:
                `Sources/CoreML/TensorBufferAllocator.swift:84`

                Could we use stack allocation or a scratch ring-buffer for intermediate tensor descriptors instead of `UnsafeMutableRawBufferPointer.allocate(byteCount:...)`?
                Under 120Hz continuous dispatch, the allocator churn might induce micro-stutters during GC/malloc passes.

                Let me know what you think, or let's chat in the design doc.

                Best,
                Jeff
                """,
                category: .work,
                isVIP: true,
                urgencyScore: 2,
                requiresAction: true,
                suggestedAction: "Reply to review comments & run microbenchmark",
                defaultMailbox: .inbox
            ),
            Template(
                sender: "Chris Lattner",
                senderEmail: "clattner@modular.com",
                subject: "Feedback on LanguageModelSession Swift 6 ergonomic proposals",
                snippet: "The call-site first approach with @Generable schemas is spot on. Here are some thoughts on Sendable isolation.",
                body: """
                Peter,

                Really enjoyed reviewing the latest draft of the Foundation Models System One bridge.

                Having:
                ```swift
                let session = LanguageModelSession(model: selectedModel)
                let response = try await session.respond(to: prompt, generating: Decision.self)
                ```
                as the primary call-site is exactly the kind of progressive disclosure Swift needs. It completely avoids the unnecessary abstraction layers that plagued earlier inference SDKs.

                One thought: for offline Core ML model loading, ensure the model compilation step doesn't hop back and forth across actors unnecessarily. Keeping the weights warm in unified memory will give you sub-5ms latencies.

                Let's catch up next week.

                Cheers,
                Chris
                """,
                category: .work,
                isVIP: true,
                urgencyScore: 1,
                requiresAction: false,
                suggestedAction: "Schedule catch-up sync",
                defaultMailbox: .inbox
            ),
            Template(
                sender: "Craig Federighi",
                senderEmail: "craig@apple.com",
                subject: "Liquid Glass adoption & ProMotion 120Hz validation in MailTriage",
                snippet: "Great work on keeping Liquid Glass outside of scroll view rows. The 120Hz ProMotion experience is velvety smooth.",
                body: """
                Team,

                I spent some time test driving the latest MailTriage build on macOS 27 and iOS 27.

                Adhering to the rule of keeping glass effects strictly in floating toolbars and navigation bars rather than list rows makes an enormous difference. The ProMotion scroll performance is silky smooth even with 500+ messages in the virtualized list.

                Let's ensure the empty state reader and the bottom triage drawer maintain that same level of visual finesse.

                Keep up the fantastic craftsmanship!

                Craig
                """,
                category: .work,
                isVIP: true,
                urgencyScore: 1,
                requiresAction: false,
                suggestedAction: "Forward note to engineering team",
                defaultMailbox: .inbox
            ),
            // Apple Purchases & Developer Program
            Template(
                sender: "Apple Developer Program",
                senderEmail: "developer@apple.com",
                subject: "Your Apple Developer Program membership has been renewed",
                snippet: "Your annual membership has been successfully renewed. Your certificates, identifiers, and profiles remain active.",
                body: """
                Dear Peter,

                Thank you for renewing your Apple Developer Program membership.

                Order Number: W948102847
                Membership Expiration: September 24, 2027
                Annual Fee: $99.00 USD

                All your app IDs, provisioning profiles, CloudKit databases, and TestFlight distributions will continue uninterrupted.
                You can manage your account and access pre-release SDKs at:
                https://developer.apple.com/account

                Apple Developer Relations
                """,
                category: .billing,
                isVIP: false,
                urgencyScore: 0,
                requiresAction: false,
                suggestedAction: "Archive receipt",
                defaultMailbox: .inbox
            ),
            Template(
                sender: "App Store Connect",
                senderEmail: "no_reply@email.apple.com",
                subject: "TestFlight: MailTriage version 2.4 (Build 492) is ready for testing",
                snippet: "Build 492 is now available for internal and external testers. Processing completed in 4 minutes.",
                body: """
                The following build has completed processing and is ready for TestFlight testing:

                App: MailTriage (macOS & iOS)
                Version: 2.4
                Build: 492
                SDK: macOS 27.0 / iOS 27.0
                Commit: 7ab1c9f (feature/liquid-glass-sidebar)

                To notify your testers or configure public test groups, visit App Store Connect:
                https://appstoreconnect.apple.com/apps/mailtriage/testflight

                Apple Worldwide Developer Relations
                """,
                category: .work,
                isVIP: false,
                urgencyScore: 1,
                requiresAction: false,
                suggestedAction: "Notify external test group",
                defaultMailbox: .inbox
            ),
            // Cloud Invoices & Billing
            Template(
                sender: "Google Cloud Billing",
                senderEmail: "billing-noreply@google.com",
                subject: "Monthly Statement: Google Cloud Platform TPU v5e Cluster ($14,892.40)",
                snippet: "Your invoice for billing period Aug 1 - Aug 31, 2026 is now available. Auto-payment will process in 3 days.",
                body: """
                Google Cloud Platform Billing Statement

                Account: TypeSafe AI Enterprise Production (ID: 0184A-94B2C-8812F)
                Billing Period: August 1, 2026 - August 31, 2026
                Total Due: $14,892.40 USD

                Breakdown:
                - Cloud TPU v5e Pod Slices (europe-west4): $11,240.00
                - Google Cloud Storage (Multi-region EU): $1,420.40
                - Inter-region Network Egress (RoCE / VPC): $1,850.00
                - Cloud Logging & Monitoring: $382.00

                Payment Method: Corporate Amex ending in 4092 (Auto-charge scheduled for Sep 27, 2026).
                Download official PDF tax invoice: https://console.cloud.google.com/billing
                """,
                category: .billing,
                isVIP: false,
                urgencyScore: 1,
                requiresAction: true,
                suggestedAction: "Forward invoice to accounting",
                defaultMailbox: .billing
            ),
            Template(
                sender: "Stripe Invoicing",
                senderEmail: "invoices@stripe.com",
                subject: "Invoice #INV-2026-9481 from TypeSafe Jev Cloud ($3,420.00)",
                snippet: "Receipt for 85,500,000 System One inference calls. Thank you for your business.",
                body: """
                Invoice #INV-2026-9481
                Amount Paid: $3,420.00 USD
                Date: September 22, 2026

                Description:
                - TypeSafe Jev Pro Tier Tier-1 Inferences: 85.5M decisions @ $0.040 per 1k calls
                - Mean Latency: 12ms (p99: 28ms)
                - Uptime SLA: 99.995%

                Card charged: Visa ending in 8831.
                Questions? Visit https://dashboard.typesafe.ai/billing
                """,
                category: .billing,
                isVIP: false,
                urgencyScore: 0,
                requiresAction: false,
                suggestedAction: "File receipt",
                defaultMailbox: .billing
            ),
            // Security notices & Phishing
            Template(
                sender: "Okta Security Alerts",
                senderEmail: "security-noreply@okta.com",
                subject: "Security Alert: New login from unrecognized device (Dublin, Ireland)",
                snippet: "A successful login to your Apple Corporate SSO was detected from macOS 14.2 in Dublin, Ireland.",
                body: """
                OKTA IDENTITY THREAT DETECTION

                A new sign-in was verified for user: peter@apple.com
                Time: Today at 04:12 AM UTC
                Location: Dublin, Leinster, Ireland (IP: 185.122.91.44)
                Device: macOS 14.2 / Safari 18.0
                Authentication Method: FastPass Biometrics + FIDO2 YubiKey

                If this was you (e.g. traveling or using corporate VPN), no action is required.
                If you did not authorize this login, immediately click:
                https://identity.apple.internal/revoke-all-sessions?token=948a12
                """,
                category: .securityAlerts,
                isVIP: false,
                urgencyScore: 2,
                requiresAction: true,
                suggestedAction: "Confirm VPN session or revoke credentials",
                defaultMailbox: .securityAlerts
            ),
            Template(
                sender: "Executive Payroll Office",
                senderEmail: "executive-wire-update@sec-notice-payroll-auth.info",
                subject: "URGENT: Confidential Executive Wire Transfer verification needed by 5 PM",
                snippet: "Please verify the urgent wire transfer instructions for the overseas board member immediately.",
                body: """
                CONFIDENTIAL & TIME SENSITIVE

                Hello,

                Due to the recent quarterly audit, we need you to review and verify the revised banking wire coordinates for the senior executive board distribution ($185,000.00).

                Please download the encrypted attachment below and verify your corporate credentials to confirm the SWIFT routing number before banking cutoff at 5:00 PM EST.

                Download Link: http://sec-notice-payroll-auth.info/wire-form-oct26.exe

                Thank you,
                Executive Finance Operations
                """,
                category: .quarantine,
                isVIP: false,
                urgencyScore: 3,
                requiresAction: true,
                suggestedAction: "Quarantine & report phishing attempt",
                defaultMailbox: .quarantine
            ),
            Template(
                sender: "Corporate Compliance",
                senderEmail: "compliance@apple.corp",
                subject: "Action Required: Complete Mandatory Q3 Security & Data Privacy Training",
                snippet: "Annual compliance deadline is approaching in 6 business days. Please complete the 20-minute module.",
                body: """
                Team Member,

                All Apple and affiliate engineers must complete the Q3 2026 Security & Data Privacy refresher before Friday, October 2nd.

                Course highlights:
                - On-device data isolation & Neural Engine safety protocols
                - Phishing defense and hardware security key usage
                - Handling confidential benchmark numbers

                Link to Learning Portal: https://learning.internal.apple.com/course/sec-q3-2026
                Estimated duration: 20 minutes.
                """,
                category: .work,
                isVIP: false,
                urgencyScore: 1,
                requiresAction: true,
                suggestedAction: "Schedule 20-minute calendar block",
                defaultMailbox: .inbox
            ),
            // Meetings & Calendar
            Template(
                sender: "Elena Rostova",
                senderEmail: "elena@apple.com",
                subject: "1:1 Sync Agenda: Q4 Engineering OKRs & Staff Promotion Packet",
                snippet: "Looking forward to our sync tomorrow at 10 AM. Here is the draft agenda and packet doc.",
                body: """
                Hi Peter,

                For our 1:1 tomorrow at 10:00 AM, I'd like to cover three topics:

                1. Reviewing the MailTriage Foundation Models launch metrics and community adoption.
                2. Finalizing your Staff Engineer promotion packet blurbs (I added notes to section 3).
                3. On-call coverage rotation for the upcoming Thanksgiving sprint.

                Meeting link: https://meet.apple.com/elena-peter-sync
                Agenda doc: https://quip.apple.com/9482/okr-staff-review

                See you tomorrow!
                Elena
                """,
                category: .meetings,
                isVIP: true,
                urgencyScore: 1,
                requiresAction: false,
                suggestedAction: "Review agenda doc before sync",
                defaultMailbox: .meetings
            ),
            Template(
                sender: "Marcus Vance",
                senderEmail: "marcus.v@apple.com",
                subject: "Sprint 26.4 Planning & Retro: Backlog Grooming Notes",
                snippet: "Summary of sprint commitments: 42 story points accepted, focusing on FoundationModels integration.",
                body: """
                Hi team,

                Here is the summary of our Sprint 26.4 Planning:

                Sprint Goals:
                - Implement 3-pane NavigationSplitView for MailTriage macOS & iOS
                - Achieve 100% offline unit testing via MockJevTransport & MockSystemOneBackend
                - Benchmark sub-10ms response times for on-device Core ML decisions

                Total capacity: 48 points. Committed: 42 points.
                Jira Sprint Board: https://jira.internal.apple.com/secure/RapidBoard.jspa?rapidView=819

                Thanks everyone for the focused discussion!
                Marcus
                """,
                category: .meetings,
                isVIP: false,
                urgencyScore: 1,
                requiresAction: false,
                suggestedAction: "Review committed tickets",
                defaultMailbox: .meetings
            ),
            Template(
                sender: "David Chen",
                senderEmail: "david.c@apple.com",
                subject: "On-call swap request: Covering primary shift on Tuesday Oct 6",
                snippet: "Can anyone swap primary on-call on Oct 6? Happy to take your weekend shift in exchange.",
                body: """
                Hey folks,

                I have a personal family conflict on Tuesday Oct 6 and won't be able to carry the primary PagerDuty pager from 9 AM to 9 PM PST.

                Would anyone on the rotation be willing to swap with me? I'm happy to cover your shift the following Saturday or Sunday in return.

                Let me know if that works for you and I'll submit the schedule override in PagerDuty.

                Thanks a ton,
                David
                """,
                category: .work,
                isVIP: false,
                urgencyScore: 2,
                requiresAction: true,
                suggestedAction: "Check calendar & reply to swap request",
                defaultMailbox: .inbox
            ),
            // Newsletters & Technical Digests
            Template(
                sender: "John Sundell",
                senderEmail: "john@swiftbysundell.com",
                subject: "Swift Weekly #418: Swift 6 Strict Concurrency, FlowDeck CLI, & Modern SwiftUI",
                snippet: "This week, we explore building high-performance macOS split views, mastering Swift 6 isolation, and FlowDeck.",
                body: """
                Welcome to Swift Weekly issue #418!

                In this issue:
                - Mastering Swift 6 Strict Concurrency: Why actor hops matter in high-throughput pipelines.
                - Apple's NavigationSplitView in macOS 27: Achieving native 3-column elegance with zero boilerplate.
                - FlowDeck CLI in Action: Revolutionizing Apple platform build automation with structured diagnostics.
                - Tip of the week: Using @Observable with fine-grained view invalidation.

                Read the full issue online at: https://swiftbysundell.com/weekly/418

                Happy Swifting!
                John
                """,
                category: .newsletters,
                isVIP: false,
                urgencyScore: 0,
                requiresAction: false,
                suggestedAction: "Read later in Safari Reading List",
                defaultMailbox: .newsletters
            ),
            Template(
                sender: "Alex Xu",
                senderEmail: "alex@bytebytego.com",
                subject: "ByteByteGo Newsletter: How Large-Scale Decision Engines Handle 10M QPS",
                snippet: "Deep dive into low-latency decision model architectures, single-pass forward propagation vs autoregression.",
                body: """
                Hi engineers,

                In today's deep dive, we explore why modern mobile architectures are shifting from heavy LLMs to lightweight System One decision models:

                1. Autoregressive token generation costs 20-50x more memory and latency than single-pass classification heads.
                2. Calibrated probabilities (Nouls) allow enterprise systems to safely route high-confidence actions while human-escalating ambiguities.
                3. On-device Apple Neural Engine execution eliminates network hops, achieving sub-5ms latency and zero cloud costs.

                Architecture diagram and benchmarks included in the full post:
                https://blog.bytebytego.com/p/decision-engines-architecture-10m-qps

                Until next time,
                Alex Xu
                """,
                category: .newsletters,
                isVIP: false,
                urgencyScore: 0,
                requiresAction: false,
                suggestedAction: "Bookmark article",
                defaultMailbox: .newsletters
            ),
            Template(
                sender: "ArXiv Daily Feed",
                senderEmail: "digest@arxiv.org",
                subject: "ArXiv CS.AI: Sparse Attention & Decision Transformer Architectures for On-Device Inference",
                snippet: "4 new papers matching your tracked topics: [cs.AI, cs.LG, Apple Neural Engine, Decision Models].",
                body: """
                arXiv Daily Computer Science Update
                Tracked categories: cs.AI, cs.LG, cs.NE

                1. "Sub-Millisecond System One Decision Modeling on Mobile Silicon"
                   Authors: K. Zhang, M. Hoffman, L. Dupont
                   Abstract: We present an optimization technique mapping multi-head decision models to hardware-accelerated INT8 matrix units on modern mobile SoCs, achieving 450 inferences/sec at under 0.8W power draw.

                2. "Calibrated Epistemic Uncertainty in Foundation Model Agents"
                   Authors: S. Venkatesh, R. Chen
                   Abstract: Proposing dual-signal confidence gating for autonomous workflow dispatch.

                Full papers available at: https://arxiv.org/list/cs.AI/recent
                """,
                category: .newsletters,
                isVIP: false,
                urgencyScore: 0,
                requiresAction: false,
                suggestedAction: "Save PDF to research folder",
                defaultMailbox: .newsletters
            ),
            Template(
                sender: "Kelsey Hightower",
                senderEmail: "kelsey@minimalist.dev",
                subject: "Reflecting on Simple Software Architectures in 2026",
                snippet: "The best code is the code that doesn't need to exist. Why native Apple Foundation Models hit the sweet spot.",
                body: """
                Peter,

                Read your technical note on the Foundation Models integration.

                "Simplicity is prerequisite for reliability." When developers don't have to manage custom HTTP connection pools, authentication headers, and proprietary response parsers, the entire application becomes much easier to reason about.

                Keep pushing for minimal abstractions. Software that gets out of the developer's way is the software that lasts.

                Best regards,
                Kelsey
                """,
                category: .work,
                isVIP: true,
                urgencyScore: 0,
                requiresAction: false,
                suggestedAction: "Reply with appreciation",
                defaultMailbox: .inbox
            )
        ]

        var emails: [Email] = []
        emails.reserveCapacity(500)

        // Target: exactly 500 emails, with ~180 unread (let's do exactly 180 unread and 320 read)
        // Mailbox distribution:
        // - inbox: 415
        // - drafts: 15
        // - sent: 25
        // - archive: 25
        // - quarantine: 10
        // - securityAlerts: 10

        let totalEmails = 500
        let targetUnread = 180

        // Select exactly targetUnread (180) indices within inbox items (0..<415)
        var unreadIndices = Set<Int>()
        var stepCounter = 0
        while unreadIndices.count < targetUnread && stepCounter < 1000 {
            let index = (stepCounter * 7 + 1) % 415
            unreadIndices.insert(index)
            stepCounter += 1
        }

        // Secondary senders for variety
        let secondarySenders = [
            ("Sarah Connor", "sarah.c@apple.com"),
            ("Priya Patel", "priya.p@corp.net"),
            ("Alexei Romanov", "alexei@security.internal"),
            ("Jordan Lee", "jordan.lee@dev.to"),
            ("Rachel Adams", "radams@cloudops.org"),
            ("Michael Chang", "mchang@systems.internal"),
            ("Hanna Lindberg", "hanna.l@nordic-tech.io"),
            ("Tariq Mansoor", "tariq@neural-inference.org")
        ]

        for i in 0..<totalEmails {
            let baseTemplate = templates[i % templates.count]
            let isUnread = unreadIndices.contains(i)

            // Calculate timestamp: item 0 is 2 minutes ago, spread out over ~14 days (1,209,600 seconds)
            // Quadratic distribution so there are more recent emails today/yesterday
            let normalizedRatio = Double(i) / Double(totalEmails)
            let secondsAgo = 120.0 + (normalizedRatio * normalizedRatio * 1_200_000.0) + Double(i * 180)
            let emailDate = referenceDate.addingTimeInterval(-secondsAgo)

            // Flags: roughly 1 in 8 emails flagged
            let isFlagged = (i % 8 == 2)

            // VIP: based on template or specific prominent indices
            let isVIP = baseTemplate.isVIP || (i % 15 == 0)

            // Sender variation: periodically inject secondary senders
            let sender: String
            let senderEmail: String
            if i >= templates.count && i % 4 == 0 {
                let sec = secondarySenders[(i / 4) % secondarySenders.count]
                sender = sec.0
                senderEmail = sec.1
            } else {
                sender = baseTemplate.sender
                senderEmail = baseTemplate.senderEmail
            }

            // Subject with subtle index qualification if repetitive
            let subject: String
            if i < templates.count {
                subject = baseTemplate.subject
            } else {
                let cycle = (i / templates.count) + 1
                switch baseTemplate.category {
                case .work:
                    subject = "\(baseTemplate.subject) [Batch #\(cycle)]"
                case .securityAlerts:
                    subject = "\(baseTemplate.subject) (Ticket #\(8000 + i))"
                case .billing:
                    subject = "\(baseTemplate.subject) (Ref #\(4000 + i))"
                case .meetings:
                    subject = "\(baseTemplate.subject) (Follow-up #\(cycle))"
                case .newsletters:
                    subject = "\(baseTemplate.subject) — Edition \(cycle)"
                case .quarantine:
                    subject = "\(baseTemplate.subject) [Ref \(900 + i)]"
                }
            }

            // Mailbox assignment:
            let mailbox: Mailbox
            if i < 415 {
                mailbox = .inbox
            } else if i < 430 {
                mailbox = .drafts
            } else if i < 455 {
                mailbox = .sent
            } else if i < 480 {
                mailbox = .archive
            } else if i < 490 {
                mailbox = .quarantine
            } else {
                mailbox = .securityAlerts
            }

            let email = Email(
                id: UUID(),
                sender: sender,
                senderEmail: senderEmail,
                recipient: (mailbox == .sent) ? "team@apple.com" : "developer@apple.com",
                subject: subject,
                previewSnippet: baseTemplate.snippet,
                body: baseTemplate.body,
                date: emailDate,
                isUnread: (mailbox == .sent || mailbox == .drafts) ? false : isUnread,
                isFlagged: isFlagged,
                isVIP: isVIP,
                mailbox: mailbox,
                category: baseTemplate.category,
                urgencyScore: baseTemplate.urgencyScore,
                requiresAction: baseTemplate.requiresAction,
                suggestedAction: baseTemplate.suggestedAction
            )

            emails.append(email)
        }

        // Sort descending by date (newest first)
        emails.sort { $0.date > $1.date }

        return emails
    }
}

import Foundation

/// Provides realistic multi-domain test files for directory organization.
public enum SampleData {
    public struct SampleFile: Sendable {
        public let relativePath: String
        public let content: String

        public init(_ relativePath: String, _ content: String) {
            self.relativePath = relativePath
            self.content = content
        }
    }

    public static let invoice = SampleFile(
        "Invoice_INV-2026-9041.txt",
        """
        ======================================================================
        INVOICE: INV-2026-9041
        ISSUER: Apex Cloud Consulting LLC
        BILL TO: Acme Corporation
        ISSUE DATE: September 15, 2026
        PAYMENT DUE: October 1, 2026 (ACTION REQUIRED)
        ----------------------------------------------------------------------
        Description                                 Hours   Rate    Amount
        Stratos Swift 6 Concurrency Migration          40   $250   $10,000.00
        Apple Foundation Models Jev Integration        35   $250    $8,750.00
        ----------------------------------------------------------------------
        TOTAL DUE: $18,750.00 USD
        Wire Transfer Instructions:
        Bank: Silicon Valley Commercial Bank
        Routing: 121000358
        Account: 8849-2019-3321
        Please remit payment prior to due date to avoid late penalty.
        ======================================================================
        """
    )

    public static let credentialsEnv = SampleFile(
        "production_credentials.env",
        """
        # CRITICAL PRODUCTION SECRETS - DO NOT COMMIT
        ENVIRONMENT=production
        TYPESAFE_API_KEY=dummy_mock_typesafe_key_for_testing
        AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE
        AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
        DATABASE_URL=postgres://app_admin:dummy_mock_password@db-prod.internal:5432/main_db
        STRIPE_SECRET_KEY=dummy_mock_stripe_secret_key_for_testing
        JWT_SIGNING_SALT=dummy_jwt_signing_salt_for_testing
        """
    )

    public static let legalContract = SampleFile(
        "master_services_agreement_executed.txt",
        """
        MASTER SERVICES AGREEMENT & MUTUAL NONDISCLOSURE
        Between: Apex Cloud Consulting LLC ("Provider")
        And:     Acme Corporation ("Client")
        Effective Date: January 1, 2026

        1. CONFIDENTIALITY & PROPRIETARY INFORMATION
        Each party agrees to hold the other's Proprietary Information in strict confidence.
        Neither party will disclose Proprietary Information to third parties without prior
        written consent.

        2. INTELLECTUAL PROPERTY RIGHTS
        All Deliverables created by Provider specifically for Client shall be deemed
        "Work Made for Hire" and the exclusive property of Client upon full payment of fees.

        3. INDEMNIFICATION & GOVERNING LAW
        This Agreement is governed by the laws of the State of California.
        Signed: Jane Doe (Acme Corp CEO), John Smith (Apex Cloud Managing Partner).
        """
    )

    public static let swiftSourceCode = SampleFile(
        "TokenAuthMiddleware.swift",
        """
        import Foundation
        import FoundationModels

        /// An actor-isolated middleware enforcing bearer token authentication
        /// conforming to Swift 6 strict concurrency guarantees.
        public actor TokenAuthMiddleware {
            private let tokenValidator: @Sendable (String) async throws -> Bool
            private var failureCountByIP: [String: Int] = [:]

            public init(validator: @escaping @Sendable (String) async throws -> Bool) {
                self.tokenValidator = validator
            }

            public func authenticate(header: String?, clientIP: String) async throws -> Bool {
                guard let header = header, header.hasPrefix("Bearer ") else {
                    failureCountByIP[clientIP, default: 0] += 1
                    return false
                }
                let token = String(header.dropFirst(7))
                return try await tokenValidator(token)
            }
        }
        """
    )

    public static let technicalDocs = SampleFile(
        "system_architecture_overview.md",
        """
        # System Architecture: Jev Foundation Models Subsystem

        ## 1. Overview
        This document details the architectural boundaries between Apple Foundation Models
        and TypeSafe AI's Jev System One decision service.

        ## 2. Component Diagram
        - `LanguageModelSession`: Apple-native coordinator handling user sessions & dynamic profiles.
        - `JevLanguageModel`: Conforms to `LanguageModel` with `.guidedGeneration` capability.
        - `JevExecutor`: Bridges `LanguageModelExecutorGenerationRequest` to Jev JSON API.
        - `SchemaTranslator`: Maps `@Generable` structs and enums to `noul`, `choice`, and `score`.

        ## 3. SLA & Latency Guarantees
        P99 inference latency target is under 120ms with calibrated probabilities.
        """
    )

    public static let personalNotes = SampleFile(
        "weekend_chores_and_groceries.txt",
        """
        Weekend To-Do & Grocery List:
        - Whole Foods: Organic oat milk, avocados, dark roast coffee beans, sourdough loaf.
        - Home Depot: 2-inch wood screws, sandpaper (220 grit), exterior primer.
        - Pick up dry cleaning before 5 PM Saturday.
        - Prune tomato plants in backyard garden.
        - Book dentist appointment for Tuesday morning.
        """
    )

    public static let ambiguousScratchpad = SampleFile(
        "scratchpad_fragment.tmp",
        """
        temp test 1234
        random snippet:
        asdf qwerty 42
        maybe look into this later? or delete?
        unsure what this was for
        """
    )

    public static let allFiles: [SampleFile] = [
        invoice,
        credentialsEnv,
        legalContract,
        swiftSourceCode,
        technicalDocs,
        personalNotes,
        ambiguousScratchpad
    ]

    /// Populates a target directory with the sample files.
    public static func populateSandbox(at directoryURL: URL) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        for file in allFiles {
            let fileURL = directoryURL.appendingPathComponent(file.relativePath)
            try file.content.write(to: fileURL, atomically: true, encoding: .utf8)
        }
    }
}

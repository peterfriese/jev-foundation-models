# Mobile Application Blueprints for Jev & Apple Foundation Models

This document specifies high-impact mobile application concepts designed around **TypeSafe AI's Jev** System One decision model integrated natively via Apple's **Foundation Models** framework.

Each blueprint leverages Jev's distinct architectural strengths—**sub-100ms latency**, **calibrated probabilities**, and **bounded `@Generable` Swift types**—to deliver mobile experiences that are impossible with traditional generative LLMs or brittle regex rules.

---

## 🏛️ The Mobile Architectural Paradigm

### Why Jev Changes Mobile AI

| Dimension | Generative LLMs (GPT-4o, Claude, On-Device 3B) | Jev System One (`LanguageModelSession`) |
| :--- | :--- | :--- |
| **Response Latency** | 1,500ms – 4,000ms (token streaming) | **40ms – 120ms** (single feed-forward pass) |
| **Mobile Interaction** | Modals, loading spinners, chat interfaces | **Live typing loops**, camera viewfinders, background tasks |
| **Output Guarantees** | Free-form text; requires parsing & repair | **100% typed `@Generable` Swift structs/enums** |
| **Energy & Thermals** | Heavy CPU/NPU load; drains battery | Negligible client footprint; lightweight payload |
| **Certainty Signal** | Opaque or hallucinated confidence | **Calibrated probabilities ($0.0 - 1.0$)** |

### The Three-Tier Mobile UX Pattern

Because Jev provides calibrated probabilities (`noul`) and confidence scores (`choice`/`score`) via `response.metadata`, mobile interfaces should implement a three-tier interaction model:

```
┌──────────────────────────────────────────────────────────────┐
│  Probability / Confidence >= 0.85: Auto-Execute              │
│  Zero user taps. Perform action with subtle haptic tap.      │
├──────────────────────────────────────────────────────────────┤
│  Probability / Confidence 0.50 – 0.84: Interactive Suggest   │
│  Surface a single-tap SwiftUI suggestion chip / preview pill.│
├──────────────────────────────────────────────────────────────┤
│  Probability / Confidence < 0.50: Silent Fallback            │
│  Keep standard manual UI; never interrupt the user.          │
└──────────────────────────────────────────────────────────────┘
```

---

## 📋 Catalog of Blueprints

1. [Zero-Tap Expense & Document Scanner](#1-zero-tap-expense--document-scanner)
2. [Real-Time Typing Diplomacy & Tone Co-Pilot](#2-real-time-typing-diplomacy--tone-co-pilot)
3. [Nutrition Label & Dietary Safety Scanner](#3-nutrition-label--dietary-safety-scanner)
4. ["Magic Paste" Clipboard Action Predictor](#4-magic-paste-clipboard-action-predictor)
5. [Real-Time Notification Interceptor & Focus Radar](#5-real-time-notification-interceptor--focus-radar)
6. [Adaptive Daily Training & Recovery Dial](#6-adaptive-daily-training--recovery-dial)

---

## 1. Zero-Tap Expense & Document Scanner

### 📱 Concept & UX Flow
The user points their iPhone camera at a receipt, invoice, or packing slip. As VisionKit extracts OCR text, Jev categorizes the purchase, flags tax deductibility, checks corporate policy tier, and flags personal items in **under 80ms**. 

Before the shutter animation completes, the viewfinder presents a contextual card:
> *"Meals & Entertainment ($42.50) • Auto-filed to Trip: WWDC 2026"*

### 🧠 Foundation Models `@Generable` Schema
```swift
import FoundationModels

@Generable
public struct ExpenseScanDecision: Sendable {
    @Guide(description: "Primary business expense category based on vendor and itemized lines")
    public var category: ExpenseCategory

    @Guide(description: "Is this purchase eligible as an ordinary and necessary business tax deduction?")
    public var isTaxDeductible: Bool

    @Guide(description: "Approval urgency and expense tier", .range(0...2))
    public var expenseTier: Int // 0: under petty cash threshold (<$25), 1: standard itemized receipt, 2: flag for manager review

    @Guide(description: "Does the receipt include alcohol, personal items, or non-reimbursable gratuity?")
    public var hasFlaggedItems: Bool
}

@Generable
public enum ExpenseCategory: String, Sendable {
    case mealsAndEntertainment
    case travelAndLodging
    case transportationAndTransit
    case softwareAndSaaS
    case officeSupplies
    case personalNonReimbursable
}
```

### 📥 Sample Evaluation State
```text
Vendor: Blue Bottle Coffee #104, San Francisco CA
Date: 2026-09-22 08:42 AM
Items:
1x Pour Over (Hayes Valley) - $5.50
1x Avocado Toast - $12.00
1x Sparkling Water - $3.50
Subtotal: $21.00
Tax: $1.84
Tip: $4.00
Total: $26.84
Payment: Apple Pay (Visa ending 4129)
```

### ⚡ Why Jev is Superior
- **vs. Regex / Rules**: Rules cannot differentiate between buying coffee for a client (deductible meal) vs. buying groceries or gift cards at a cafe.
- **vs. Generative LLMs**: LLMs take 2–4 seconds to stream JSON, forcing an artificial loading spinner on camera capture. Jev completes in ~60ms.
- **vs. CoreML**: Training a custom classification model requires thousands of labeled receipts and cannot easily adapt to new corporate policy rules.

---

## 2. Real-Time Typing Diplomacy & Tone Co-Pilot

### 📱 Concept & UX Flow
Integrated into an iOS Keyboard Extension or in-app compose bar (Slack, Mail, Teams). On a **200–250ms typing pause**, Jev evaluates the thread history and draft text in **~50ms**. 

Rather than generating intrusive text rewrites, an ambient status indicator smoothly transitions color (emerald $\to$ warm amber $\to$ alert coral). Tapping the indicator reveals an actionable insight:
> *"This reads as defensive or abrupt (78% confidence). Consider clarifying the next step."*

### 🧠 Foundation Models `@Generable` Schema
```swift
import FoundationModels

@Generable
public struct ToneAnalysisDecision: Sendable {
    @Guide(description: "Emotional escalation and interpersonal tension rubric", .range(0...3))
    public var tensionLevel: Int // 0: collaborative/warm, 1: direct/terse, 2: defensive/passive-aggressive, 3: confrontational

    @Guide(description: "Primary communicative intent detected in the draft")
    public var intent: MessageIntent

    @Guide(description: "Does the message leave expectations ambiguous or omit an explicit next step?")
    public var hasAmbiguousNextStep: Bool

    @Guide(description: "Is this message appropriate for formal corporate or external client communication?")
    public var isProfessional: Bool
}

@Generable
public enum MessageIntent: String, Sendable {
    case clarificationRequest
    case boundarySetting
    case statusUpdate
    case constructiveFeedback
    case apology
    case casualChatter
}
```

### 📥 Sample Evaluation State
```text
Thread Context:
Client: "We were expecting the updated build yesterday at 5 PM. What happened?"
Draft Response:
"As per my previous email, the API credentials you provided were invalid so we couldn't run the build. We need working keys."
```

### ⚡ Why Jev is Superior
- **vs. Generative LLMs ("Rewrite with AI")**: Destroys personal tone, outputs verbose corporate platitudes, and introduces high typing lag.
- **vs. Sentiment Sentiment Analysis (NLTK / VADER)**: Classical sentiment only measures "positive vs. negative" words. It completely fails on subtle professional passive-aggression like *"As per my previous email"*.
- **Jev Superpower**: Evaluates tension as an ordinal rubric (`score` 0...3) with calibrated probability in under 60ms during live typing.

---

## 3. Nutrition Label & Dietary Safety Scanner

### 📱 Concept & UX Flow
A two-layer grocery scanning system:
1. **Layer 1 (Deterministic)**: Scans UPC/EAN barcode via AVFoundation in 5ms. If found in database, passes ingredient list to Jev.
2. **Layer 2 (VisionKit Fallback)**: If barcode is unlisted or absent (fresh bakery, import goods), camera OCR extracts ingredient blocks in 15ms and hands text to Jev.

Jev evaluates the label in **50ms** against the user's specific dietary profile (e.g., Strict Celiac / Gluten-Free, Diabetic, Low Sodium). The screen flashes green or red with an instant explanation:
> *"⚠️ Contains Barley Malt Extract (Hidden Gluten, 94% prob) • NOVA Tier 3 (Ultra-Processed)"*

### 🧠 Foundation Models `@Generable` Schema
```swift
import FoundationModels

@Generable
public struct DietarySafetyDecision: Sendable {
    @Guide(description: "Is this product strictly safe according to the user's dietary restriction profile?")
    public var isSafe: Bool

    @Guide(description: "Allergen exposure and contamination risk rubric", .range(0...3))
    public var allergenRisk: Int // 0: certified clear, 1: shared facility/traces, 2: contains derived aliases, 3: explicit allergen

    @Guide(description: "Ultra-processed food index according to the international NOVA classification", .range(0...3))
    public var processingTier: Int // 0: unprocessed whole food, 1: minimally processed culinary, 2: processed, 3: ultra-processed

    @Guide(description: "Primary dietary conflict or warning flag detected")
    public var primaryFlag: DietaryFlag
}

@Generable
public enum DietaryFlag: String, Sendable {
    case none
    case hiddenGluten
    case dairyOrLactose
    case seedOils
    case highAddedSugar
    case artificialSweeteners
    case excessiveSodium
    case animalDerivatives
}
```

### 📥 Sample Evaluation State
```text
User Profile: Strict Celiac (Gluten-Free), Low Added Sugar
Product: Nature Valley Crunchy Granola Bar - Oats 'n Honey
Ingredients:
Whole Grain Oats, Sugar, Canola Oil, Rice Flour, Honey, Brown Sugar Syrup, Salt, 
Barley Malt Extract, Baking Soda, Soy Lecithin.
Nutrition per 2 bars (42g):
Calories: 190, Total Fat: 7g, Sodium: 140mg, Total Carb: 29g, Added Sugars: 11g, Protein: 3g.
```

### ⚡ Why Jev is Superior
- **vs. Keyword Matching**: Misses ingredient aliases (e.g. barley malt, triticale, farro, kamut, modified food starch, spelt).
- **vs. Multimodal LLMs**: LLMs misread dense tabular numbers (e.g. swapping Total Sugars with Added Sugars) and take 3 seconds. Jev + Apple Vision OCR provides sub-100ms verification with zero numerical hallucination.

---

## 4. "Magic Paste" Clipboard Action Predictor

### 📱 Concept & UX Flow
When the user launches the app, taps the iPhone **Action Button**, or engages an interactive Lock Screen widget, the app inspects `UIPasteboard.general.string`. In **45ms**, Jev determines user intent and surfaces an immediate Action Banner:
- Copied flight text $\to$ **`[Add to Calendar]`** / **`[Track Flight]`**
- Copied address $\to$ **`[Navigate via Apple Maps]`**
- Copied bill or payment request $\to$ **`[Send via Venmo]`**
- Copied secret/token $\to$ Silently purges clipboard with a security toast.

### 🧠 Foundation Models `@Generable` Schema
```swift
import FoundationModels

@Generable
public struct ClipboardIntentDecision: Sendable {
    @Guide(description: "Recommended immediate operating system action to trigger")
    public var recommendedAction: ClipboardAction

    @Guide(description: "Time sensitivity and execution urgency rubric", .range(0...2))
    public var urgency: Int // 0: passive reference/note, 1: timely reference, 2: immediate action requested

    @Guide(description: "Is this snippet sensitive security data (password, 2FA code, API token, private key)?")
    public var isSensitiveData: Bool
}

@Generable
public enum ClipboardAction: String, Sendable {
    case createCalendarEvent
    case openNavigationMap
    case trackShipmentOrFlight
    case initiatePayment
    case saveBookmark
    case plainNote
}
```

### 📥 Sample Evaluation State
```text
Hey! Dinner reservation confirmed at Kokkari Estiatorio (200 Jackson St) for 4 people this Friday at 7:30 PM. Can someone grab an Uber?
```

### ⚡ Why Jev is Superior
- **vs. `NSDataDetector`**: Apple's native detector finds isolated dates or addresses, but cannot synthesize intent (e.g. recognizing that this is a dinner plan requiring calendar entry + navigation).
- **vs. Generative LLMs**: The Action Button requires instant physical tactile feedback. A 2-second LLM delay destroys the UX.
- **Jev Superpower**: Delivers the action in 45ms, enabling direct invocation of Apple App Intents.

---

## 5. Real-Time Notification Interceptor & Focus Radar

### 📱 Concept & UX Flow
Operates inside an iOS `UNNotificationServiceExtension`. When a push notification arrives from customer support, Slack, or smart home cameras, Jev evaluates the payload in **50ms** before the screen turns on.

High-priority alerts break through Focus modes; promotional messages are routed to the Scheduled Summary.

### 🧠 Foundation Models `@Generable` Schema
```swift
import FoundationModels

@Generable
public struct NotificationTriageDecision: Sendable {
    @Guide(description: "Interruption priority rubric", .range(0...2))
    public var priority: Int // 0: promotional/idle, 1: routine informational, 2: critical/time-sensitive

    @Guide(description: "Target delivery policy for the notification")
    public var delivery: DeliveryPolicy

    @Guide(description: "Is this alert a 2FA authentication code, fraud alert, or account security challenge?")
    public var isSecurityAlert: Bool
}

@Generable
public enum DeliveryPolicy: String, Sendable {
    case breakthroughFocus
    case deliverQuietly
    case batchToScheduledSummary
    case suppressNotification
}
```

### 📥 Sample Evaluation State
```text
App: PagerDuty / OpsGenie
Sender: AlertManager
Body: "CRITICAL: Database primary node in us-east-1 memory threshold > 95% for 5 consecutive minutes. P99 latency degraded to 4200ms."
User Context: Focus Mode = Sleep, Time = 03:15 AM
```

### ⚡ Why Jev is Superior
- **iOS Execution Limit**: `UNNotificationServiceExtension` has a strict ~30s execution ceiling, but user perception demands <150ms before sound/vibration trigger. Jev executes in 50ms.
- **Calibrated Routing**: Uses calibrated `isSecurityAlert` and `priority` probabilities to safely elevate `UNNotificationInterruptionLevel.timeSensitive`.

---

## 6. Adaptive Daily Training & Recovery Dial

### 📱 Concept & UX Flow
Runs via `BGAppRefreshTask` at 6:00 AM or upon wrist-raise on Apple Watch. Reads overnight HealthKit biometric trends (HRV deviation, resting heart rate delta, sleep debt, respiratory rate). Jev computes an objective training stimulus in **60ms** and pushes it to Lock Screen widgets and Apple Watch complications before the user gets out of bed.

### 🧠 Foundation Models `@Generable` Schema
```swift
import FoundationModels

@Generable
public struct DailyRecoveryDecision: Sendable {
    @Guide(description: "Physiological readiness and autonomic recovery rubric", .range(0...3))
    public var readinessTier: Int // 0: acute strain/illness recovery, 1: under-recovered, 2: baseline ready, 3: primed for peak effort

    @Guide(description: "Recommended exercise stimulus for today")
    public var recommendedStimulus: TrainingStimulus

    @Guide(description: "Do biometric trends indicate potential onset of illness, infection, or severe systemic fatigue?")
    public var flagsSystemicStrain: Bool
}

@Generable
public enum TrainingStimulus: String, Sendable {
    case completeRest
    case gentleMobilityAndWalk
    case zone2AerobicBase
    case tempoIntervals
    case heavyStrengthTraining
}
```

### 📥 Sample Evaluation State
```text
Biometric Trends (Past 24h vs. 30-day baseline):
- Sleep Duration: 5h 15m (Baseline: 7h 45m, Deficit: -2h 30m)
- Deep Sleep: 22m (Normal: 65m)
- Resting Heart Rate: 58 bpm (Baseline: 49 bpm, +9 bpm elevation)
- HRV (RMSSD): 32 ms (Baseline: 64 ms, -50% suppression)
- Yesterday Training Load: 18km long run (High exertion)
```

### ⚡ Why Jev is Superior
- **No Hallucinated Prose**: Wearables and widgets require clean enum cases (`.gentleMobilityAndWalk`), not 300 words of generic health advice.
- **Reliable Guardrails**: Calibrated `flagsSystemicStrain` probability reliably protects athletes from overtraining injuries and illness exacerbation.

---

## 🚀 Recommended Implementation Order

To continue expanding the sample suite in this repository:

1. **`magic-paste-demo` (Blueprint #4)**: Lowest complexity, highest instant visual payoff. Can be tested with a simple CLI or SwiftUI pasteboard observer.
2. **`dietary-scanner-demo` (Blueprint #3)**: Demonstrates the power of two-layer verification (deterministic barcode vs. semantic label evaluation) with rich real-world food data.
3. **`tone-radar-demo` (Blueprint #2)**: Demonstrates the live debounced evaluation loop with ordinal rubric scoring.

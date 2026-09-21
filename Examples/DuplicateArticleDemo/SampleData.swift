import Foundation

/// Real-world sample articles matching the scenarios discussed in the blog post:
/// "Detecting Duplicate Articles with Jev — or: How I Finally Stopped Saving the Same Article Twice"
public enum SampleData {

    // MARK: - Scenario 1 Articles (Deterministic Duplicate)

    public static let blogPostOriginal = Article(
        id: "art-peter-blog",
        title: "Agentic Coding with Xcode and Gemini CLI",
        byline: "Peter Friese",
        url: URL(string: "https://peterfriese.dev/blog/2026/agentic-coding-xcode-geminicli")!,
        excerpt: "Autonomous coding agents are moving into production workflows. Here is how Gemini CLI pairs with Xcode for automated builds and testing."
    )

    public static let xArticleSyndication = Article(
        id: "art-peter-x",
        title: "Agentic Coding with Xcode and Gemini CLI",
        byline: "Peter Friese",
        url: URL(string: "https://x.com/peterfriese/status/2021555930412847567?utm_source=twitter&ref=share")!,
        excerpt: "Autonomous coding agents are moving into production workflows. Here is how Gemini CLI pairs with Xcode for automated builds and testing."
    )

    // MARK: - Scenario 2 Articles (Semantic Duplicate / Rewritten Wire Story)

    public static let apNewsOriginal = Article(
        id: "art-ap-wire",
        title: "Apple unveils iPhone Duo, its foldable smartphone",
        byline: "Barbara Ortutay",
        url: URL(string: "https://apnews.com/article/apple-foldable-iphone-ternus-fd35312e6d894d5f3b055b3d62f22cd2")!,
        excerpt: "Apple on Wednesday unveiled its latest generation of iPhones, including a widely anticipated foldable version called Duo. The company announced the device at its annual hardware event in Cupertino."
    )

    public static let kcbdLocalSyndication = Article(
        id: "art-kcbd-syndicated",
        title: "New iPhone lineup includes a foldable version called Duo",
        byline: "The Associated Press and Barbara Ortutay",
        url: URL(string: "https://www.kcbd.com/2026/09/10/new-iphone-lineup-includes-a-foldable-version-called-duo")!,
        excerpt: "Apple on Wednesday unveiled its latest generation of iPhones, including a widely anticipated foldable version called Duo. The company announced the device at its annual hardware event in Cupertino."
    )

    // MARK: - Scenario 3 Articles (Distinct Content / Same Topic - False Positive Control)

    public static let googlePixelFoldArticle = Article(
        id: "art-verge-pixel",
        title: "Google announces Pixel Fold 3 with Gemini Nano",
        byline: "David Pierce",
        url: URL(string: "https://theverge.com/2026/09/12/pixel-fold-3")!,
        excerpt: "Google announced its third-generation foldable phone today at its Made by Google event in Mountain View, featuring on-device Gemini Nano multimodal intelligence."
    )
}

import Foundation

enum OnboardingStrings {
    static let pageOneTitle = localized(
        "onboarding.page1.title",
        fallback: "Welcome to Yal.ai"
    )
    static let pageOneDescription = localized(
        "onboarding.page1.description",
        fallback: "Your chat, your rules.\nWe help stop fraud before it even begins."
    )

    static let pageTwoTitle = localized(
        "onboarding.page2.title",
        fallback: "Private. Protected. Peaceful."
    )
    static let pageTwoDescription = localized(
        "onboarding.page2.description",
        fallback: "No spam. No scams.\nJust secure, seamless conversations you control."
    )

    static let pageThreeTitle = localized(
        "onboarding.page3.title",
        fallback: "Stay a step ahead."
    )
    static let pageThreeDescription = localized(
        "onboarding.page3.description",
        fallback: "We send real-time alerts so you're never caught off guard."
    )

    static let nextButton = localized(
        "onboarding.button.next",
        fallback: "Next"
    )
    static let startMessagingButton = localized(
        "onboarding.button.startMessaging",
        fallback: "Start messaging"
    )

    private static func localized(_ key: String, fallback: String) -> String {
        NSLocalizedString(key, value: fallback, comment: "")
    }
}

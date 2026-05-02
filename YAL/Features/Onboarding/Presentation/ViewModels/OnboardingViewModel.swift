import Foundation

private enum OnboardingAsset: String {
    case welcomeGif = "onboardOne"
    case privacyGif = "onboardTwo"
    case alertsGif = "onboardThree"
}

struct OnboardingSlide: Identifiable {
    let id: Int
    let imageName: String
    let title: String
    let description: String

    var gifURL: URL? {
        Bundle.main.url(forResource: imageName, withExtension: "gif")
    }
}

final class OnboardingFlowViewModel: ObservableObject {
    @Published var currentPageIndex: Int = 0

    let slides: [OnboardingSlide] = [
        OnboardingSlide(
            id: 0,
            imageName: OnboardingAsset.welcomeGif.rawValue,
            title: OnboardingStrings.pageOneTitle,
            description: OnboardingStrings.pageOneDescription
        ),
        OnboardingSlide(
            id: 1,
            imageName: OnboardingAsset.privacyGif.rawValue,
            title: OnboardingStrings.pageTwoTitle,
            description: OnboardingStrings.pageTwoDescription
        ),
        OnboardingSlide(
            id: 2,
            imageName: OnboardingAsset.alertsGif.rawValue,
            title: OnboardingStrings.pageThreeTitle,
            description: OnboardingStrings.pageThreeDescription
        )
    ]

    var isOnLastSlide: Bool {
        currentPageIndex == slides.count - 1
    }

    var primaryButtonTitle: String {
        isOnLastSlide ? OnboardingStrings.startMessagingButton : OnboardingStrings.nextButton
    }

    func advanceToNextSlide() {
        guard currentPageIndex < slides.count - 1 else { return }
        currentPageIndex += 1
    }
}

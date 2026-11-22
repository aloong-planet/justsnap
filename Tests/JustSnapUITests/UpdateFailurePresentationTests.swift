import Foundation
import Testing
import JustSnapCore
@testable import JustSnapUI

@Suite("Update failure presentation")
struct UpdateFailurePresentationTests {
    @Test("the failure row names a failed update and shows the updater's own message")
    func messageIsShown() {
        LocalizationTestCoordinator.withExclusiveAccess {
            JustSnapLocalization.configure(effectiveLanguage: .english)
            #expect(JustSnapStrings.updateFailedTitle == "Update Failed")
            #expect(
                JustSnapStrings.updateFailedDetail(message: "Failed to gain authorization required to update target")
                    == "Failed to gain authorization required to update target"
            )
        }
    }

    @Test("a failure without a message, or with a blank one, shows the generic line", arguments: [nil, "", "  \n"])
    func missingMessageFallsBack(message: String?) {
        LocalizationTestCoordinator.withExclusiveAccess {
            JustSnapLocalization.configure(effectiveLanguage: .english)
            #expect(JustSnapStrings.updateFailedDetail(message: message) == "The update did not complete. Try again.")
            JustSnapLocalization.configure(effectiveLanguage: .simplifiedChinese)
            #expect(JustSnapStrings.updateFailedDetail(message: message) == "更新未能完成，请重试。")
        }
    }
}

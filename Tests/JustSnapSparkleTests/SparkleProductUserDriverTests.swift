import Sparkle
import Testing
import JustSnapCore
@testable import JustSnapSparkle

@Suite("Sparkle product user driver")
@MainActor
struct SparkleProductUserDriverTests {
    @Test("download reply is consumed exactly once")
    func downloadReplyIsOneShot() throws {
        let replies = ReplyProbe()
        let version = AvailableUpdateVersion(version: "1.1.0", displayVersion: "1.1.0")
        let driver = SparkleProductUserDriver(eventHandler: { _ in })
        driver.registerFoundUpdate(version: version, informationURL: nil) {
            replies.record($0)
        }

        try driver.beginDownload()
        #expect(throws: SparkleUpdateDriverError.noDownloadAvailable) {
            try driver.beginDownload()
        }
        #expect(replies.choices == [.install])
    }

    @Test("information-only update cannot enter the download path")
    func informationOnlyUpdateCannotDownload() {
        let version = AvailableUpdateVersion(version: "2.0.0", displayVersion: "2.0")
        let driver = SparkleProductUserDriver(eventHandler: { _ in })
        driver.registerFoundUpdate(
            version: version,
            informationURL: URL(string: "https://example.com/update")
        ) { _ in }

        #expect(throws: SparkleUpdateDriverError.informationOnlyUpdate) {
            try driver.beginDownload()
        }
    }

    @Test("Sparkle callbacks reach Core in callback order")
    func callbackOrderIsPreserved() async {
        let events = EventProbe()
        let version = AvailableUpdateVersion(version: "1.1.0", displayVersion: "1.1.0")
        let driver = SparkleProductUserDriver(eventHandler: { event in
            await events.record(event)
        })
        driver.registerFoundUpdate(version: version, informationURL: nil) { _ in }
        driver.showDownloadInitiated(cancellation: {})
        driver.showDownloadDidReceiveExpectedContentLength(1_000)
        driver.showDownloadDidReceiveData(ofLength: 250)
        driver.showReady(toInstallAndRelaunch: { _ in })

        await driver.waitForPendingEvents()

        #expect(
            await events.values == [
                .available(version),
                .downloadStarted(version),
                .downloadExpectedBytes(1_000),
                .downloadedBytes(250),
                .readyToInstall(version),
            ]
        )
    }

    @Test("an updater error reaches Core with its own description and reason")
    func updaterErrorCarriesItsText() async {
        let events = EventProbe()
        let driver = SparkleProductUserDriver(eventHandler: { event in
            await events.record(event)
        })
        let error = NSError(
            domain: "TestDomain",
            code: 7,
            userInfo: [
                NSLocalizedDescriptionKey: "Failed to gain authorization required to update target",
                NSLocalizedFailureReasonErrorKey: "The installer was refused.",
            ]
        )
        let acknowledgements = CountProbe()

        driver.showUpdaterError(error, acknowledgement: { acknowledgements.record() })
        await driver.waitForPendingEvents()

        #expect(
            await events.values == [
                .failed(
                    .check,
                    code: "updater_failed",
                    message: "Failed to gain authorization required to update target\nThe installer was refused."
                ),
            ]
        )
        #expect(acknowledgements.count == 1)
    }

    @Test("an updater error whose reason repeats its description shows it once")
    func updaterErrorWithRepeatedReason() {
        let error = NSError(
            domain: "TestDomain",
            code: 9,
            userInfo: [
                NSLocalizedDescriptionKey: "The update could not be installed.",
                NSLocalizedFailureReasonErrorKey: "The update could not be installed.",
            ]
        )

        #expect(SparkleProductUserDriver.message(for: error) == "The update could not be installed.")
    }

    @Test("an updater error without a separate reason shows its description once")
    func updaterErrorWithoutReason() async {
        let events = EventProbe()
        let driver = SparkleProductUserDriver(eventHandler: { event in
            await events.record(event)
        })
        let error = NSError(
            domain: "TestDomain",
            code: 8,
            userInfo: [NSLocalizedDescriptionKey: "An error occurred while downloading the update."]
        )

        driver.showUpdaterError(error, acknowledgement: {})
        await driver.waitForPendingEvents()

        #expect(
            await events.values == [
                .failed(.check, code: "updater_failed", message: "An error occurred while downloading the update."),
            ]
        )
    }
}

@MainActor
private final class ReplyProbe {
    private(set) var choices: [SPUUserUpdateChoice] = []

    func record(_ choice: SPUUserUpdateChoice) {
        choices.append(choice)
    }
}

private actor EventProbe {
    private(set) var values: [UpdateLifecycleEvent] = []

    func record(_ event: UpdateLifecycleEvent) {
        values.append(event)
    }
}

@MainActor
private final class CountProbe {
    private(set) var count = 0

    func record() {
        count += 1
    }
}

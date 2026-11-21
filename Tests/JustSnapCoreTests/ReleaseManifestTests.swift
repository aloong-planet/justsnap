import Foundation
import Testing
@testable import JustSnapCore

@Suite("Release manifest")
struct ReleaseManifestTests {
    @Test("A release manifest with the single Apple silicon artifact is accepted")
    func singleArm64ManifestIsAccepted() throws {
        try validManifest().validateForFormalRelease()
    }

    @Test("A formal release rejects an insecure feed")
    func insecureFeedIsRejected() throws {
        let manifest = validManifest(
            artifacts: [
                DistributionArtifact(
                    architecture: .arm64,
                    feedURL: URL(string: "http://downloads.aloongplanet.com/appcast-arm64.xml")!,
                    dmgFileName: "JustSnap-1.0.0-mac-arm64.dmg"
                ),
            ]
        )

        #expect(throws: ReleaseManifestError.insecureFeed(.arm64)) {
            try manifest.validateForFormalRelease()
        }
    }

    @Test("A formal release rejects an artifact name from another architecture")
    func otherArchitectureArtifactNameIsRejected() throws {
        let manifest = validManifest(
            artifacts: [
                DistributionArtifact(
                    architecture: .arm64,
                    feedURL: URL(string: "https://downloads.aloongplanet.com/justsnap/appcast-arm64.xml")!,
                    dmgFileName: "JustSnap-1.0.0-mac-x64.dmg"
                ),
            ]
        )

        #expect(throws: ReleaseManifestError.invalidArtifactName(.arm64)) {
            try manifest.validateForFormalRelease()
        }
    }

    @Test("A formal release rejects anything but exactly one artifact")
    func artifactCountOtherThanOneIsRejected() throws {
        let artifact = validManifest().artifacts[0]
        let none = validManifest(artifacts: [])
        let twice = validManifest(artifacts: [artifact, artifact])

        #expect(throws: ReleaseManifestError.incompleteArchitectureSet) {
            try none.validateForFormalRelease()
        }
        #expect(throws: ReleaseManifestError.incompleteArchitectureSet) {
            try twice.validateForFormalRelease()
        }
    }

    @Test("A formal release rejects a malformed Sparkle public key")
    func malformedSparklePublicKeyIsRejected() throws {
        let valid = validManifest()
        let manifest = ReleaseManifest(
            version: valid.version,
            buildVersion: valid.buildVersion,
            bundleIdentifier: valid.bundleIdentifier,
            sparklePublicKey: "placeholder",
            artifacts: valid.artifacts
        )

        #expect(throws: ReleaseManifestError.invalidSparklePublicKey) {
            try manifest.validateForFormalRelease()
        }
    }

    private func validManifest(artifacts: [DistributionArtifact]? = nil) -> ReleaseManifest {
        ReleaseManifest(
            version: "1.0.0",
            buildVersion: "100",
            bundleIdentifier: "com.loong.justsnap",
            sparklePublicKey: Data(repeating: 7, count: 32).base64EncodedString(),
            artifacts: artifacts ?? [
                DistributionArtifact(
                    architecture: .arm64,
                    feedURL: URL(string: "https://downloads.aloongplanet.com/justsnap/appcast-arm64.xml")!,
                    dmgFileName: "JustSnap-1.0.0-mac-arm64.dmg"
                ),
            ]
        )
    }
}

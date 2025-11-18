import XCTest
@testable import StreakSync

final class BetaFeatureFlagsTests: XCTestCase {

    func testDefaultStateIsMinimal() {
        let flags = BetaFeatureFlags()
        XCTAssertTrue(flags.isMinimalBeta, "Default flags should represent minimal beta experience.")
        XCTAssertFalse(flags.multipleCircles)
        XCTAssertFalse(flags.reactions)
        XCTAssertFalse(flags.activityFeed)
    }

    func testEnableForInternalTestingTogglesFlags() {
        let flags = BetaFeatureFlags()
        flags.enableForInternalTesting()
        XCTAssertTrue(flags.multipleCircles)
        XCTAssertTrue(flags.reactions)
        XCTAssertTrue(flags.activityFeed)
        XCTAssertTrue(flags.contactDiscovery)
        XCTAssertTrue(flags.rankDeltas)
        XCTAssertFalse(flags.isMinimalBeta)
    }
}


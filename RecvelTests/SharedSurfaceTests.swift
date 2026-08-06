import XCTest
@testable import Recvel

final class SharedSurfaceTests: XCTestCase {
    func testSharedSnapshotRoundTripPreservesDashboardValues() throws {
        let original = RecvelSharedSnapshot.preview
        let data = try XCTUnwrap(RecvelSharedSnapshotStore.encoded(original))
        let decoded = try XCTUnwrap(RecvelSharedSnapshotStore.decoded(data))

        XCTAssertEqual(decoded, original)
        XCTAssertEqual(decoded.version, RecvelSharedSnapshot.schemaVersion)
        XCTAssertEqual(decoded.recovery, 82)
        XCTAssertEqual(try XCTUnwrap(decoded.sleepHours), 7.7, accuracy: 0.001)
    }

    func testPlaceholderNeverInventsHealthValues() {
        let placeholder = RecvelSharedSnapshot.placeholder

        XCTAssertNil(placeholder.recovery)
        XCTAssertNil(placeholder.hrvMilliseconds)
        XCTAssertNil(placeholder.steps)
        XCTAssertEqual(placeholder.confidenceID, "common.low")
    }
}

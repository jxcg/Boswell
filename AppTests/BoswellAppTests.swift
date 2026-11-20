import BoswellCore
import SwiftUI
import XCTest
@testable import Boswell

final class BoswellAppTests: XCTestCase {
    func testConfidenceTintsMatchEvidenceKey() {
        XCTAssertEqual(Confidence.green.tint, .green)
        XCTAssertEqual(Confidence.yellow.tint, .yellow)
        XCTAssertEqual(Confidence.red.tint, .red)
    }
}

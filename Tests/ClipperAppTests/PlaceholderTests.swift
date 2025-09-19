import XCTest
@testable import ClipperApp

final class PlaceholderTests: XCTestCase {
    func testConfigurationDefaults() {
        let configuration = DownloadConfiguration.default
        XCTAssertFalse(configuration.shouldPromptForFormat)
        XCTAssertEqual(configuration.formatPreference, .best)
    }
}

import XCTest
@testable import sweTAK

final class AboutTests: XCTestCase {

    // MARK: - AboutScreenHelper Tests

    func testAboutScreenHelperDefaultValue() {
        // Clear any existing preference
        UserDefaults.standard.removeObject(forKey: "swetak_dont_show_about_at_startup")

        // By default, should show at startup
        XCTAssertTrue(AboutScreenHelper.shouldShowAtStartup)
    }

    func testAboutScreenHelperSetDontShowAtStartup() {
        // Set to don't show
        AboutScreenHelper.setDontShowAtStartup(true)
        XCTAssertFalse(AboutScreenHelper.shouldShowAtStartup)

        // Set back to show
        AboutScreenHelper.setDontShowAtStartup(false)
        XCTAssertTrue(AboutScreenHelper.shouldShowAtStartup)

        // Clean up
        UserDefaults.standard.removeObject(forKey: "swetak_dont_show_about_at_startup")
    }

    func testAboutScreenHelperPersistence() {
        // Set preference
        AboutScreenHelper.setDontShowAtStartup(true)

        // Verify it persists
        let storedValue = UserDefaults.standard.bool(forKey: "swetak_dont_show_about_at_startup")
        XCTAssertTrue(storedValue)

        // Clean up
        UserDefaults.standard.removeObject(forKey: "swetak_dont_show_about_at_startup")
    }
}

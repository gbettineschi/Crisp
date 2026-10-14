import Foundation
import XCTest

@MainActor
final class DefaultDisplaySetupTests: XCTestCase {
    private func setup() -> DefaultDisplaySetup {
        DefaultDisplaySetup(displays: [
            .init(uuid: "builtin", width: 1512, height: 982, isHiDPI: true,
                  x: 0, y: 0, isMain: true),
            .init(uuid: "dell", width: 2560, height: 1440, isHiDPI: true,
                  x: -2560, y: -200, isMain: false)
        ])
    }

    func testMatchesStableUUIDsRegardlessOfEnumerationOrder() {
        XCTAssertTrue(setup().matches(uuids: ["dell", "builtin"]))
    }

    func testDoesNotApplyAnOpenLidSetupWithTheBuiltInMissing() {
        XCTAssertFalse(setup().matches(uuids: ["dell"]))
    }

    func testDoesNotApplyToAnotherMonitorOrAnExtraMonitor() {
        XCTAssertFalse(setup().matches(uuids: ["builtin", "other"]))
        XCTAssertFalse(setup().matches(uuids: ["builtin", "dell", "other"]))
    }

    func testPreservesNegativeOriginsAndAboveNativeHiDPISize() throws {
        let encoded = try JSONEncoder().encode(setup())
        let decoded = try JSONDecoder().decode(DefaultDisplaySetup.self, from: encoded)
        XCTAssertEqual(decoded, setup())
        XCTAssertTrue(decoded.isValid)
    }

    func testRejectsDuplicateDisplayIdentities() {
        var value = setup()
        value.displays[1].uuid = "builtin"
        XCTAssertFalse(value.isValid)
    }

    func testRejectsEmptySetAndInvalidDimensions() {
        XCTAssertFalse(DefaultDisplaySetup(displays: []).isValid)
        var value = setup()
        value.displays[1].width = 0
        XCTAssertFalse(value.isValid)
    }

    func testRequiresExactlyOneMainDisplayAtOrigin() {
        var value = setup()
        value.displays[1].isMain = true
        XCTAssertFalse(value.isValid)
        value = setup()
        value.displays[0].x = 100
        XCTAssertFalse(value.isValid)
    }

    func testSaveSurvivesStoreRecreationAndCanBeReplacedWithFHD() throws {
        let suite = "crisp.default-setup-tests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        try DefaultDisplaySetupStore(defaults: defaults).save(setup())
        let recreated = DefaultDisplaySetupStore(defaults: defaults)
        XCTAssertEqual(recreated.load(), setup())
        var fhd = setup()
        fhd.displays[1].width = 1920
        fhd.displays[1].height = 1080
        fhd.displays[1].isHiDPI = false
        try recreated.save(fhd)
        XCTAssertEqual(DefaultDisplaySetupStore(defaults: defaults).load(), fhd)
    }

    func testClearStopsAutomaticRestorationWithoutChangingTheCapturedValue() throws {
        let suite = "crisp.default-setup-tests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = DefaultDisplaySetupStore(defaults: defaults)
        try store.save(setup())
        store.clear()
        XCTAssertNil(DefaultDisplaySetupStore(defaults: defaults).load())
    }

    func testCorruptPreferencesAreIgnored() throws {
        let suite = "crisp.default-setup-tests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(Data("broken JSON".utf8), forKey: DefaultDisplaySetupStore.key)
        XCTAssertNil(DefaultDisplaySetupStore(defaults: defaults).load())
    }

    func testInvalidDecodedSetupIsIgnored() throws {
        let suite = "crisp.default-setup-tests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        var invalid = setup()
        invalid.displays[1].uuid = "builtin"
        defaults.set(try JSONEncoder().encode(invalid), forKey: DefaultDisplaySetupStore.key)
        XCTAssertNil(DefaultDisplaySetupStore(defaults: defaults).load())
    }

    func testInvalidSaveDoesNotReplaceThePreviousDefault() throws {
        let suite = "crisp.default-setup-tests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = DefaultDisplaySetupStore(defaults: defaults)
        try store.save(setup())
        XCTAssertThrowsError(try store.save(DefaultDisplaySetup(displays: [])))
        XCTAssertEqual(store.load(), setup())
    }
}

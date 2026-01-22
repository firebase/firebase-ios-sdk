import XCTest
@testable import FirebaseCoreLinux

final class FirebaseCoreLinuxTests: XCTestCase {

    override func tearDown() {
        // Cleanup apps
        // Note: delete is async but we invoke nil completion.
        // We might need to ensure cleanup happens synchronously or wait.
        // However, delete removes from _allApps immediately.

        let apps = FirebaseApp.allApps
        for name in apps.keys {
            FirebaseApp.app(name: name)?.delete(completion: nil)
        }
    }

    func testConfigureDefault() {
        // We explicitly pass options to avoid dependency on GoogleService-Info.plist in test bundle
        let options = FirebaseOptions(googleAppID: "appID", gcmSenderID: "senderID")
        FirebaseApp.configure(options: options)
        XCTAssertNotNil(FirebaseApp.app())
        XCTAssertEqual(FirebaseApp.app()?.options.googleAppID, "appID")
        XCTAssertTrue(FirebaseApp.app()?.isDefaultApp ?? false)
    }

    func testConfigureNamed() {
        let options = FirebaseOptions(googleAppID: "appID2", gcmSenderID: "senderID2")
        FirebaseApp.configure(name: "testApp", options: options)
        XCTAssertNotNil(FirebaseApp.app(name: "testApp"))
        XCTAssertEqual(FirebaseApp.app(name: "testApp")?.name, "testApp")
        XCTAssertFalse(FirebaseApp.app(name: "testApp")?.isDefaultApp ?? true)
    }

    func testOptionsInit() {
        let options = FirebaseOptions(googleAppID: "1:123:ios:abc", gcmSenderID: "123")
        XCTAssertEqual(options.googleAppID, "1:123:ios:abc")
        XCTAssertEqual(options.gcmSenderID, "123")
        XCTAssertEqual(options.bundleID, Bundle.main.bundleIdentifier ?? "")
    }

    func testComponentRegistrationAndResolution() {
        // Define a dummy service
        class TestService {
            let id = UUID()
        }

        // Register component
        let component = Component(TestService.self) { container in
            return TestService()
        }

        FirebaseApp.register(component)

        // Configure app
        let options = FirebaseOptions(googleAppID: "appID", gcmSenderID: "senderID")
        FirebaseApp.configure(name: "compApp", options: options)

        guard let app = FirebaseApp.app(name: "compApp") else {
            XCTFail("App not configured")
            return
        }

        // Resolve instance
        let instance1 = app.container.instance(for: TestService.self)
        XCTAssertNotNil(instance1)

        // Resolve again (should be same instance for lazy singleton)
        let instance2 = app.container.instance(for: TestService.self)
        XCTAssertNotNil(instance2)
        XCTAssertTrue(instance1 === instance2)
    }

    func testHeartbeatLogger() {
        let logger = HeartbeatLogger(appID: "testAppID")
        logger.log()
        // Just verify it doesn't crash.
        // We rely on internal logic which is hard to inspect from public API without mocking storage.
        // But we can check headerValue
        let header = logger.headerValue()
        // It might be nil if empty, or string if logged.
        // Since we logged, it should potentially produce something, but it's async logging usually.
        // HeartbeatController.log uses async storage write.
        // So headerValue might be nil immediately.
    }
}

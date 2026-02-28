import XCTest
import Foundation
import FirebaseCore
@testable import GeneratedFirebaseAI
@testable import TestServer

class FirebaseE2ETestBase: XCTestCase {
    nonisolated(unsafe) static var testServer: TestServer?

    var client: APIClient!
    var projectID: String!
    var apiKey: String!

    private class func localBinPath() -> String {
        return FileManager.default.temporaryDirectory
            .appendingPathComponent("test-server-bin/test-server").path
    }

    override class func setUp() {
        super.setUp()

        let currentFileURL = URL(fileURLWithPath: #file)
        let sdkRoot = currentFileURL.deletingLastPathComponent().deletingLastPathComponent().path

        let options = TestServerOptions(
            configPath: "\(sdkRoot)/Tests/test-server.yml",
            recordingDir: "\(sdkRoot)/Tests/Recordings",
            mode: ProcessInfo.processInfo.environment["TEST_MODE"] ?? "replay",
            binaryPath: localBinPath(),
            testServerSecrets: nil
        )
        testServer = TestServer(options: options)
    }

    override class func tearDown() {
        testServer?.stop()
        testServer = nil
        super.tearDown()
    }


    override func setUp() async throws {
        try await super.setUp()

        try await Self.testServer?.start()

        // Configure naming for the recording file
        let rawName = self.name
        let cleanName = rawName.trimmingCharacters(in: CharacterSet(charactersIn: "-[]"))
            .replacingOccurrences(of: " ", with: ".")
        TestServerURLProtocol.currentTestName = cleanName

        // Setup Credentials
        self.projectID = ProcessInfo.processInfo.environment["GOOGLE_CLOUD_PROJECT"] ?? "test-project"
        self.apiKey = ProcessInfo.processInfo.environment["GOOGLE_API_KEY"] ?? "test-api-key"

        // Initialize Client
        let sessionConfig = URLSessionConfiguration.ephemeral
        sessionConfig.protocolClasses = [TestServerURLProtocol.self]
        let proxySession = URLSession(configuration: sessionConfig)

        let firebaseApp = FirebaseFake.create(apiKey: apiKey, projectID: projectID)
        self.client = APIClient(
            backend: .vertexAI(location: "us-central1", projectId: projectID, version: .v1beta),
            authentication: .firebase(app: firebaseApp),
            urlSession: proxySession
        )
    }
}

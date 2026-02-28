import XCTest
import Foundation
@testable import GeneratedFirebaseAI
@testable import TestServer

final class GenerateContentFirebaseTest: FirebaseE2ETestBase {

    func testGenerateContent() async throws {

        let models = Models(apiClient: client)

        let content = [Content(parts: [Part(text: "Hello from Firebase!")], role: "user")]
        let params = GenerateContentParameters(model: "gemini-2.5-flash", contents: content)

        let response = try await models.generateContentInternal(params: params)
        XCTAssertNotNil(response.candidates)
    }
}

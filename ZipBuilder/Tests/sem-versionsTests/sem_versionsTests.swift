import XCTest
@testable import sem_versions

final class sem_versionsTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(sem_versions().text, "Hello, World!")
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}

import XCTest

#if !canImport(ObjectiveC)
  public func allTests() -> [XCTestCaseEntry] {
    return [
      testCase(sem_versionsTests.allTests),
    ]
  }
#endif

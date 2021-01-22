import XCTest

#if !canImport(ObjectiveC)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(coverage_report_parserTests.allTests),
    ]
}
#endif

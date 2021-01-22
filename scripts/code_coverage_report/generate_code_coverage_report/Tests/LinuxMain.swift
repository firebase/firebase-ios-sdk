import XCTest

import CoverageReportParser

var tests = [XCTestCaseEntry]()
tests += CoverageReportParser.allTests()
XCTMain(tests)

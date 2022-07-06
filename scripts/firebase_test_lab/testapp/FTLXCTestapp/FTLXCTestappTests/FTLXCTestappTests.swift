//
//  FTLXCTestappTests.swift
//  FTLXCTestappTests
//
//  Created by Gran Luo on 7/6/22.
//

import XCTest
@testable import FTLXCTestapp

class FTLXCTestappTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() throws {
      XCTAssert(true)
    }

  func testFailedExample() throws {
    XCTAssert(false)
  }
    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
          sleep(5)
            // Put the code you want to measure the time of here.
        }
    }

}

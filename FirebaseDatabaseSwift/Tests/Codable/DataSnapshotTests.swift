//
//  File.swift
//  
//
//  Created by Morten Bek Ditlevsen on 04/05/2021.
//

import FirebaseDatabase
import FirebaseDatabaseSwift
import FirebaseDatabaseTestingSupport
import Foundation
import XCTest

class DataSnapshotTests: XCTestCase {
  struct Model: Codable, Equatable {
    var a: String
    var b: Int
  }

  func testGetValue() throws {

    let fake = DataSnapshotFake()
    fake.fakeValue = ["a": "hello", "b": 42]

    let expected = Model(a: "hello", b: 42)

    let actual = try fake.data(as: Model.self)

    XCTAssertEqual(actual, expected)
  }

  // Test that if we ask for an `Optional`, then it's
  // still ok to decode an actual value
  func testGetValueOptional() throws {

    let fake = DataSnapshotFake()
    fake.fakeValue = ["a": "hello", "b": 42]

    let expected = Model(a: "hello", b: 42)

    let actual = try fake.data(as: Model?.self)

    XCTAssertEqual(actual, expected)
  }

  // Test that if we ask for an `Optional`, then it's
  // ok to decode a `nil` value
  func testGetNonExistingValueOptional() throws {

    let fake = DataSnapshotFake()
    fake.fakeValue = nil

    let actual = try fake.data(as: Model?.self)

    XCTAssertNil(actual)
  }

  // Test that if we do NOT ask for an `Optional`, then it's
  // an error
  func testGetNonExistingValueFailure() throws {

    let fake = DataSnapshotFake()
    fake.fakeValue = nil

    do {
      _ = try fake.data(as: Model.self)
    } catch let error as DecodingError {
      switch error {
      case .valueNotFound(_, let context):
        XCTAssertEqual(context.debugDescription, "Cannot get keyed decoding container -- found null value instead.")
      default:
        XCTFail("Unexpected error")
      }
    } catch {
      XCTFail("Unexpected error")
    }
  }


}

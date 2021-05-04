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

class DatabaseReferenceTests: XCTestCase {
  struct Model: Codable, Equatable {
    var a: String
    var b: Int
  }

  func testSetValueEncodable() throws {
    let model = Model(a: "hello", b: 42)
    let fake = DatabaseReferenceFake()
    try fake.setValue(from: model)

    let decoder = Database.Decoder()
    let decoded = try decoder.decode(Model.self, from: fake.value as Any)
    XCTAssertEqual(decoded, model)
  }

  func testSetValueEncodableWithCompletion() throws {
    let model = Model(a: "hello", b: 42)
    let fake = DatabaseReferenceFake()

    let completionExpectation = expectation(description: "Completion called")

    try fake.setValue(from: model, completion: { error in
      XCTAssertNil(error)
      completionExpectation.fulfill()
    })

    wait(for: [completionExpectation], timeout: 0.1)

    let decoder = Database.Decoder()
    let decoded = try decoder.decode(Model.self, from: fake.value as Any)
    XCTAssertEqual(decoded, model)
  }

}

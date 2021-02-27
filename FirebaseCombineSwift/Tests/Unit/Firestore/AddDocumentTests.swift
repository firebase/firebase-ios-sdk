// Copyright 2021 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation
import FirebaseCombineSwift
import FirebaseFirestore
import Combine
import XCTest

class AddDocumentTests: XCTestCase {
    
    class MockCollectionReference: CollectionReference {
        
        var mockAddDocument: () throws -> Void = {
            fatalError("You need to implement \(#function) in your mock.")
        }
        
        var verifyData: ((_ data: [String : Any]) throws -> Void)?
        
        override func addDocument(data: [String : Any], completion: ((Error?) -> Void)? = nil) -> DocumentReference {
            do {
                try verifyData?(data)
                try mockAddDocument()
                completion?(nil)
            } catch {
                completion?(error)
            }
            return document()
        }
        
        override init() {
        }
    }
    
    override class func setUp() {
        FirebaseApp.configureForTests()
    }
    
    override class func tearDown() {
        FirebaseApp.app()?.delete { success in
            if success {
                print("Shut down app successfully.")
            } else {
                print("💥 There was a problem when shutting down the app..")
            }
        }
    }
    
    override func setUp() {
        do {
            try Auth.auth().signOut()
        } catch {}
    }
    
    func testAddDocumentWithDataSuccess() {
        // given
        var cancellables = Set<AnyCancellable>()
        
        let addDocumentWasCalledExpectation = expectation(description: "addDocument was called")
        let addDocumentSuccessExpectation = expectation(description: "addDocument succeeded")
        
        let reference = MockCollectionReference()
        
        reference.mockAddDocument = {
            addDocumentWasCalledExpectation.fulfill()
        }
        
        let dummyData = ["name": "Johnny Appleseed"]
        
        // when
        reference.addDocument(data: dummyData)
            .sink { completion in
                switch completion {
                case .finished:
                    print("Finished")
                case let .failure(error):
                    XCTFail("💥 Something went wrong: \(error)")
                }
            } receiveValue: { _ in
                addDocumentSuccessExpectation.fulfill()
            }
            .store(in: &cancellables)
        
        // then
        wait(
            for: [addDocumentWasCalledExpectation, addDocumentSuccessExpectation],
            timeout: expectationTimeout
        )
    }
    
    func testAddDocumentWithEncodableSuccess() {
        // given
        var cancellables = Set<AnyCancellable>()
        
        let addDocumentWasCalledExpectation = expectation(description: "addDocument was called")
        let addDocumentSuccessExpectation = expectation(description: "addDocument succeeded")
        
        let reference = MockCollectionReference()
        
        reference.mockAddDocument = {
            addDocumentWasCalledExpectation.fulfill()
        }
        
        let dummyData = ["name": "Johnny Appleseed"]
        
        // when
        reference.addDocument(from: dummyData)
            .sink { completion in
                switch completion {
                case .finished:
                    print("Finished")
                case let .failure(error):
                    XCTFail("💥 Something went wrong: \(error)")
                }
            } receiveValue: { _ in
                addDocumentSuccessExpectation.fulfill()
            }
            .store(in: &cancellables)
        
        // then
        wait(
            for: [addDocumentWasCalledExpectation, addDocumentSuccessExpectation],
            timeout: expectationTimeout
        )
    }
    func testAddDocumentWithDataFailure() {
        // given
        var cancellables = Set<AnyCancellable>()
        
        let addDocumentWasCalledExpectation = expectation(description: "addDocument was called")
        let addDocumentFailureExpectation = expectation(description: "addDocument failed")
        
        let reference = MockCollectionReference()
        
        reference.mockAddDocument = {
            addDocumentWasCalledExpectation.fulfill()
        }
        
        let dummyData = ["name": "Johnny Appleseed"]
        
        // when
        reference.addDocument(data: dummyData)
            .sink { completion in
                switch completion {
                case .finished:
                    print("Finished")
                case let .failure(error as NSError):
                    XCTAssertEqual(error.code, FirestoreErrorCode.unknown.rawValue)
                    addDocumentFailureExpectation.fulfill()
                }
            } receiveValue: { _ in
                XCTFail("💥 Something went wrong")
            }
            .store(in: &cancellables)
        
        // then
        wait(
            for: [addDocumentWasCalledExpectation, addDocumentFailureExpectation],
            timeout: expectationTimeout
        )
    }
    
    func testAddDocumentWithEncodableFailure() {
        // given
        var cancellables = Set<AnyCancellable>()
        
        let addDocumentWasCalledExpectation = expectation(description: "addDocument was called")
        let addDocumentFailureExpectation = expectation(description: "addDocument failed")
        
        let reference = MockCollectionReference()
        
        reference.mockAddDocument = {
            addDocumentWasCalledExpectation.fulfill()
            throw NSError(domain: FirestoreErrorDomain,
                          code: FirestoreErrorCode.unknown.rawValue,
                          userInfo: [NSLocalizedDescriptionKey: "Dummy Error"])
        }
        
        let dummyData = ["name": "Johnny Appleseed"]
        
        // when
        reference.addDocument(from: dummyData)
            .sink { completion in
                switch completion {
                case .finished:
                    print("Finished")
                case let .failure(error as NSError):
                    XCTAssertEqual(error.code, FirestoreErrorCode.unknown.rawValue)
                    addDocumentFailureExpectation.fulfill()
                }
            } receiveValue: { _ in
                XCTFail("💥 Something went wrong")
            }
            .store(in: &cancellables)
        
        // then
        wait(
            for: [addDocumentWasCalledExpectation, addDocumentFailureExpectation],
            timeout: expectationTimeout
        )
    }
}

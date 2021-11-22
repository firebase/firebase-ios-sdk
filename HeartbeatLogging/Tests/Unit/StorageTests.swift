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

import XCTest
@testable import HeartbeatLogging

class FileStorageTests: XCTestCase {
  func testRead_WhenFileDoesNotExist_ThrowsError() {
    // Given
    let fileStorage = FileStorage(url: makeTemporaryFileURL())
    // Then
    XCTAssertThrowsError(try fileStorage.read())
  }

  func testRead_WhenFileExists_ReturnsFileContents() throws {
    // Given
    let fileStorage = FileStorage(url: makeTemporaryFileURL())

    let data = "data".data(using: .utf8)
    XCTAssertNoThrow(try fileStorage.write(data))
    // When
    let storedData = try fileStorage.read()
    // Then
    XCTAssertEqual(storedData, data)
  }

  func testWriteData_WhenFileDoesNotExist_CreatesFile() throws {
    // Given
    let fileStorage = FileStorage(url: makeTemporaryFileURL())
    XCTAssertThrowsError(try fileStorage.read())
    // When
    let data = Data()
    XCTAssertNoThrow(try fileStorage.write(data))
    // Then
    let storedData = try fileStorage.read()
    XCTAssertEqual(storedData, data)
  }

  func testWriteData_WhenFileExists_ModifiesFile() throws {
    // Given
    let fileStorage = FileStorage(url: makeTemporaryFileURL())

    let data = "data".data(using: .utf8)
    XCTAssertNoThrow(try fileStorage.write(data))
    // When
    let modifiedData = #function.data(using: .utf8)
    XCTAssertNoThrow(try fileStorage.write(modifiedData))

    // Then
    let storedData = try fileStorage.read()
    XCTAssertEqual(storedData, modifiedData)
  }

  func testWriteNil_WhenFileDoesNotExist_DoesNothing() {
    // Given
    let fileStorage = FileStorage(url: makeTemporaryFileURL())
    XCTAssertThrowsError(try fileStorage.read())
    // When
    XCTAssertNoThrow(try fileStorage.write(nil))
    // Then
    XCTAssertThrowsError(try fileStorage.read())
  }

  func testWriteNil_WhenFileExists_RemovesFile() {
    // Given
    let fileStorage = FileStorage(url: makeTemporaryFileURL())

    let data = "data".data(using: .utf8)
    XCTAssertNoThrow(try fileStorage.write(data))
    // When
    XCTAssertNoThrow(try fileStorage.write(nil))
    // Then
    XCTAssertThrowsError(try fileStorage.read())
  }

  func makeTemporaryFileURL(testName: String = #function, suffix: String = "") -> URL {
    let temporaryPath = NSTemporaryDirectory() + testName + suffix
    let temporaryURL = URL(fileURLWithPath: temporaryPath)
    try? FileManager.default.removeItem(at: temporaryURL)
    return temporaryURL
  }
}

class UserDefaultsStorageTests: XCTestCase {
  var defaults: UserDefaults!
  var data: Data!
  let suiteName = #file

  override func setUpWithError() throws {
    // Clean up suite in case prior test case did not complete.
    UserDefaults.standard.removePersistentDomain(forName: suiteName)

    defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    data = try XCTUnwrap("data".data(using: .utf8))
  }

  override func tearDownWithError() throws {
    defaults.removePersistentDomain(forName: suiteName)
  }

  func testRead_WhenDefaultDoesNotExist_ThrowsError() throws {
    // Given
    let defaultsStorage = UserDefaultsStorage(
      defaults: defaults,
      key: #function
    )
    // Then
    XCTAssertThrowsError(try defaultsStorage.read())
  }

  func testRead_WhenDefaultExists_ReturnsDefault() throws {
    // Given
    let defaultsStorage = UserDefaultsStorage(
      defaults: defaults,
      key: #function
    )
    XCTAssertNoThrow(try defaultsStorage.write(data))
    // When
    let storedData = try defaultsStorage.read()
    // Then
    XCTAssertEqual(storedData, data)
  }

  func testWriteData_WhenDefaultDoesNotExist_CreatesDefault() throws {
    // Given
    let defaultsStorage = UserDefaultsStorage(
      defaults: defaults,
      key: #function
    )
    XCTAssertThrowsError(try defaultsStorage.read())
    // When
    XCTAssertNoThrow(try defaultsStorage.write(data))
    // Then
    let storedData = try defaultsStorage.read()
    XCTAssertEqual(storedData, data)
  }

  func testWriteData_WhenDefaultExists_ModifiesDefault() throws {
    // Given
    let defaultsStorage = UserDefaultsStorage(
      defaults: defaults,
      key: #function
    )
    XCTAssertNoThrow(try defaultsStorage.write(data))
    // When
    let modifiedData = #function.data(using: .utf8)
    XCTAssertNoThrow(try defaultsStorage.write(modifiedData))

    // Then
    let storedData = try defaultsStorage.read()
    XCTAssertEqual(storedData, modifiedData)
  }

  func testWriteNil_WhenDefaultDoesNotExist_DoesNothing() throws {
    // Given
    let defaultsStorage = UserDefaultsStorage(
      defaults: defaults,
      key: #function
    )
    XCTAssertThrowsError(try defaultsStorage.read())
    // When
    XCTAssertNoThrow(try defaultsStorage.write(nil))
    // Then
    XCTAssertThrowsError(try defaultsStorage.read())
  }

  func testWriteNil_WhenDefaultExists_RemovesDefault() throws {
    // Given
    let defaultsStorage = UserDefaultsStorage(
      defaults: defaults,
      key: #function
    )
    XCTAssertNoThrow(try defaultsStorage.write(data))
    // When
    XCTAssertNoThrow(try defaultsStorage.write(nil))
    // Then
    XCTAssertThrowsError(try defaultsStorage.read())
  }
}

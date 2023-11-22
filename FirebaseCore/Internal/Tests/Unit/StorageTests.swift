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

@testable import FirebaseCoreInternal
import XCTest

private enum Constants {
  static let testData = "test_data".data(using: .utf8)!
}

// MARK: - FileStorageTests

class FileStorageTests: XCTestCase {
  func testRead_WhenFileDoesNotExist_ThrowsError() throws {
    // Given
    let fileStorage = FileStorage(url: makeTemporaryFileURL())
    // Then
    XCTAssertThrowsError(try fileStorage.read())
  }

  func testRead_WhenFileExists_ReturnsFileContents() throws {
    // Given
    let fileStorage = FileStorage(url: makeTemporaryFileURL())
    XCTAssertNoThrow(try fileStorage.write(Constants.testData))
    // When
    let storedData = try fileStorage.read()
    // Then
    XCTAssertEqual(storedData, Constants.testData)
  }

  func testWriteData_WhenFileDoesNotExist_CreatesFile() throws {
    // Given
    let fileStorage = FileStorage(url: makeTemporaryFileURL())
    XCTAssertThrowsError(try fileStorage.read())
    // When
    XCTAssertNoThrow(try fileStorage.write(Constants.testData))
    // Then
    let storedData = try fileStorage.read()
    XCTAssertEqual(storedData, Constants.testData)
  }

  func testWriteData_WhenFileExists_ModifiesFile() throws {
    // Given
    let fileStorage = FileStorage(url: makeTemporaryFileURL())
    XCTAssertNoThrow(try fileStorage.write(Constants.testData))
    // When
    let modifiedData = "modified_data".data(using: .utf8)
    XCTAssertNoThrow(try fileStorage.write(modifiedData))

    // Then
    let storedData = try fileStorage.read()
    XCTAssertEqual(storedData, modifiedData)
  }

  func testWriteNil_WhenFileDoesNotExist_CreatesEmptyFile() throws {
    // Given
    let fileStorage = FileStorage(url: makeTemporaryFileURL())
    XCTAssertThrowsError(try fileStorage.read())
    // When
    XCTAssertNoThrow(try fileStorage.write(nil))
    // Then
    let emptyData = try fileStorage.read()
    XCTAssertTrue(emptyData.isEmpty)
  }

  func testWriteNil_WhenFileExists_EmptiesFile() throws {
    // Given
    let fileStorage = FileStorage(url: makeTemporaryFileURL())
    XCTAssertNoThrow(try fileStorage.write(Constants.testData))
    // When
    XCTAssertNoThrow(try fileStorage.write(nil))
    // Then
    let emptyData = try fileStorage.read()
    XCTAssertTrue(emptyData.isEmpty)
  }

  private func makeTemporaryFileURL(testName: String = #function) -> URL {
    let temporaryPath = NSTemporaryDirectory() + testName
    let temporaryURL = URL(fileURLWithPath: temporaryPath)
    try? FileManager.default.removeItem(at: temporaryURL)
    return temporaryURL
  }
}

// MARK: - UserDefaultsStorageTests

class UserDefaultsStorageTests: XCTestCase {
  var defaults: UserDefaults!
  let suiteName = #file

  override func setUpWithError() throws {
    defaults = try XCTUnwrap(UserDefaultsFake(suiteName: suiteName))
  }

  func testRead_WhenDefaultDoesNotExist_ThrowsError() throws {
    // Given
    let defaultsStorage = UserDefaultsStorage(defaults: defaults, key: #function)
    // Then
    XCTAssertThrowsError(try defaultsStorage.read())
  }

  func testRead_WhenDefaultExists_ReturnsDefault() throws {
    // Given
    let defaultsStorage = UserDefaultsStorage(defaults: defaults, key: #function)
    XCTAssertNoThrow(try defaultsStorage.write(Constants.testData))
    // When
    let storedData = try defaultsStorage.read()
    // Then
    XCTAssertEqual(storedData, Constants.testData)
  }

  func testWriteData_WhenDefaultDoesNotExist_CreatesDefault() throws {
    // Given
    let defaultsStorage = UserDefaultsStorage(defaults: defaults, key: #function)
    XCTAssertThrowsError(try defaultsStorage.read())
    // When
    XCTAssertNoThrow(try defaultsStorage.write(Constants.testData))
    // Then
    let storedData = try defaultsStorage.read()
    XCTAssertEqual(storedData, Constants.testData)
  }

  func testWriteData_WhenDefaultExists_ModifiesDefault() throws {
    // Given
    let defaultsStorage = UserDefaultsStorage(defaults: defaults, key: #function)
    XCTAssertNoThrow(try defaultsStorage.write(Constants.testData))
    // When
    let modifiedData = #function.data(using: .utf8)
    XCTAssertNoThrow(try defaultsStorage.write(modifiedData))

    // Then
    let storedData = try defaultsStorage.read()
    XCTAssertEqual(storedData, modifiedData)
  }

  func testWriteNil_WhenDefaultDoesNotExist_RemovesDefault() throws {
    // Given
    let defaultsStorage = UserDefaultsStorage(defaults: defaults, key: #function)
    XCTAssertThrowsError(try defaultsStorage.read())
    // When
    XCTAssertNoThrow(try defaultsStorage.write(nil))
    // Then
    XCTAssertThrowsError(try defaultsStorage.read())
  }

  func testWriteNil_WhenDefaultExists_RemovesDefault() throws {
    // Given
    let defaultsStorage = UserDefaultsStorage(defaults: defaults, key: #function)
    XCTAssertNoThrow(try defaultsStorage.write(Constants.testData))
    // When
    XCTAssertNoThrow(try defaultsStorage.write(nil))
    // Then
    XCTAssertThrowsError(try defaultsStorage.read())
  }
}

// MARK: - Fakes

private class UserDefaultsFake: UserDefaults {
  private var defaults = [String: Any]()

  override func object(forKey defaultName: String) -> Any? {
    defaults[defaultName]
  }

  override func set(_ value: Any?, forKey defaultName: String) {
    defaults[defaultName] = value
  }
}

//
// Copyright 2022 Google LLC
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

@testable import FirebaseSessions
import XCTest

/// This file and extension exist for ease of testing. Without this, you cannot use
/// XCTAssertEqual on errors, which means you need to do switches whenever you
/// want to assert on errors, which is clunky.
///
/// This class exists for unit testing purposes only. The SDK should use switch internally
/// when handling errors, because equating errors is prone to issues (eg. we're just comparing
/// the types, but not the values).
extension FirebaseSessionsError: Swift.Equatable {
  public static func == (lhs: FirebaseSessions.FirebaseSessionsError,
                         rhs: FirebaseSessions.FirebaseSessionsError) -> Bool {
    return String(reflecting: lhs) == String(reflecting: rhs)
  }
}

enum FakeError: Error {
  case Fake
}

final class ErrorEquatableTests: XCTestCase {
  func test_equalErrorTypes_areEqual() throws {
    let fakeError = FakeError.Fake
    let errs: [FirebaseSessionsError] = [
      .DataCollectionError,
      .SessionSamplingError,
      .SessionInstallationsError(fakeError),
      .DisabledViaSettingsError,
      .DataTransportError(fakeError),
    ]
    let errs2: [FirebaseSessionsError] = [
      .DataCollectionError,
      .SessionSamplingError,
      .SessionInstallationsError(fakeError),
      .DisabledViaSettingsError,
      .DataTransportError(fakeError),
    ]
    for (i, err) in errs.enumerated() {
      XCTAssertEqual(err, errs2[i])
    }
  }

  func test_unequalErrorTypes_areNotEqual() throws {
    let fakeError = FakeError.Fake
    let errs: [FirebaseSessionsError] = [
      .DataCollectionError,
      .SessionSamplingError,
      .SessionInstallationsError(fakeError),
      .DisabledViaSettingsError,
      .DataTransportError(fakeError),
    ]
    // errs2 is off by one from errs so none of the elements match
    let errsOffByOne: [FirebaseSessionsError] = [
      .DataTransportError(fakeError),
      .DataCollectionError,
      .SessionSamplingError,
      .SessionInstallationsError(fakeError),
      .DisabledViaSettingsError,
    ]
    for (i, err) in errs.enumerated() {
      XCTAssertNotEqual(err, errsOffByOne[i])
    }
  }
}

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
import XCTest

@objc(FIRHeartbeatLoggingTestUtils)
@objcMembers
public class HeartbeatLoggingTestUtils: NSObject {
  @objc(assertEncodedPayloadString:isEqualToLiteralString:withError:)
  public static func assertEqualPayloadStrings(_ encoded: String, _ literal: String) throws {
    let encodedData = try XCTUnwrap(Data(base64Encoded: encoded))
    let literalData = try XCTUnwrap(literal.data(using: .utf8))

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .formatted(HeartbeatsPayload.dateFormatter)

    let payloadFromEncoded = try? decoder.decode(HeartbeatsPayload.self, from: encodedData)

    let payloadFromLiteral = try? decoder.decode(HeartbeatsPayload.self, from: literalData)

    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .formatted(HeartbeatsPayload.dateFormatter)
    encoder.outputFormatting = .prettyPrinted

    let payloadDataFromEncoded = try XCTUnwrap(encoder.encode(payloadFromEncoded))
    let payloadDataFromLiteral = try XCTUnwrap(encoder.encode(payloadFromLiteral))

    XCTAssertEqual(
      payloadFromEncoded,
      payloadFromLiteral,
      """
      Mismatched payloads!

      Payload 1:
      \(String(data: payloadDataFromEncoded, encoding: .utf8) ?? "")

      Payload 2:
      \(String(data: payloadDataFromLiteral, encoding: .utf8) ?? "")

      """
    )
  }

  /// Removes all underlying storage containers used by the module.
  /// - Throws: An error if the storage container could not be removed.
  public static func removeUnderlyingHeartbeatStorageContainers() throws {
    #if os(tvOS)
      UserDefaults().removePersistentDomain(forName: Constants.heartbeatUserDefaultsSuiteName)
    #else
      let heartbeatsDirectoryURL = FileManager.default
        .applicationSupportDirectory
        .appendingPathComponent(
          Constants.heartbeatFileStorageDirectoryPath, isDirectory: true
        )
      do {
        try FileManager.default.removeItem(at: heartbeatsDirectoryURL)
      } catch CocoaError.fileNoSuchFile {
        // Do nothing.
      } catch {
        throw error
      }
    #endif // os(tvOS)
  }
}

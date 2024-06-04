// Copyright 2024 Google LLC
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

import FirebaseSharedSwift

// UUIDKey represents the UUID custom scalar type in Data Connect
// Its a UUID without dashes.
@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
public struct UUIDKey: Codable, Equatable, Hashable, Identifiable, CustomStringConvertible {
  // Identifiable conformance. Same as 'uuid'
  public var id: UUID { uuid }

  public private(set) var uuid: UUID

  public private(set) var uuidKeyString: String

  public init() {
    uuid = UUID()
    uuidKeyString = UUIDKey.convertToNoDashUUID(uuid: uuid)
  }

  public init(uuid: UUID) {
    self.uuid = uuid
    uuidKeyString = UUIDKey.convertToNoDashUUID(uuid: uuid)
  }

  public init?(uuidKeyString: String) {
    guard let expandedString = UUIDKey.addDashesToUUIDString(uuidKeyString: uuidKeyString),
          let uuid = UUID(uuidString: expandedString) else {
      return nil
    }
    self.uuidKeyString = uuidKeyString
    self.uuid = uuid
  }

  public var description: String {
    return uuidKeyString
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    let value = try container.decode(String.self)

    guard let ukey = UUIDKey(uuidKeyString: value) else {
      throw DataConnectError.invalidUUID
    }
    self = ukey
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    let uuidKeyString = UUIDKey.convertToNoDashUUID(uuid: uuid)
    try container.encode(uuidKeyString)
  }

  private static func convertToNoDashUUID(uuid: UUID) -> String {
    return uuid.uuidString.replacingOccurrences(of: "-", with: "").lowercased()
  }

  private static func addDashesToUUIDString(uuidKeyString: String) -> String? {
    guard uuidKeyString.count == 32 else {
      return nil
    }

    let sourceChars = [Character](uuidKeyString)
    var targetChars = [Character]()

    var indx = 0
    while indx < sourceChars.count {
      switch indx {
      case 8, 12, 16, 20:
        targetChars.append("-")
      default:
        break
      }
      targetChars.append(sourceChars[indx])
      indx += 1
    }

    return String(targetChars)
  }
}

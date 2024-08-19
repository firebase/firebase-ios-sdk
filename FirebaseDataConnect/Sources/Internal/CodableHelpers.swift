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

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
protocol CodableConverter {
  associatedtype E: Encodable
  associatedtype D: Decodable

  func encode(input: E) throws -> D
  func decode(input: D) throws -> E
}

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
class Int64CodableConverter: CodableConverter {
  func encode(input: Int64?) throws -> String? {
    guard let input else {
      return nil
    }

    let int64String = "\(input)"
    return int64String
  }

  func decode(input: String?) throws -> Int64? {
    guard let input else {
      return nil
    }

    guard let int64Value = Int64(input) else {
      throw DataConnectError.decodeFailed
    }
    return int64Value
  }
}

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
class UUIDCodableConverter: CodableConverter {
  func encode(input: UUID?) throws -> String? {
    guard let input else {
      return nil
    }

    let uuidNoDashString = convertToNoDashUUID(uuid: input)
    return uuidNoDashString
  }

  func decode(input: String?) throws -> UUID? {
    guard let input,
          let dashesAddedUUID = addDashesToUUIDString(uuidKeyString: input)
    else {
      return nil
    }

    return UUID(uuidString: dashesAddedUUID)
  }

  private func convertToNoDashUUID(uuid: UUID) -> String {
    return uuid.uuidString.replacingOccurrences(of: "-", with: "").lowercased()
  }

  private func addDashesToUUIDString(uuidKeyString: String) -> String? {
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

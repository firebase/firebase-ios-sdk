//
//  CodecHelper.swift
//
//
//  Created by Aashish Patil on 6/4/24.
//

import Foundation

/*
 *** IMPORTANT ***

 Although this class is marked as public,
 this class is not part of supported public API and is subject to change.
 It is only for internal use by Data Connect generated code.

 */
@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
public class CodecHelper<K: CodingKey> {
  // MARK: Encoding

  public func encode(_ value: Encodable, forKey: K,
                     container: inout KeyedEncodingContainer<K>) throws {
    switch value {
    case let int64Value as Int64:
      let int64Value = "\(value)"
      try container.encode(int64Value, forKey: forKey)
    case let uuidValue as UUID:
      let noDashUUID = convertToNoDashUUID(uuid: uuidValue)
      try container.encode(noDashUUID, forKey: forKey)
    default:
      try container.encode(value, forKey: forKey)
    }
  }

  private func convertToNoDashUUID(uuid: UUID) -> String {
    return uuid.uuidString.replacingOccurrences(of: "-", with: "").lowercased()
  }

  // MARK: Decoding

  public func decode<T: Decodable>(_ type: T.Type, forKey: K,
                                   container: inout KeyedDecodingContainer<K>) throws -> T {
    if type == Int64.self {
      let int64String = try container.decode(String.self, forKey: forKey)
      guard let int64Value = Int64(int64String) else {
        throw DataConnectError.decodeFailed
      }
      return int64Value as! T
    } else if type == UUID.self {
      let uuidNoDashString = try container.decode(String.self, forKey: forKey)

      guard let uuidString = addDashesToUUIDString(uuidKeyString: uuidNoDashString),
            let uuid = UUID(uuidString: uuidString) else {
        throw DataConnectError.decodeFailed
      }
      return uuid as! T
    }
    return try container.decode(type, forKey: forKey)
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

  public init() {}
}

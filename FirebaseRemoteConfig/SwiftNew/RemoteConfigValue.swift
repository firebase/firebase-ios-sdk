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

import FirebaseCore
import Foundation

// TODO: Some objc's and public's should be removed.

@objc(FIRRemoteConfigValue)
public class RemoteConfigValue: NSObject, NSCopying {
  /// Data backing the config value.
  @objc public let dataValue: Data

  /// Identifies the source of the fetched value. Only for Firebase internal use.
  @objc public let source: RemoteConfigSource

  /// Designated initializer. Only for Firebase internal use.
  @objc public init(data: Data?, source: RemoteConfigSource) {
    dataValue = data ?? Data()
    self.source = source
  }

  /// Gets the value as a string.
  @objc public var stringValue: String {
    if let string = String(data: dataValue, encoding: .utf8) {
      return string
    }
    return "" // Return empty string if data is not valid UTF-8
  }

  /// Gets the value as a number value.
  @objc public var numberValue: NSNumber {
    return NSNumber(value: Double(stringValue) ?? 0)
  }

  /// Gets the value as a boolean.
  @objc public var boolValue: Bool {
    return (stringValue as NSString).boolValue
  }

  /// Gets a foundation object (NSDictionary / NSArray) by parsing the value as JSON.
  @objc(JSONValue) public var jsonValue: Any? {
    guard !dataValue.isEmpty else {
      return nil
    }
    do {
      let jsonObject = try JSONSerialization.jsonObject(with: dataValue, options: [])
      return jsonObject
    } catch {
      RCLog.debug("I-RCN000065", "Error parsing data as JSON.")
      return nil
    }
  }

  /// Debug description showing the representations of all types.
  override public var debugDescription: String {
    let content = """
    Boolean: \(boolValue), String: \(stringValue), Number: \(numberValue), \
    JSON:\(String(describing: jsonValue)), Data: \(dataValue), Source: \(source.rawValue)
    """
    return "<\(type(of: self)): \(Unmanaged.passUnretained(self).toOpaque()), \(content)>"
  }

  /// Copy method.
  @objc public func copy(with zone: NSZone? = nil) -> Any {
    return RemoteConfigValue(data: dataValue, source: source)
  }
}

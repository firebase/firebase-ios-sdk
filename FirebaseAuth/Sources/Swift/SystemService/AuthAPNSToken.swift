// Copyright 2023 Google LLC
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

#if !os(macOS)
  import Foundation

  /// A data structure for an APNs token.
  class AuthAPNSToken: NSObject {
    let data: Data
    let type: AuthAPNSTokenType

    /// Initializes the instance.
    /// - Parameter data: The APNs token data.
    /// - Parameter type: The APNs token type.
    /// - Returns: The initialized instance.
    init(withData data: Data, type: AuthAPNSTokenType) {
      self.data = data
      self.type = type
    }

    /// The uppercase hexadecimal string form of the APNs token data.
    lazy var string: String = {
      let byteArray = [UInt8](data)
      var s = ""
      for byte in byteArray {
        s.append(String(format: "%02X", byte))
      }
      return s
    }()
  }
#endif

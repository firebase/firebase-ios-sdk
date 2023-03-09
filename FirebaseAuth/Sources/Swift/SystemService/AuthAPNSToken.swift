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

  /** @class AuthAPNSToken
      @brief A data structure for an APNs token.
   */
  @objc(FIRAuthAPNSToken) public class AuthAPNSToken: NSObject {
    @objc public let data: Data
    @objc public let type: AuthAPNSTokenType

    @objc public init(withData data: Data, type: AuthAPNSTokenType) {
      self.data = data
      self.type = type
    }

    @objc public lazy var string: String = {
      let byteArray = [UInt8](data)
      var s = ""
      for byte in byteArray {
        s.append(String(format: "%02X", byte))
      }
      return s
    }()
  }
#endif

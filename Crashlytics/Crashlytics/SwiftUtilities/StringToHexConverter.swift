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

// This is a swift rewrite for the logic in FIRCLSFile for the function FIRCLSFileHexEncodeString()
@objc(FIRCLSwiftFileUtility)
public class FileUtility: NSObject {
  @objc public static func stringToHexConverter(for string: String) -> String {
    let hexMap = "0123456789abcdef"

    var processedString = ""
    let utf8Array = string.utf8.map { UInt8($0) }
    for c in utf8Array {
      let index1 = String.Index(
        utf16Offset: Int(c >> 4),
        in: hexMap
      )
      let index2 = String.Index(
        utf16Offset: Int(c & 0x0F),
        in: hexMap
      )
      processedString = processedString + String(hexMap[index1]) + String(hexMap[index2])
    }
    return processedString
  }
}

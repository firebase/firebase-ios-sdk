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

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
public struct ImagenAspectRatio {
  public static let square1x1 = ImagenAspectRatio(kind: .square1x1)

  public static let portrait9x16 = ImagenAspectRatio(kind: .portrait9x16)

  public static let landscape16x9 = ImagenAspectRatio(kind: .landscape16x9)

  public static let portrait3x4 = ImagenAspectRatio(kind: .portrait3x4)

  public static let landscape4x3 = ImagenAspectRatio(kind: .landscape4x3)

  let rawValue: String
}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
extension ImagenAspectRatio: ProtoEnum {
  enum Kind: String {
    case square1x1 = "1:1"
    case portrait9x16 = "9:16"
    case landscape16x9 = "16:9"
    case portrait3x4 = "3:4"
    case landscape4x3 = "4:3"
  }
}

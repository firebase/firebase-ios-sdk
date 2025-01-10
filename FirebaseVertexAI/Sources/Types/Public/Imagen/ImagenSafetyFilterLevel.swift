// Copyright 2025 Google LLC
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

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
public struct ImagenSafetyFilterLevel: ProtoEnum {
  enum Kind: String {
    case blockLowAndAbove = "block_low_and_above"
    case blockMediumAndAbove = "block_medium_and_above"
    case blockOnlyHigh = "block_only_high"
    case blockNone = "block_none"
  }

  public static let blockLowAndAbove = ImagenSafetyFilterLevel(kind: .blockLowAndAbove)
  public static let blockMediumAndAbove = ImagenSafetyFilterLevel(kind: .blockMediumAndAbove)
  public static let blockOnlyHigh = ImagenSafetyFilterLevel(kind: .blockOnlyHigh)
  public static let blockNone = ImagenSafetyFilterLevel(kind: .blockNone)

  let rawValue: String
}

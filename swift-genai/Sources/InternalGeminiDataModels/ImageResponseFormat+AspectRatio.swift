// Copyright 2026 Google LLC
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

extension GeminiDataModels.ImageResponseFormat {
  /// Optional. The aspect ratio for the image output.
  package enum AspectRatio: Codable, Sendable, Equatable, Hashable {
    /// 1:1 aspect ratio.
    case oneByOne
    
    /// 2:3 aspect ratio.
    case twoByThree
    
    /// 3:2 aspect ratio.
    case threeByTwo
    
    /// 3:4 aspect ratio.
    case threeByFour
    
    /// 4:3 aspect ratio.
    case fourByThree
    
    /// 4:5 aspect ratio.
    case fourByFive
    
    /// 5:4 aspect ratio.
    case fiveByFour
    
    /// 9:16 aspect ratio.
    case nineBySixteen
    
    /// 16:9 aspect ratio.
    case sixteenByNine
    
    /// 21:9 aspect ratio.
    case twentyOneByNine
    
    /// 1:8 aspect ratio.
    case oneByEight
    
    /// 8:1 aspect ratio.
    case eightByOne
    
    /// 1:4 aspect ratio.
    case oneByFour
    
    /// 4:1 aspect ratio.
    case fourByOne
    
    /// Unrecognized case.
    ///
    /// - Parameter value: The raw string value of the unrecognized enum case.
    case unrecognized(_ value: String)
  }
}

// MARK: - RawRepresentable Conformance

extension GeminiDataModels.ImageResponseFormat.AspectRatio: RawRepresentable {
  package var rawValue: String {
    switch self {
    case .oneByOne: "ASPECT_RATIO_ONE_BY_ONE"
    case .twoByThree: "ASPECT_RATIO_TWO_BY_THREE"
    case .threeByTwo: "ASPECT_RATIO_THREE_BY_TWO"
    case .threeByFour: "ASPECT_RATIO_THREE_BY_FOUR"
    case .fourByThree: "ASPECT_RATIO_FOUR_BY_THREE"
    case .fourByFive: "ASPECT_RATIO_FOUR_BY_FIVE"
    case .fiveByFour: "ASPECT_RATIO_FIVE_BY_FOUR"
    case .nineBySixteen: "ASPECT_RATIO_NINE_BY_SIXTEEN"
    case .sixteenByNine: "ASPECT_RATIO_SIXTEEN_BY_NINE"
    case .twentyOneByNine: "ASPECT_RATIO_TWENTY_ONE_BY_NINE"
    case .oneByEight: "ASPECT_RATIO_ONE_BY_EIGHT"
    case .eightByOne: "ASPECT_RATIO_EIGHT_BY_ONE"
    case .oneByFour: "ASPECT_RATIO_ONE_BY_FOUR"
    case .fourByOne: "ASPECT_RATIO_FOUR_BY_ONE"
    case .unrecognized(let value): value
    }
  }

  package init(rawValue: String) {
    switch rawValue {
    case "ASPECT_RATIO_ONE_BY_ONE": self = .oneByOne
    case "ASPECT_RATIO_TWO_BY_THREE": self = .twoByThree
    case "ASPECT_RATIO_THREE_BY_TWO": self = .threeByTwo
    case "ASPECT_RATIO_THREE_BY_FOUR": self = .threeByFour
    case "ASPECT_RATIO_FOUR_BY_THREE": self = .fourByThree
    case "ASPECT_RATIO_FOUR_BY_FIVE": self = .fourByFive
    case "ASPECT_RATIO_FIVE_BY_FOUR": self = .fiveByFour
    case "ASPECT_RATIO_NINE_BY_SIXTEEN": self = .nineBySixteen
    case "ASPECT_RATIO_SIXTEEN_BY_NINE": self = .sixteenByNine
    case "ASPECT_RATIO_TWENTY_ONE_BY_NINE": self = .twentyOneByNine
    case "ASPECT_RATIO_ONE_BY_EIGHT": self = .oneByEight
    case "ASPECT_RATIO_EIGHT_BY_ONE": self = .eightByOne
    case "ASPECT_RATIO_ONE_BY_FOUR": self = .oneByFour
    case "ASPECT_RATIO_FOUR_BY_ONE": self = .fourByOne
    default: self = .unrecognized(rawValue)
    }
  }
}
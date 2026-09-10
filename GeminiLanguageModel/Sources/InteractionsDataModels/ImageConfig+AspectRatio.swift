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

extension ImageConfig {
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

extension ImageConfig.AspectRatio: RawRepresentable {
  package var rawValue: String {
    switch self {
    case .oneByOne: "1:1"
    case .twoByThree: "2:3"
    case .threeByTwo: "3:2"
    case .threeByFour: "3:4"
    case .fourByThree: "4:3"
    case .fourByFive: "4:5"
    case .fiveByFour: "5:4"
    case .nineBySixteen: "9:16"
    case .sixteenByNine: "16:9"
    case .twentyOneByNine: "21:9"
    case .oneByEight: "1:8"
    case .eightByOne: "8:1"
    case .oneByFour: "1:4"
    case .fourByOne: "4:1"
    case .unrecognized(let value): value
    }
  }

  package init(rawValue: String) {
    switch rawValue {
    case "1:1": self = .oneByOne
    case "2:3": self = .twoByThree
    case "3:2": self = .threeByTwo
    case "3:4": self = .threeByFour
    case "4:3": self = .fourByThree
    case "4:5": self = .fourByFive
    case "5:4": self = .fiveByFour
    case "9:16": self = .nineBySixteen
    case "16:9": self = .sixteenByNine
    case "21:9": self = .twentyOneByNine
    case "1:8": self = .oneByEight
    case "8:1": self = .eightByOne
    case "1:4": self = .oneByFour
    case "4:1": self = .fourByOne
    default: self = .unrecognized(rawValue)
    }
  }
}

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

public struct TimeUnit: Sendable, Equatable, Hashable {
  enum Kind: String {
    case microsecond
    case millisecond
    case second
    case minute
    case hour
    case day
  }

  public static let microsecond = TimeUnit(kind: .microsecond)
  public static let millisecond = TimeUnit(kind: .millisecond)
  public static let second = TimeUnit(kind: .second)
  public static let minute = TimeUnit(kind: .minute)
  public static let hour = TimeUnit(kind: .hour)
  public static let day = TimeUnit(kind: .day)

  public let rawValue: String

  init(kind: Kind) {
    rawValue = kind.rawValue
  }
}

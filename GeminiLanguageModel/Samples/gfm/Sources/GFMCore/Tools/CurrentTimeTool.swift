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

#if canImport(FoundationModels) && compiler(>=6.4)
  public import FoundationModels

  /// A built-in demo tool that retrieves the current system date, time, and timezone.
  @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
  @available(tvOS, unavailable)
  public struct CurrentTimeTool: Tool, Sendable {
    public let name = "current_time"
    public let description = "Get the current date, time, and timezone."

    /// Arguments schema for the `CurrentTimeTool` (no arguments needed).
    @Generable
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    @available(tvOS, unavailable)
    public struct Arguments: Sendable {
      public init() {}
    }

    public init() {}

    /// Executes the tool call, returning the formatted current date and time.
    ///
    /// - Parameter arguments: The arguments supplied by the language model.
    /// - Returns: A string representation of the current timestamp with timezone.
    public func call(arguments: Arguments) async throws -> String {
      let formatter = DateFormatter()
      formatter.dateStyle = .full
      formatter.timeStyle = .full
      formatter.locale = Locale.current
      formatter.timeZone = TimeZone.current
      return formatter.string(from: Date())
    }
  }
#endif

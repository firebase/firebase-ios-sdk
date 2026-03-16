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

import Foundation

/// An expression that produces an error with a custom error message.
/// This is primarily used for debugging purposes.
///
/// Example:
/// ```swift
/// ErrorExpression("This is a custom error message").as("errorResult")
/// ```
public class ErrorExpression: FunctionExpression, @unchecked Sendable {
  public init(_ errorMessage: String) {
    super.init(functionName: "error", args: [Constant(errorMessage)])
  }
}

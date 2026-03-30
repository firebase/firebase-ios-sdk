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

/// Represents the query enhancement to be used in a search stage.
///
/// - Note: This API is in beta.
public struct QueryEnhancement: Sendable, Equatable, Hashable {
  let kind: Kind

  enum Kind: String {
    case disabled
    case required
    case preferred
  }

  /// Query enhancement is disabled.
  public static let disabled: QueryEnhancement = .init(kind: .disabled)

  /// Query enhancement is required. If query enhancement fails or times out, the search stage will
  /// fail, causing the pipeline to fail.
  public static let required: QueryEnhancement = .init(kind: .required)

  /// Query enhancement is preferred.If query enhancement fails or times out, the search stage will
  /// still execute with the user provided query.
  public static let preferred: QueryEnhancement = .init(kind: .preferred)

  init(kind: Kind) {
    self.kind = kind
  }
}

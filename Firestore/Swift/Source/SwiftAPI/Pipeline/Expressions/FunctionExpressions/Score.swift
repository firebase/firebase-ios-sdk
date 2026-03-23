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

#if SWIFT_PACKAGE
  @_exported import FirebaseFirestoreInternalWrapper
#else
  @_exported import FirebaseFirestoreInternal
#endif // SWIFT_PACKAGE
import Foundation

/// Represents the relevance score of a document against the search query.
///
/// Example usage:
/// ```swift
/// firestore.pipeline().collection("restaurants")
/// .search(
///   query: "waffles OR pancakes",
///   sort: [ Score().as("searchScore") ]
/// )
/// ```
public struct Score: Expression, BridgeWrapper, @unchecked Sendable {
  public let bridge: ExprBridge

  public init() {
    let funcExpr = FunctionExpression(functionName: "score", args: [])
    bridge = funcExpr.bridge
  }
}

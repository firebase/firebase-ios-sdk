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

#if SWIFT_PACKAGE
  @_exported import FirebaseFirestoreInternalWrapper
#else
  @_exported import FirebaseFirestoreInternal
#endif // SWIFT_PACKAGE
import Foundation

/// A full-text search against all indexed search fields in the document.
///
/// - Note: This API is in beta.
///
/// Note: This expression can only be used in the `search` stage.
///
/// Example usage in a `search` stage:
/// ```swift
/// firestore.pipeline()
///   .collection("restaurants")
///   .search(query: DocumentMatches("waffles OR pancakes"))
/// ```
public struct DocumentMatches: BooleanExpression, BridgeWrapper, @unchecked Sendable {
  public let bridge: ExprBridge

  /// Creates a document search expression.
  /// - Parameters:
  ///   - query: The text to search for.
  public init(_ query: String) {
    let args: [Sendable] = [query]
    let exprs = args.map { Helper.sendableToExpr($0) }
    let funcExpr = FunctionExpression(functionName: "document_matches", args: exprs)
    bridge = funcExpr.bridge
  }
}

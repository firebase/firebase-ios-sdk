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

/// Represents a full-text search against the entire document content.
public struct SearchDocumentFor: BooleanExpression, BridgeWrapper, @unchecked Sendable {
  public let bridge: ExprBridge

  /// Creates a document search expression.
  /// - Parameters:
  ///   - query: The text to search for.
  ///   - mode: The search mode to use.
  public init(_ query: String, mode: SearchMode? = nil) {
    var args: [Sendable] = [query]
    if let mode = mode {
      args.append(mode.rawValue)
    }
    let exprs = args.map { Helper.sendableToExpr($0) }
    // Assuming a function "search_document_for" that takes query and optional mode as args.
    let funcExpr = FunctionExpression(functionName: "search_document_for", args: exprs)
    bridge = funcExpr.bridge
  }
}

/// Represents the relevance score of a document against the search query.
public struct TopicalityScore: Expression, BridgeWrapper, @unchecked Sendable {
  public let bridge: ExprBridge

  public init() {
    let funcExpr = FunctionExpression(functionName: "topicality_score", args: [])
    bridge = funcExpr.bridge
  }
}

/// Generates a snippet highlighting matches within the entire document.
public struct DocumentSnippet: Expression, BridgeWrapper, @unchecked Sendable {
  public let bridge: ExprBridge

  /// Creates a document-level snippet expression.
  /// - Parameter rquery: The search query string used to find matches.
  public init(_ rquery: String) {
    let funcExpr = FunctionExpression(functionName: "document_snippet", args: [Constant(rquery)])
    bridge = funcExpr.bridge
  }
}

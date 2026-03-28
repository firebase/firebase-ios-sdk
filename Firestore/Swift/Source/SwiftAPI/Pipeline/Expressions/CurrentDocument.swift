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

/// An expression that represents the current document being processed.
///
/// Example:
/// ```swift
/// // Define the current document as a variable "doc"
/// firestore.pipeline().collection("books")
///     .define([CurrentDocument().as("doc")])
///     // Access a field from the defined document variable
///     .select([Variable("doc").getField("title")])
/// ```
public struct CurrentDocument: Expression, BridgeWrapper {
  let bridge: ExprBridge

  public init() {
    bridge = FunctionExprBridge(name: "current_document", args: [])
  }
}

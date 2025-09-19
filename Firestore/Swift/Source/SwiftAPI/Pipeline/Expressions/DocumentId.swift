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

///
/// Represents the ID of a document.
///
/// A `DocumentId` expression can be used in pipeline stages like `where`, `sort`, and `select`
/// to refer to the unique identifier of a document. It is a special field that is implicitly
/// available on every document.
///
/// Example usage:
///
/// ```swift
/// // Sort documents by their ID in ascending order
/// firestore.pipeline()
///   .collection("users")
///   .sort(DocumentId().ascending())
///
/// // Select the document ID and another field
/// firestore.pipeline()
///   .collection("products")
///   .select([
///     DocumentId().as("productId"),
///     Field("name")
///   ])
///
/// // Filter documents based on their ID
/// firestore.pipeline()
///   .collection("orders")
///   .where(DocumentId().equal("some-order-id"))
/// ```
public class DocumentId: Field, @unchecked Sendable {
  /// Initializes a new `DocumentId` expression.
  public init() {
    super.init("__name__")
  }
}

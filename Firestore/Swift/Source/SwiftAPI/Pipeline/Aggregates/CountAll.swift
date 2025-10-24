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
/// Represents an aggregation that counts all documents in the input set.
///
/// `CountAll` is used within the `aggregate` pipeline stage to get the total number of documents
/// that match the query criteria up to that point.
///
/// Example usage:
/// ```swift
/// // Count all books in the collection
/// firestore.pipeline()
///   .collection("books")
///   .aggregate([
///     CountAll().as("totalBooks")
///   ])
///
/// // Count all sci-fi books published after 1960
/// firestore.pipeline()
///   .collection("books")
///   .where(Field("genre").equal("Science Fiction") && Field("published").greaterThan(1960))
///   .aggregate([
///     CountAll().as("sciFiBooksCount")
///   ])
/// ```
public class CountAll: AggregateFunction, @unchecked Sendable {
  /// Initializes a new `CountAll` aggregation.
  public init() {
    super.init(functionName: "count", args: [])
  }
}

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

/// Computes the rank of the current document within its window partition.
///
/// Documents that compare equal in the window sort order receive the same rank, and the next rank
/// is offset by the number of tied documents.
///
/// Example usage:
/// ```swift
/// firestore.pipeline()
///   .collection("sales")
///   .addWindowFields(
///     window: .partition(["product"]).sort(Field("salesPrice").descending()),
///     fields: [
///       Rank().as("topSalesRank")
///     ]
///   )
/// ```
public class Rank: WindowFunction, @unchecked Sendable {
  /// Initializes a new `Rank` window function.
  public init() {
    super.init(functionName: "rank", args: [])
  }
}

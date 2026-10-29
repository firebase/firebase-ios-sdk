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

/// **[Public Preview]** Returns the rank of each document within its partition according to the
/// window's sort order. Documents with equal sort values receive the same rank, and the following
/// rank is skipped. The window must specify exactly one sort ordering.
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
///
/// > Warning: Window Functions SDK features are in preview until the backend feature
/// > launches. Look for launch announcement at:
/// > https://docs.cloud.google.com/firestore/docs/release-notes
public class Rank: WindowFunction, @unchecked Sendable {
  /// Initializes a new `Rank` window function.
  public init() {
    super.init(functionName: "rank", args: [])
  }
}

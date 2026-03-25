/*
 * Copyright 2026 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

/// A `Subcollection` is a special type of pipeline constructed for sub-queries.
///
/// It is not tied to a primary database instance upfront and cannot be executed directly;
/// instead, it is intended to be converted into an array or scalar expression and used within
/// another pipeline's stage (such as `addFields`).
///
/// ```swift
/// // Calculate the average rating of reviews for each book and add it as a field.
/// firestore.pipeline().collection("books")
///   .addFields([
///      Subcollection("reviews")
///          .aggregate([Field("rating").average().as("avgRating")])
///          .toScalarExpression().as("averageRating")
///   ])
/// ```
@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
public class Subcollection: Pipeline {
  
  /// Initializes a Subcollection Pipeline centered on a target path.
  ///
  /// - Parameter path: The location of the subcollection or relative target.
  public init(_ path: String) {
    super.init(stages: [SubcollectionStage(path: path)], db: nil)
  }
}

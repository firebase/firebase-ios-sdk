/*
 * Copyright 2021 Google LLC
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

/// A configuration used in FirestoreQueries and the underlying FirestoreQueryObservables.
///
/// The configuration of a FirestoreQuery can be accessed and dynamically changed using the projectedValue of the Property Wrapper.
/// See FirestoreQuery.projectedValue for more details.
public struct FirestoreQueryConfiguration {
  public var path: String
  public var predicates: [QueryPredicate]
}

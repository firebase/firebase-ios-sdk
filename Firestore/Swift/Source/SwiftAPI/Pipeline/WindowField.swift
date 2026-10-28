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

/// A protocol for named values that can be computed by the `addWindowFields` stage.
///
/// `WindowField` is adopted by `AliasedAggregate` (an `AggregateFunction` given an alias with
/// `.as()`) and `AliasedWindowFunction` (a `WindowFunction`, such as `Rank()` or an aggregate
/// with `.over()`, given an alias with `.as()`).
///
/// - Note: This API is in beta. Window Functions SDK features are in preview until the backend
///   feature launches. Look for launch announcement at:
///   https://docs.cloud.google.com/firestore/docs/release-notes
public protocol WindowField: Sendable {}

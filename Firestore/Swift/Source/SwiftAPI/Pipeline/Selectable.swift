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

/// A protocol for expressions that have a name.
///
/// `Selectable` is adopted by expressions that can be used in pipeline stages where a named output
/// is required, such as `select` and `distinct`.
///
/// A `Field` is a `Selectable` where the name is the field path.
///
/// An expression can be made `Selectable` by giving it an alias using the `.as()` method.
public protocol Selectable: Sendable {}

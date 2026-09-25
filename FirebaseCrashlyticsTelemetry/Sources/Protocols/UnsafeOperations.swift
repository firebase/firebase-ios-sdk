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

/// A marker protocol used to opt types into exposing an explicit namespace for unsafe operations.
///
/// Types conforming to this protocol automatically gain a static `.unsafe` property.
protocol UnsafeOperations {}

extension UnsafeOperations {
  /// Exposes unsafe memory operations scoped specifically to this type.
  ///
  /// This property returns a zero-cost namespace wrapper allowing safe APIs to remain
  /// separated from manually managed memory operations (e.g.,
  /// `CommonAdapter.unsafe.toProtoAttribute(...)`).
  static var unsafe: UnsafeMemoryOperations<Self> {
    return UnsafeMemoryOperations<Self>()
  }
}

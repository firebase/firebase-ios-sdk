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

/// A generic namespace wrapper that acts as a compile-time "gate" for unsafe operations.
///
/// This type does not store any state and is optimized away entirely by the compiler at runtime.
/// It uses the `Base` generic parameter as a phantom type to scope specific extensions
/// (e.g., `extension UnsafeMemoryOperations where Base == CommonAdapter`).
struct UnsafeMemoryOperations<Base> {
  /// Initializes an instance of the namespace wrapper.
  /// This is kept internal to allow instantiation within the protocol extension.
  init() {}
}

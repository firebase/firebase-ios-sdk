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

package import FirebaseCore
import Foundation

/// Type-safe lookup wrapper matching Darwin's `FIRComponentType` (`ComponentType`).
package enum ComponentType<T> {
  /// Retrieves a component instance that provides the specified functionality from `container`.
  ///
  /// - Parameters:
  ///   - type: The interop protocol or component type to retrieve.
  ///   - container: The `FirebaseComponentContainer` belonging to a `FirebaseApp`.
  /// - Returns: The component instance, or `nil` if none is registered.
  package static func instance(for type: T.Type,
                               in container: FirebaseComponentContainer) -> T? {
    container.instance(for: type)
  }
}

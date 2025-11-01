/*
 * Copyright 2025 Google LLC
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

#if SWIFT_PACKAGE
  @_exported import FirebaseFirestoreInternalWrapper
#else
  @_exported import FirebaseFirestoreInternal
#endif // SWIFT_PACKAGE
import Foundation

@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
public extension Query {
  func snapshotStream(options: SnapshotListenOptions = SnapshotListenOptions())
    -> AsyncThrowingStream<QuerySnapshot, Error> {
    AsyncThrowingStream { continuation in
      let listener = self.addSnapshotListener(options: options) { snapshot, error in
        if let snapshot = snapshot {
          continuation.yield(snapshot)
        } else if let error = error {
          continuation.finish(throwing: error)
        }
      }

      continuation.onTermination = { _ in
        listener.remove()
      }
    }
  }
}

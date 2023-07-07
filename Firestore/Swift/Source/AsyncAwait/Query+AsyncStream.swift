/*
 * Copyright 2023 Google LLC
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

import FirebaseFirestore
import Foundation

@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
public extension Query {
  func snapshotSequence<T>(_ type: T.Type,
                           includeMetadataChanges: Bool = false) -> AsyncThrowingStream<
    [T],
    Error
  > where T: Decodable {
    .init { continuation in
      let listener =
        addSnapshotListener(includeMetadataChanges: includeMetadataChanges) { querySnapshot, error in
          do {
            guard let documents = querySnapshot?.documents else {
              continuation.yield([])
              return
            }
            let results = try documents.map { try $0.data(as: T.self) }
            continuation.yield(results)
          } catch {
            continuation.finish(throwing: error)
          }
        }

      continuation.onTermination = { @Sendable _ in
        listener.remove()
      }
    }
  }
}

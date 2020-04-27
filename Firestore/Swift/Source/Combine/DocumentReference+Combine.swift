/*
 * Copyright 2020 Google LLC
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

#if canImport(Combine)
  import Combine
#endif
import Foundation
import FirebaseFirestore

extension DocumentReference {
  @available(iOS 13.0, macOS 10.15, tvOS 13.0, *)
  func dummyPublisher() -> AnyPublisher<Int, Never> {
    return Just(42).eraseToAnyPublisher()
  }
}

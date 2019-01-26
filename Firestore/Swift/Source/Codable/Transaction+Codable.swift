/*
 * Copyright 2019 Google
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

extension Transaction {
  public func setData<T: Encodable>(_ value: T, forDocument: DocumentReference) {
    do {
      setData(try Firestore.encode(value), forDocument: forDocument)
    } catch let error {
      fatalError("Unable to encode data with Firestore encoder: \(error)")
    }
  }
}

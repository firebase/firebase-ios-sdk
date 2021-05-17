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

import Foundation
import FirebaseDatabase

extension DatabaseReference {
  /** Encode an `Encodable` instance and write it to this Firebase Database location.

     See `Database.Encoder` for more details about the encoding process.

     This will overwrite any data at this location and all child locations.

     The effect of the write will be visible immediately and the corresponding
     events will be triggered. Synchronization of the data to the Firebase Database
     servers will also be started.

   - Parameters:
     - value: An instance of `Encodable` to be encoded to a document.
     - encoder: An encoder instance to use to run the encoding.
     - completion: A block to execute once the value has been successfully
     written to the server. This block will not be called while
     the client is offline, though local changes will be visible
     immediately.
      */
  public func setValue<T: Encodable>(from value: T,
                                     encoder: Database.Encoder = Database.Encoder(),
                                     completion: ((Error?) -> Void)? =
                                       nil) throws {
    let encoded = try encoder.encode(value)
    if let completion = completion {
      setValue(encoded, withCompletionBlock: { error, _ in completion(error) })
    } else {
      setValue(encoded)
    }
  }
}

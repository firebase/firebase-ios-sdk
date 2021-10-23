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
import FirebaseFunctions
import FirebaseSharedSwift

extension HTTPSCallable {
  enum CallableError: Error {
    case internalError
  }
  public func call<T: Encodable, U: Decodable>(_ data: T,
                                               resultAs: U.Type,
                                               encoder: StructureEncoder = StructureEncoder(),
                                               decoder: StructureDecoder = StructureDecoder(),
                                               completion: @escaping (Result<U, Error>) -> Void) throws {
    let encoded = try encoder.encode(data)
    self.call(encoded) { result, error in
      do {
        if let result = result {
          let decoded = try decoder.decode(U.self, from: result.data)
          completion(.success(decoded))
        } else if let error = error {
          completion(.failure(error))
        } else {
          completion(.failure(CallableError.internalError))
        }
      } catch {
        completion(.failure(error))
      }
    }
  }

#if compiler(>=5.5) && canImport(_Concurrency)
  @available(iOS 15, tvOS 15, macOS 12, watchOS 8, *)
  public func call<T: Encodable, U: Decodable>(_ data: T,
                                               resultAs: U.Type,
                                               encoder: StructureEncoder = StructureEncoder(),
                                               decoder: StructureDecoder = StructureDecoder()) async throws -> U {
    let encoded = try encoder.encode(data)
    let result = try await self.call(encoded)
    return try decoder.decode(U.self, from: result.data)
  }
#endif
}

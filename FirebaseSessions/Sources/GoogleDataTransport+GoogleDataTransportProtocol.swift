//
// Copyright 2022 Google LLC
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

import Foundation

@_implementationOnly import GoogleDataTransport

enum GoogleDataTransportProtocolErrors: Error {
  case writeFailure
}

protocol GoogleDataTransportProtocol {
  func logGDTEvent(event: GDTCOREvent, completion: @escaping (Result<Void, Error>) -> Void)
  func eventForTransport() -> GDTCOREvent
}

extension GDTCORTransport: GoogleDataTransportProtocol {
  func logGDTEvent(event: GDTCOREvent, completion: @escaping (Result<Void, Error>) -> Void) {
    sendDataEvent(event) { wasWritten, error in
      if let error = error {
        completion(.failure(error))
      } else if !wasWritten {
        completion(.failure(GoogleDataTransportProtocolErrors.writeFailure))
      } else {
        completion(.success(()))
      }
    }
  }
}

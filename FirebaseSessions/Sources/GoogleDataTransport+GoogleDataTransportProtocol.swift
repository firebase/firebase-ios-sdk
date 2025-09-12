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

@preconcurrency internal import GoogleDataTransport

enum GoogleDataTransportProtocolErrors: Error {
  case writeFailure
}

protocol GoogleDataTransportProtocol: Sendable {
  func logGDTEvent(event: GDTCOREvent,
                   completion: @escaping @Sendable (Result<Void, Error>) -> Void)
  func eventForTransport() -> GDTCOREvent
}

/// Workaround in combo with preconcurrency import of GDT. When GDT's
/// `GDTCORTransport`type conforms to Sendable within the GDT module,
/// this can be removed.
final class GoogleDataTransporter: GoogleDataTransportProtocol {
  private let transporter: GDTCORTransport

  init(mappingID: String,
       transformers: [any GDTCOREventTransformer]?,
       target: GDTCORTarget) {
    transporter = GDTCORTransport(mappingID: mappingID, transformers: transformers, target: target)!
  }

  func logGDTEvent(event: GDTCOREvent,
                   completion: @escaping @Sendable (Result<Void, any Error>) -> Void) {
    transporter.sendDataEvent(event) { wasWritten, error in
      if let error {
        completion(.failure(error))
      } else if !wasWritten {
        completion(.failure(GoogleDataTransportProtocolErrors.writeFailure))
      } else {
        completion(.success(()))
      }
    }
  }

  func eventForTransport() -> GDTCOREvent {
    transporter.eventForTransport()
  }
}

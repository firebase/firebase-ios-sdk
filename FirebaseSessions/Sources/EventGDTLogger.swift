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

protocol EventGDTLoggerProtocol {
  func logEvent(event: SessionStartEvent, completion: @escaping (Result<Void, Error>) -> Void)
}

///
/// EventGDTLogger is responsible for
///   1) Creating GDT Events and logging them to the GoogleDataTransport SDK
///   2) Handling debugging situations (eg. running in Simulator or printing the event to console)
///
class EventGDTLogger: EventGDTLoggerProtocol {
  let googleDataTransport: GoogleDataTransportProtocol

  init(googleDataTransport: GoogleDataTransportProtocol) {
    self.googleDataTransport = googleDataTransport
  }

  /// Logs the event to FireLog, taking into account debugging cases such as running
  /// in simulator.
  func logEvent(event: SessionStartEvent, completion: @escaping (Result<Void, Error>) -> Void) {
    let gdtEvent = googleDataTransport.eventForTransport()
    gdtEvent.dataObject = event
    gdtEvent.qosTier = GDTCOREventQoS.qosDefault
    if ProcessInfo.processInfo.environment["SIMULATOR_UDID"] != nil {
      Logger.logDebug("Logging events using fast QOS due to running on a simulator")
      gdtEvent.qosTier = GDTCOREventQoS.qoSFast
    }

    googleDataTransport.logGDTEvent(event: gdtEvent, completion: completion)
  }
}

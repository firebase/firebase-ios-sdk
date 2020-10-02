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

import WatchKit
import Foundation
import Dispatch

import GoogleDataTransport

class InterfaceController: WKInterfaceController {
  let transport: GDTCORTransport = GDTCORTransport(mappingID: "1234", transformers: nil,
                                                   target: GDTCORTarget.test)!

  override func awake(withContext context: Any?) {
    super.awake(withContext: context)
    // Configure interface objects here.
  }

  override func didDeactivate() {
    // This method is called when watch view controller is no longer visible
    super.didDeactivate()
  }

  @IBAction func generateDataEvent(sender: AnyObject?) {
    print("Generating data event")
    let event: GDTCOREvent = transport.eventForTransport()
    event.dataObject = TestDataObject()
    transport.sendDataEvent(event)
  }

  @IBAction func generateTelemetryEvent(sender: AnyObject?) {
    print("Generating telemetry event")
    let event: GDTCOREvent = transport.eventForTransport()
    event.dataObject = TestDataObject()
    transport.sendTelemetryEvent(event)
  }

  @IBAction func generateHighPriorityEvent(sender: AnyObject?) {
    print("Generating high priority event")
    let event: GDTCOREvent = transport.eventForTransport()
    event.dataObject = TestDataObject()
    event.qosTier = GDTCOREventQoS.qoSFast
    transport.sendDataEvent(event)
  }

  @IBAction func generateWifiOnlyEvent(sender: AnyObject?) {
    print("Generating wifi only event")
    let event: GDTCOREvent = transport.eventForTransport()
    event.dataObject = TestDataObject()
    event.qosTier = GDTCOREventQoS.qoSWifiOnly
    transport.sendDataEvent(event)
  }

  @IBAction func generateDailyEvent(sender: AnyObject?) {
    print("Generating daily event")
    let event: GDTCOREvent = transport.eventForTransport()
    event.dataObject = TestDataObject()
    event.qosTier = GDTCOREventQoS.qoSDaily
    transport.sendDataEvent(event)
  }
}

class TestDataObject: NSObject, GDTCOREventDataObject {
  func transportBytes() -> Data {
    return "Normally, some SDK's data object would populate this. \(Date())"
      .data(using: String.Encoding.utf8)!
  }
}

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

import UIKit
import GoogleDataTransport

class ViewController: UIViewController {
  let transport: GDTTransport = GDTTransport(mappingID: "1234", transformers: nil, target: GDTTarget.test.rawValue)

  override func viewDidLoad() {
    super.viewDidLoad()
    GDTRegistrar.sharedInstance().register(TestUploader(), target: GDTTarget.test)
    GDTRegistrar.sharedInstance().register(TestPrioritizer(), target: GDTTarget.test)
  }

  @IBAction func generateDataEvent() {
    print("Generating data event")
    let event: GDTEvent = transport.eventForTransport()
    event.dataObject = TestDataObject()
    transport.sendDataEvent(event)
  }

  @IBAction func generateTelemetryEvent() {
    print("Generating telemetry event")
    let event: GDTEvent = transport.eventForTransport()
    event.dataObject = TestDataObject()
    transport.sendTelemetryEvent(event)
  }

  @IBAction func generateHighPriorityEvent() {
    print("Generating high priority event")
    let event: GDTEvent = transport.eventForTransport()
    event.dataObject = TestDataObject()
    event.qosTier = GDTEventQoS.qoSFast
    transport.sendDataEvent(event)
  }

  @IBAction func generateWifiOnlyEvent() {
    print("Generating wifi only event")
    let event: GDTEvent = transport.eventForTransport()
    event.dataObject = TestDataObject()
    event.qosTier = GDTEventQoS.qoSWifiOnly
    transport.sendDataEvent(event)
  }

  @IBAction func generateDailyEvent() {
    print("Generating daily event")
    let event: GDTEvent = transport.eventForTransport()
    event.dataObject = TestDataObject()
    event.qosTier = GDTEventQoS.qoSDaily
    transport.sendDataEvent(event)
  }
}

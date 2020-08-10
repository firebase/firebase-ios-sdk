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
import GoogleDataTransport

class InterfaceController: WKInterfaceController {
  var transport: GDTCORTransport = GDTCORTransport(mappingID: "1018", transformers: nil,
                                                   target: GDTCORTarget.FLL)!

  override func awake(withContext context: Any?) {
    super.awake(withContext: context)

    // Configure interface objects here.
  }

  override func willActivate() {
    // This method is called when watch view controller is about to be visible to user
    super.willActivate()
  }

  override func didDeactivate() {
    // This method is called when watch view controller is no longer visible
    super.didDeactivate()
  }

  @IBAction func generateDataEvent(sender: AnyObject?) {
    print("Generating data event on independent watch app")
    let transportToUse = transport
    let event: GDTCOREvent = transportToUse.eventForTransport()
    let testMessage = FirelogTestMessageHolder()
    testMessage.root.identifier = "watchos_test_app_data_event"
    testMessage.root.repeatedID = ["id1", "id2", "id3"]
    testMessage.root.warriorChampionships = 1_111_110
    testMessage.root.subMessage.starTrekData = "technoBabble".data(using: String.Encoding.utf8)!
    testMessage.root.subMessage.repeatedSubMessage = [
      SubMessageTwo(),
      SubMessageTwo(),
    ]
    testMessage.root.subMessage.repeatedSubMessage[0].samplingPercentage = 13.37
    event.dataObject = testMessage
    let encoder = JSONEncoder()
    if let jsonData = try? encoder.encode(["needs_network_connection_info": true]) {
      event.customBytes = jsonData
    }
    transportToUse.sendDataEvent(event)
  }

  @IBAction func generateTelemetryEvent(sender: AnyObject?) {
    print("Generating telemetry event on independent watch app")
    let transportToUse = transport
    let event: GDTCOREvent = transportToUse.eventForTransport()
    let testMessage = FirelogTestMessageHolder()
    testMessage.root.identifier = "watchos_test_app_telemetry_event"
    testMessage.root.warriorChampionships = 1000
    testMessage.root.subMessage.repeatedSubMessage = [
      SubMessageTwo(),
    ]
    event.dataObject = testMessage
    let encoder = JSONEncoder()
    if let jsonData = try? encoder.encode(["needs_network_connection_info": true]) {
      event.customBytes = jsonData
    }
    transportToUse.sendTelemetryEvent(event)
  }

  @IBAction func generateHighPriorityEvent(sender: AnyObject?) {
    print("Generating high priority event on independent watch app")
    let transportToUse = transport
    let event: GDTCOREvent = transportToUse.eventForTransport()
    let testMessage = FirelogTestMessageHolder()
    testMessage.root.identifier = "watchos_test_app_high_priority_event"
    testMessage.root.repeatedID = ["id1", "id2", "id3"]
    testMessage.root.warriorChampionships = 1337
    event.qosTier = GDTCOREventQoS.qoSFast
    event.dataObject = testMessage
    let encoder = JSONEncoder()
    if let jsonData = try? encoder.encode(["needs_network_connection_info": true]) {
      event.customBytes = jsonData
    }
    transportToUse.sendDataEvent(event)
  }

  @IBAction func generateWifiOnlyEvent(sender: AnyObject?) {
    print("Generating wifi only event on independent watch app")
    let transportToUse = transport
    let event: GDTCOREvent = transportToUse.eventForTransport()
    let testMessage = FirelogTestMessageHolder()
    testMessage.root.identifier = "watchos_test_app_wifi_only_event"
    event.qosTier = GDTCOREventQoS.qoSWifiOnly
    event.dataObject = testMessage
    let encoder = JSONEncoder()
    if let jsonData = try? encoder.encode(["needs_network_connection_info": true]) {
      event.customBytes = jsonData
    }
    transportToUse.sendDataEvent(event)
  }

  @IBAction func generateDailyEvent(sender: AnyObject?) {
    print("Generating daily event on independent watch app")
    let transportToUse = transport
    let event: GDTCOREvent = transportToUse.eventForTransport()
    let testMessage = FirelogTestMessageHolder()
    testMessage.root.identifier = "watchos_test_app_daily_event"
    testMessage.root.repeatedID = ["id1", "id2", "id3"]
    testMessage.root.warriorChampionships = 9001
    testMessage.root.subMessage.starTrekData = "engage!".data(using: String.Encoding.utf8)!
    testMessage.root.subMessage.repeatedSubMessage = [
      SubMessageTwo(),
    ]
    testMessage.root.subMessage.repeatedSubMessage[0].samplingPercentage = 100.0
    event.qosTier = GDTCOREventQoS.qoSDaily
    event.dataObject = testMessage
    let encoder = JSONEncoder()
    if let jsonData = try? encoder.encode(["needs_network_connection_info": true]) {
      event.customBytes = jsonData
    }
    transportToUse.sendDataEvent(event)
  }
}

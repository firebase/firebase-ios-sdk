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

import Foundation
import Dispatch
import GoogleDataTransport

public extension ViewController {
  override func viewDidLoad() {
    super.viewDidLoad()
    Globals.SharedViewController = self
  }

  @IBAction func generateDataEvent(sender: AnyObject?) {
    print("Generating data event")
    let transportToUse = transport
    let event: GDTCOREvent = transportToUse.eventForTransport()
    let testMessage = FirelogTestMessageHolder()
    testMessage.root.identifier = "ios_test_app_data_event"
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
    print("Generating telemetry event")
    let transportToUse = transport
    let event: GDTCOREvent = transportToUse.eventForTransport()
    let testMessage = FirelogTestMessageHolder()
    testMessage.root.identifier = "ios_test_app_telemetry_event"
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
    print("Generating high priority event")
    let transportToUse = transport
    let event: GDTCOREvent = transportToUse.eventForTransport()
    let testMessage = FirelogTestMessageHolder()
    testMessage.root.identifier = "ios_test_app_high_priority_event"
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
    print("Generating wifi only event")
    let transportToUse = transport
    let event: GDTCOREvent = transportToUse.eventForTransport()
    let testMessage = FirelogTestMessageHolder()
    testMessage.root.identifier = "ios_test_app_wifi_only_event"
    event.qosTier = GDTCOREventQoS.qoSWifiOnly
    event.dataObject = testMessage
    let encoder = JSONEncoder()
    if let jsonData = try? encoder.encode(["needs_network_connection_info": true]) {
      event.customBytes = jsonData
    }
    transportToUse.sendDataEvent(event)
  }

  @IBAction func generateDailyEvent(sender: AnyObject?) {
    print("Generating daily event")
    let transportToUse = transport
    let event: GDTCOREvent = transportToUse.eventForTransport()
    let testMessage = FirelogTestMessageHolder()
    testMessage.root.identifier = "ios_test_app_daily_event"
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

  func beginMonkeyTest(completion: () -> Void) {
    print("Beginning monkey test")
    Globals.IsMonkeyTesting = true

    let sema: DispatchSemaphore = DispatchSemaphore(value: 0)
    var generateEvents = true
    DispatchQueue.global().asyncAfter(deadline: .now() + Globals.MonkeyTestLength) {
      generateEvents = false
      sema.signal()
    }

    func generateEvent() {
      DispatchQueue.global().asyncAfter(deadline: .now() + Double.random(in: 0 ..< 3.0)) {
        let generationFunctions = [
          self.generateDataEvent,
          self.generateTelemetryEvent,
          self.generateHighPriorityEvent,
          self.generateWifiOnlyEvent,
          self.generateDailyEvent,
        ]
        let randomIndex: Int = Int.random(in: 0 ..< generationFunctions.count)
        generationFunctions[randomIndex](self)
      }
      RunLoop.current.run(until: Date(timeIntervalSinceNow: Double.random(in: 0 ..< 1.5)))
      if generateEvents {
        generateEvent()
      }
    }
    generateEvent()
    sema.wait()
    Globals.IsMonkeyTesting = false
    completion()
  }
}

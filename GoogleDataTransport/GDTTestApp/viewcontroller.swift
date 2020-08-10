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
    GDTCORRegistrar.sharedInstance().register(TestUploader(), target: GDTCORTarget.test)
    Globals.SharedViewController = self
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

  func beginMonkeyTest(completion: () -> Void) {
    print("Beginning monkey test")

    let generateEventsQueue = DispatchQueue(label: "com.google.GDTTestApp.vc.generateEvents")
    let sema: DispatchSemaphore = DispatchSemaphore(value: 0)
    var generateEvents = true
    DispatchQueue.global().asyncAfter(deadline: .now() + Globals.MonkeyTestLength) {
      generateEventsQueue.sync {
        generateEvents = false
      }
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
      var shouldContinueGeneratingEvents: Bool = false
      generateEventsQueue.sync {
        shouldContinueGeneratingEvents = generateEvents
      }
      if shouldContinueGeneratingEvents {
        generateEvent()
      }
    }
    generateEvent()
    sema.wait()
    completion()
  }
}

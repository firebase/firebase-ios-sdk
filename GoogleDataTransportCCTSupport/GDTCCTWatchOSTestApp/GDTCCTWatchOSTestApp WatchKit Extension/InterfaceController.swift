//
//  InterfaceController.swift
//  GDTCCTWatchOSTestApp WatchKit Extension
//
//  Created by Doudou Nan on 2/26/20.
//  Copyright © 2020 Google. All rights reserved.
//

import WatchKit
import Foundation
import GoogleDataTransport


class InterfaceController: WKInterfaceController {
  var transport: GDTCORTransport = GDTCORTransport(mappingID: "1018", transformers: nil, target: GDTCORTarget.CCT.rawValue)!

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
    event.customPrioritizationParams = ["needs_network_connection_info": true]
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
    event.customPrioritizationParams = ["needs_network_connection_info": true]
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
    event.customPrioritizationParams = ["needs_network_connection_info": true]
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
    event.customPrioritizationParams = ["needs_network_connection_info": true]
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
    event.customPrioritizationParams = ["needs_network_connection_info": true]
    transportToUse.sendDataEvent(event)
  }

}

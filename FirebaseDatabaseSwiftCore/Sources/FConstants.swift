//
//  File.swift
//  File
//
//  Created by Morten Bek Ditlevsen on 14/09/2021.
//

import Foundation

let kWireProtocolVersionParam = "v"
let kWebsocketMaxFrameSize = 16384
let kWebsocketKeepaliveInterval: TimeInterval = 45
let kWebsocketConnectTimeout: Double = 30

let kFWPRequestType = "t"
let kFWPRequestTypeData = "d"
let kFWPRequestDataPayload = "d"
let kFWPRequestNumber = "r"
let kFWPRequestPayloadBody = "b"

let kFWPAsyncServerEnvelopeType = "t"
let kFWPAsyncServerEnvelopeData = "d"
let kFWPAsyncServerControlMessage = "c"
let kFWPAsyncServerControlMessageType = "t"
let kFWPAsyncServerControlMessageData = "d"
let kFWPAsyncServerDataMessage = "d"

let kFWPAsyncServerHello = "h"
let kFWPAsyncServerHelloTimestamp = "ts"
let kFWPAsyncServerHelloVersion = "v"
let kFWPAsyncServerHelloConnectedHost = "h"
let kFWPAsyncServerHelloSession = "s"

let kFWPAsyncServerControlMessageShutdown = "s"
let kFWPAsyncServerControlMessageReset = "r"

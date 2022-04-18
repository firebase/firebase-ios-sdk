//
//  File.swift
//  File
//
//  Created by Morten Bek Ditlevsen on 14/09/2021.
//

let kWireProtocolVersionParam = "v"
let kWebsocketMaxFrameSize = 16384
let kWebsocketKeepaliveInterval: Double /* aka TimeInterval defined in Foundation */ = 45
let kWebsocketConnectTimeout: Double = 30

let kPersistentConnectionGetConnectTimeout = 3

let kPersistentConnectionOffline = "Client is offline."


let kPersistentConnReconnectMinDelay = 1.0
let kPersistentConnReconnectMaxDelay = 30.0
let kPersistentConnReconnectMultiplier = 1.3
let kPersistentConnSuccessfulConnectionEstablishedDelay = 30.0

let kFInterruptReasonServerKill = "server_kill"
let kFInterruptReasonWaitingForOpen = "waiting_for_open"
let kFInterruptReasonRepoInterrupt = "repo_interrupt"

let kFWPRequestActionPut = "p"
let kFWPRequestActionMerge = "m"
let kFWPRequestActionGet = "g"
let kFWPRequestActionListen =
    "l" // {"t": "d", "d": {"r": 1, "a": "l", "b": { "p": "/" } } }
let kFWPRequestActionUnlisten = "u"
let kFWPRequestActionStats = "s"
let kFWPRequestActionTaggedListen = "q"
let kFWPRequestActionTaggedUnlisten = "n"
let kFWPRequestActionDisconnectPut = "o"
let kFWPRequestActionDisconnectMerge = "om"
let kFWPRequestActionDisconnectCancel = "oc"
let kFWPRequestActionAuth = "auth"
let kFWPRequestActionAppCheck = "appcheck"
let kFWPRequestActionUnauth = "unauth"
let kFWPRequestAppCheckToken = "token"
let kFWPRequestCredential = "cred"
let kFWPRequestPath = "p"
let kFWPRequestCounters = "c"
let kFWPRequestQueries = "q"
let kFWPRequestTag = "t"
let kFWPRequestData = "d"
let kFWPRequestHash = "h"
let kFWPRequestCompoundHash = "ch"
let kFWPRequestCompoundHashPaths = "ps"
let kFWPRequestCompoundHashHashes = "hs"
let kFWPRequestStatus = "s"

// MARK: -
// MARK: Wire Protocol Envelope Constants

let kFWPRequestType = "t"
let kFWPRequestTypeData = "d"
let kFWPRequestDataPayload = "d"
let kFWPRequestNumber = "r"
let kFWPRequestPayloadBody = "b"
let kFWPRequestError = "error"
let kFWPRequestAction = "a"
let kFWPResponseForRNData = "b"
let kFWPResponseForActionStatus = "s"
let kFWPResponseForActionStatusOk = "ok"
let kFWPResponseForActionStatusFailed = "failed"
let kFWPResponseForActionStatusDataStale = "datastale"
let kFWPResponseForActionData = "d"
let kFWPResponseDataWarnings = "w"
let kFWPAsyncServerAction = "a"
let kFWPAsyncServerPayloadBody = "b"
let kFWPAsyncServerDataUpdate = "d"
let kFWPAsyncServerDataMerge = "m"
let kFWPAsyncServerDataRangeMerge = "rm"
let kFWPAsyncServerAuthRevoked = "ac"
let kFWPASyncServerListenCancelled = "c"
let kFWPAsyncServerSecurityDebug = "sd"
let kFWPAsyncServerDataUpdateBodyPath = "p" // {"a": "d", "b": {"p": "/", "d": "<data>"}}
let kFWPAsyncServerDataUpdateBodyData = "d"
let kFWPAsyncServerDataUpdateStartPath = "s"
let kFWPAsyncServerDataUpdateEndPath = "e"
let kFWPAsyncServerDataUpdateRangeMerge = "m"
let kFWPAsyncServerDataUpdateBodyTag = "t"
let kFWPAsyncServerDataQueries = "q"

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

// MARK: -
// MARK: .info/ constants

let kDotInfoPrefix = ".info"
let kDotInfoConnected = "connected"
let kDotInfoServerTimeOffset = "serverTimeOffset"

// MARK: -
// MARK: Transaction Constants

let kFTransactionMaxRetries = 25
let kFTransactionTooManyRetries = "maxretry"
let kFTransactionNoData = "nodata"
let kFTransactionSet = "set"
let kFTransactionDisconnect = "disconnect"

/*
 * Copyright 2017 Google
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

#import "FConstants.h"

#pragma mark -
#pragma mark Wire Protocol Envelope Constants

NSString *const kFWPRequestType = @"t";
NSString *const kFWPRequestTypeData = @"d";
NSString *const kFWPRequestDataPayload = @"d";
NSString *const kFWPRequestNumber = @"r";
NSString *const kFWPRequestPayloadBody = @"b";
NSString *const kFWPRequestError = @"error";
NSString *const kFWPRequestAction = @"a";
NSString *const kFWPResponseForRNData = @"b";
NSString *const kFWPResponseForActionStatus = @"s";
NSString *const kFWPResponseForActionStatusOk = @"ok";
NSString *const kFWPResponseForActionStatusDataStale = @"datastale";
NSString *const kFWPResponseForActionData = @"d";
NSString *const kFWPResponseDataWarnings = @"w";
NSString *const kFWPAsyncServerAction = @"a";
NSString *const kFWPAsyncServerPayloadBody = @"b";
NSString *const kFWPAsyncServerDataUpdate = @"d";
NSString *const kFWPAsyncServerDataMerge = @"m";
NSString *const kFWPAsyncServerDataRangeMerge = @"rm";
NSString *const kFWPAsyncServerAuthRevoked = @"ac";
NSString *const kFWPASyncServerListenCancelled = @"c";
NSString *const kFWPAsyncServerSecurityDebug = @"sd";
NSString *const kFWPAsyncServerDataUpdateBodyPath =
    @"p"; // {“a”: “d”, “b”: {“p”: “/”, “d”: “<data>”}}
NSString *const kFWPAsyncServerDataUpdateBodyData = @"d";
NSString *const kFWPAsyncServerDataUpdateStartPath = @"s";
NSString *const kFWPAsyncServerDataUpdateEndPath = @"e";
NSString *const kFWPAsyncServerDataUpdateRangeMerge = @"m";
NSString *const kFWPAsyncServerDataUpdateBodyTag = @"t";
NSString *const kFWPAsyncServerDataQueries = @"q";

NSString *const kFWPAsyncServerEnvelopeType = @"t";
NSString *const kFWPAsyncServerEnvelopeData = @"d";
NSString *const kFWPAsyncServerControlMessage = @"c";
NSString *const kFWPAsyncServerControlMessageType = @"t";
NSString *const kFWPAsyncServerControlMessageData = @"d";
NSString *const kFWPAsyncServerDataMessage = @"d";

NSString *const kFWPAsyncServerHello = @"h";
NSString *const kFWPAsyncServerHelloTimestamp = @"ts";
NSString *const kFWPAsyncServerHelloVersion = @"v";
NSString *const kFWPAsyncServerHelloConnectedHost = @"h";
NSString *const kFWPAsyncServerHelloSession = @"s";

NSString *const kFWPAsyncServerControlMessageShutdown = @"s";
NSString *const kFWPAsyncServerControlMessageReset = @"r";

#pragma mark -
#pragma mark Wire Protocol Payload Constants

NSString *const kFWPRequestActionPut = @"p";
NSString *const kFWPRequestActionMerge = @"m";
NSString *const kFWPRequestActionListen =
    @"l"; // {"t": "d", "d": {"r": 1, "a": "l", "b": { "p": "/" } } }
NSString *const kFWPRequestActionUnlisten = @"u";
NSString *const kFWPRequestActionStats = @"s";
NSString *const kFWPRequestActionTaggedListen = @"q";
NSString *const kFWPRequestActionTaggedUnlisten = @"n";
NSString *const kFWPRequestActionDisconnectPut = @"o";
NSString *const kFWPRequestActionDisconnectMerge = @"om";
NSString *const kFWPRequestActionDisconnectCancel = @"oc";
NSString *const kFWPRequestActionAuth = @"auth";
NSString *const kFWPRequestActionUnauth = @"unauth";
NSString *const kFWPRequestCredential = @"cred";
NSString *const kFWPRequestPath = @"p";
NSString *const kFWPRequestCounters = @"c";
NSString *const kFWPRequestQueries = @"q";
NSString *const kFWPRequestTag = @"t";
NSString *const kFWPRequestData = @"d";
NSString *const kFWPRequestHash = @"h";
NSString *const kFWPRequestCompoundHash = @"ch";
NSString *const kFWPRequestCompoundHashPaths = @"ps";
NSString *const kFWPRequestCompoundHashHashes = @"hs";
NSString *const kFWPRequestStatus = @"s";

#pragma mark -
#pragma mark Websock Transport Constants

NSString *const kWireProtocolVersionParam = @"v";
NSString *const kWebsocketProtocolVersion = @"5";
NSString *const kWebsocketServerKillPacket = @"kill";
const int kWebsocketMaxFrameSize = 16384;
NSUInteger const kWebsocketKeepaliveInterval = 45;
NSUInteger const kWebsocketConnectTimeout = 30;

float const kPersistentConnReconnectMinDelay = 1.0;
float const kPersistentConnReconnectMaxDelay = 30.0;
float const kPersistentConnReconnectMultiplier = 1.3f;
float const kPersistentConnSuccessfulConnectionEstablishedDelay = 30.0;

#pragma mark -
#pragma mark Query constants

NSString *const kQueryDefault = @"default";
NSString *const kQueryDefaultObject = @"{}";
NSString *const kViewManagerDictConstView = @"view";
NSString *const kFQPIndexStartValue = @"sp";
NSString *const kFQPIndexStartName = @"sn";
NSString *const kFQPIndexEndValue = @"ep";
NSString *const kFQPIndexEndName = @"en";
NSString *const kFQPLimit = @"l";
NSString *const kFQPViewFrom = @"vf";
NSString *const kFQPViewFromLeft = @"l";
NSString *const kFQPViewFromRight = @"r";
NSString *const kFQPIndex = @"i";

#pragma mark -
#pragma mark Interrupt Reasons

NSString *const kFInterruptReasonServerKill = @"server_kill";
NSString *const kFInterruptReasonWaitingForOpen = @"waiting_for_open";
NSString *const kFInterruptReasonRepoInterrupt = @"repo_interrupt";

#pragma mark -
#pragma mark Payload constants

NSString *const kPayloadPriority = @".priority";
NSString *const kPayloadValue = @".value";
NSString *const kPayloadMetadataPrefix = @".";

#pragma mark -
#pragma mark ServerValue constants

NSString *const kServerValueSubKey = @".sv";
NSString *const kServerValuePriority = @"timestamp";

#pragma mark -
#pragma mark.info/ constants

NSString *const kDotInfoPrefix = @".info";
NSString *const kDotInfoConnected = @"connected";
NSString *const kDotInfoServerTimeOffset = @"serverTimeOffset";

#pragma mark -
#pragma mark ObjectiveC to JavaScript type constants

NSString *const kJavaScriptObject = @"object";
NSString *const kJavaScriptString = @"string";
NSString *const kJavaScriptBoolean = @"boolean";
NSString *const kJavaScriptNumber = @"number";
NSString *const kJavaScriptNull = @"null";
NSString *const kJavaScriptTrue = @"true";
NSString *const kJavaScriptFalse = @"false";

#pragma mark -
#pragma mark Error handling constants

NSString *const kFErrorDomain = @"com.firebase";
NSUInteger const kFAuthError = 1;
NSString *const kFErrorWriteCanceled = @"write_canceled";

#pragma mark -
#pragma mark Validation Constants

NSUInteger const kFirebaseMaxObjectDepth = 1000;
const unsigned int kFirebaseMaxLeafSize = 1024 * 1024 * 10; // 10 MB

#pragma mark -
#pragma mark Transaction Constants

NSUInteger const kFTransactionMaxRetries = 25;
NSString *const kFTransactionTooManyRetries = @"maxretry";
NSString *const kFTransactionNoData = @"nodata";
NSString *const kFTransactionSet = @"set";
NSString *const kFTransactionDisconnect = @"disconnect";

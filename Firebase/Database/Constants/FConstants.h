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

#ifndef Firebase_FConstants_h
#define Firebase_FConstants_h

#import <Foundation/Foundation.h>

#pragma mark -
#pragma mark Wire Protocol Envelope Constants

FOUNDATION_EXPORT NSString *const kFWPRequestType;
FOUNDATION_EXPORT NSString *const kFWPRequestTypeData;
FOUNDATION_EXPORT NSString *const kFWPRequestDataPayload;
FOUNDATION_EXPORT NSString *const kFWPRequestNumber;
FOUNDATION_EXPORT NSString *const kFWPRequestPayloadBody;
FOUNDATION_EXPORT NSString *const kFWPRequestError;
FOUNDATION_EXPORT NSString *const kFWPRequestAction;
FOUNDATION_EXPORT NSString *const kFWPResponseForRNData;
FOUNDATION_EXPORT NSString *const kFWPResponseForActionStatus;
FOUNDATION_EXPORT NSString *const kFWPResponseForActionStatusOk;
FOUNDATION_EXPORT NSString *const kFWPResponseForActionStatusDataStale;
FOUNDATION_EXPORT NSString *const kFWPResponseForActionData;
FOUNDATION_EXPORT NSString *const kFWPResponseDataWarnings;

FOUNDATION_EXPORT NSString *const kFWPAsyncServerAction;
FOUNDATION_EXPORT NSString *const kFWPAsyncServerPayloadBody;
FOUNDATION_EXPORT NSString *const kFWPAsyncServerDataUpdate;
FOUNDATION_EXPORT NSString *const kFWPAsyncServerDataMerge;
FOUNDATION_EXPORT NSString *const kFWPAsyncServerDataRangeMerge;
FOUNDATION_EXPORT NSString *const kFWPAsyncServerAuthRevoked;
FOUNDATION_EXPORT NSString *const kFWPASyncServerListenCancelled;
FOUNDATION_EXPORT NSString *const kFWPAsyncServerSecurityDebug;
FOUNDATION_EXPORT NSString
    *const kFWPAsyncServerDataUpdateBodyPath; // {“a”: “d”, “b”: {“p”: “/”, “d”:
                                              // “<data>”}}
FOUNDATION_EXPORT NSString *const kFWPAsyncServerDataUpdateBodyData;
FOUNDATION_EXPORT NSString *const kFWPAsyncServerDataUpdateStartPath;
FOUNDATION_EXPORT NSString *const kFWPAsyncServerDataUpdateEndPath;
FOUNDATION_EXPORT NSString *const kFWPAsyncServerDataUpdateRangeMerge;
FOUNDATION_EXPORT NSString *const kFWPAsyncServerDataUpdateBodyTag;
FOUNDATION_EXPORT NSString *const kFWPAsyncServerDataQueries;

FOUNDATION_EXPORT NSString *const kFWPAsyncServerEnvelopeType;
FOUNDATION_EXPORT NSString *const kFWPAsyncServerEnvelopeData;
FOUNDATION_EXPORT NSString *const kFWPAsyncServerControlMessage;
FOUNDATION_EXPORT NSString *const kFWPAsyncServerControlMessageType;
FOUNDATION_EXPORT NSString *const kFWPAsyncServerControlMessageData;
FOUNDATION_EXPORT NSString *const kFWPAsyncServerDataMessage;

FOUNDATION_EXPORT NSString *const kFWPAsyncServerHello;
FOUNDATION_EXPORT NSString *const kFWPAsyncServerHelloTimestamp;
FOUNDATION_EXPORT NSString *const kFWPAsyncServerHelloVersion;
FOUNDATION_EXPORT NSString *const kFWPAsyncServerHelloConnectedHost;
FOUNDATION_EXPORT NSString *const kFWPAsyncServerHelloSession;

FOUNDATION_EXPORT NSString *const kFWPAsyncServerControlMessageShutdown;
FOUNDATION_EXPORT NSString *const kFWPAsyncServerControlMessageReset;

#pragma mark -
#pragma mark Wire Protocol Payload Constants

FOUNDATION_EXPORT NSString *const kFWPRequestActionPut;
FOUNDATION_EXPORT NSString *const kFWPRequestActionMerge;
FOUNDATION_EXPORT NSString *const kFWPRequestActionTaggedListen;
FOUNDATION_EXPORT NSString *const kFWPRequestActionTaggedUnlisten;
FOUNDATION_EXPORT NSString
    *const kFWPRequestActionListen; // {"t": "d", "d": {"r": 1, "a": "l", "b": {
                                    // "p": "/" } } }
FOUNDATION_EXPORT NSString *const kFWPRequestActionUnlisten;
FOUNDATION_EXPORT NSString *const kFWPRequestActionStats;
FOUNDATION_EXPORT NSString *const kFWPRequestActionDisconnectPut;
FOUNDATION_EXPORT NSString *const kFWPRequestActionDisconnectMerge;
FOUNDATION_EXPORT NSString *const kFWPRequestActionDisconnectCancel;
FOUNDATION_EXPORT NSString *const kFWPRequestActionAuth;
FOUNDATION_EXPORT NSString *const kFWPRequestActionUnauth;
FOUNDATION_EXPORT NSString *const kFWPRequestCredential;
FOUNDATION_EXPORT NSString *const kFWPRequestPath;
FOUNDATION_EXPORT NSString *const kFWPRequestCounters;
FOUNDATION_EXPORT NSString *const kFWPRequestQueries;
FOUNDATION_EXPORT NSString *const kFWPRequestTag;
FOUNDATION_EXPORT NSString *const kFWPRequestData;
FOUNDATION_EXPORT NSString *const kFWPRequestHash;
FOUNDATION_EXPORT NSString *const kFWPRequestCompoundHash;
FOUNDATION_EXPORT NSString *const kFWPRequestCompoundHashPaths;
FOUNDATION_EXPORT NSString *const kFWPRequestCompoundHashHashes;
FOUNDATION_EXPORT NSString *const kFWPRequestStatus;

#pragma mark -
#pragma mark Websock Transport Constants

FOUNDATION_EXPORT NSString *const kWireProtocolVersionParam;
FOUNDATION_EXPORT NSString *const kWebsocketProtocolVersion;
FOUNDATION_EXPORT NSString *const kWebsocketServerKillPacket;
FOUNDATION_EXPORT const int kWebsocketMaxFrameSize;
FOUNDATION_EXPORT NSUInteger const kWebsocketKeepaliveInterval;
FOUNDATION_EXPORT NSUInteger const kWebsocketConnectTimeout;

FOUNDATION_EXPORT float const kPersistentConnReconnectMinDelay;
FOUNDATION_EXPORT float const kPersistentConnReconnectMaxDelay;
FOUNDATION_EXPORT float const kPersistentConnReconnectMultiplier;
FOUNDATION_EXPORT float const
    kPersistentConnSuccessfulConnectionEstablishedDelay;

#pragma mark -
#pragma mark Query / QueryParams constants

FOUNDATION_EXPORT NSString *const kQueryDefault;
FOUNDATION_EXPORT NSString *const kQueryDefaultObject;
FOUNDATION_EXPORT NSString *const kViewManagerDictConstView;
FOUNDATION_EXPORT NSString *const kFQPIndexStartValue;
FOUNDATION_EXPORT NSString *const kFQPIndexStartName;
FOUNDATION_EXPORT NSString *const kFQPIndexEndValue;
FOUNDATION_EXPORT NSString *const kFQPIndexEndName;
FOUNDATION_EXPORT NSString *const kFQPLimit;
FOUNDATION_EXPORT NSString *const kFQPViewFrom;
FOUNDATION_EXPORT NSString *const kFQPViewFromLeft;
FOUNDATION_EXPORT NSString *const kFQPViewFromRight;
FOUNDATION_EXPORT NSString *const kFQPIndex;

#pragma mark -
#pragma mark Interrupt Reasons

FOUNDATION_EXPORT NSString *const kFInterruptReasonServerKill;
FOUNDATION_EXPORT NSString *const kFInterruptReasonWaitingForOpen;
FOUNDATION_EXPORT NSString *const kFInterruptReasonRepoInterrupt;
FOUNDATION_EXPORT NSString *const kFInterruptReasonAuthExpired;

#pragma mark -
#pragma mark Payload constants

FOUNDATION_EXPORT NSString *const kPayloadPriority;
FOUNDATION_EXPORT NSString *const kPayloadValue;
FOUNDATION_EXPORT NSString *const kPayloadMetadataPrefix;

#pragma mark -
#pragma mark ServerValue constants

FOUNDATION_EXPORT NSString *const kServerValueSubKey;
FOUNDATION_EXPORT NSString *const kServerValuePriority;

#pragma mark -
#pragma mark.info/ constants

FOUNDATION_EXPORT NSString *const kDotInfoPrefix;
FOUNDATION_EXPORT NSString *const kDotInfoConnected;
FOUNDATION_EXPORT NSString *const kDotInfoServerTimeOffset;

#pragma mark -
#pragma mark ObjectiveC to JavaScript type constants

FOUNDATION_EXPORT NSString *const kJavaScriptObject;
FOUNDATION_EXPORT NSString *const kJavaScriptString;
FOUNDATION_EXPORT NSString *const kJavaScriptBoolean;
FOUNDATION_EXPORT NSString *const kJavaScriptNumber;
FOUNDATION_EXPORT NSString *const kJavaScriptNull;
FOUNDATION_EXPORT NSString *const kJavaScriptTrue;
FOUNDATION_EXPORT NSString *const kJavaScriptFalse;

#pragma mark -
#pragma mark Error handling constants

FOUNDATION_EXPORT NSString *const kFErrorDomain;
FOUNDATION_EXPORT NSUInteger const kFAuthError;
FOUNDATION_EXPORT NSString *const kFErrorWriteCanceled;

#pragma mark -
#pragma mark Validation Constants

FOUNDATION_EXPORT NSUInteger const kFirebaseMaxObjectDepth;
FOUNDATION_EXPORT const unsigned int kFirebaseMaxLeafSize;

#pragma mark -
#pragma mark Transaction Constants

FOUNDATION_EXPORT NSUInteger const kFTransactionMaxRetries;
FOUNDATION_EXPORT NSString *const kFTransactionTooManyRetries;
FOUNDATION_EXPORT NSString *const kFTransactionNoData;
FOUNDATION_EXPORT NSString *const kFTransactionSet;
FOUNDATION_EXPORT NSString *const kFTransactionDisconnect;

#endif

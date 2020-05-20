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

#import <Foundation/Foundation.h>

typedef NS_ENUM(int8_t, FIRMessagingProtoTag) {
  kFIRMessagingProtoTagInvalid = -1,
  kFIRMessagingProtoTagHeartbeatPing = 0,
  kFIRMessagingProtoTagHeartbeatAck = 1,
  kFIRMessagingProtoTagLoginRequest = 2,
  kFIRMessagingProtoTagLoginResponse = 3,
  kFIRMessagingProtoTagClose = 4,
  kFIRMessagingProtoTagIqStanza = 7,
  kFIRMessagingProtoTagDataMessageStanza = 8,
};

@class GPBMessage;

#pragma mark - Protocol Buffers

FOUNDATION_EXPORT FIRMessagingProtoTag FIRMessagingGetTagForProto(GPBMessage *protoClass);
FOUNDATION_EXPORT Class FIRMessagingGetClassForTag(FIRMessagingProtoTag tag);

#pragma mark - MCS

FOUNDATION_EXPORT NSString *FIRMessagingGetRmq2Id(GPBMessage *proto);
FOUNDATION_EXPORT void FIRMessagingSetRmq2Id(GPBMessage *proto, NSString *pID);
FOUNDATION_EXPORT int FIRMessagingGetLastStreamId(GPBMessage *proto);
FOUNDATION_EXPORT void FIRMessagingSetLastStreamId(GPBMessage *proto, int sid);

#pragma mark - Time

FOUNDATION_EXPORT int64_t FIRMessagingCurrentTimestampInSeconds(void);
FOUNDATION_EXPORT int64_t FIRMessagingCurrentTimestampInMilliseconds(void);

#pragma mark - App Info

FOUNDATION_EXPORT NSString *FIRMessagingCurrentAppVersion(void);
FOUNDATION_EXPORT NSString *FIRMessagingAppIdentifier(void);

#pragma mark - Others

FOUNDATION_EXPORT uint64_t FIRMessagingGetFreeDiskSpaceInMB(void);
FOUNDATION_EXPORT NSSearchPathDirectory FIRMessagingSupportedDirectory(void);

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

#import "Firebase/Messaging/FIRMessagingUtilities.h"

#import "Firebase/Messaging/Protos/GtalkCore.pbobjc.h"

#import "Firebase/Messaging/FIRMessagingLogger.h"

#import <GoogleUtilities/GULAppEnvironmentUtil.h>

// Convert the macro to a string
#define STR_EXPAND(x) #x
#define STR(x) STR_EXPAND(x)

static const uint64_t kBytesToMegabytesDivisor = 1024 * 1024LL;

#pragma mark - Protocol Buffers

FIRMessagingProtoTag FIRMessagingGetTagForProto(GPBMessage *proto) {
  if ([proto isKindOfClass:[GtalkHeartbeatPing class]]) {
    return kFIRMessagingProtoTagHeartbeatPing;
  } else if ([proto isKindOfClass:[GtalkHeartbeatAck class]]) {
    return kFIRMessagingProtoTagHeartbeatAck;
  } else if ([proto isKindOfClass:[GtalkLoginRequest class]]) {
    return kFIRMessagingProtoTagLoginRequest;
  } else if ([proto isKindOfClass:[GtalkLoginResponse class]]) {
    return kFIRMessagingProtoTagLoginResponse;
  } else if ([proto isKindOfClass:[GtalkClose class]]) {
    return kFIRMessagingProtoTagClose;
  } else if ([proto isKindOfClass:[GtalkIqStanza class]]) {
    return kFIRMessagingProtoTagIqStanza;
  } else if ([proto isKindOfClass:[GtalkDataMessageStanza class]]) {
    return kFIRMessagingProtoTagDataMessageStanza;
  }
  return kFIRMessagingProtoTagInvalid;
}

Class FIRMessagingGetClassForTag(FIRMessagingProtoTag tag) {
  switch (tag) {
    case kFIRMessagingProtoTagHeartbeatPing:
      return GtalkHeartbeatPing.class;
    case kFIRMessagingProtoTagHeartbeatAck:
      return GtalkHeartbeatAck.class;
    case kFIRMessagingProtoTagLoginRequest:
      return GtalkLoginRequest.class;
    case kFIRMessagingProtoTagLoginResponse:
      return GtalkLoginResponse.class;
    case kFIRMessagingProtoTagClose:
      return GtalkClose.class;
    case kFIRMessagingProtoTagIqStanza:
      return GtalkIqStanza.class;
    case kFIRMessagingProtoTagDataMessageStanza:
      return GtalkDataMessageStanza.class;
    case kFIRMessagingProtoTagInvalid:
      return NSNull.class;
  }
  return NSNull.class;
}

#pragma mark - MCS

NSString *FIRMessagingGetRmq2Id(GPBMessage *proto) {
  if ([proto isKindOfClass:[GtalkIqStanza class]]) {
    if (((GtalkIqStanza *)proto).hasPersistentId) {
      return ((GtalkIqStanza *)proto).persistentId;
    }
  } else if ([proto isKindOfClass:[GtalkDataMessageStanza class]]) {
    if (((GtalkDataMessageStanza *)proto).hasPersistentId) {
      return ((GtalkDataMessageStanza *)proto).persistentId;
    }
  }
  return nil;
}

void FIRMessagingSetRmq2Id(GPBMessage *proto, NSString *pID) {
  if ([proto isKindOfClass:[GtalkIqStanza class]]) {
    ((GtalkIqStanza *)proto).persistentId = pID;
  } else if ([proto isKindOfClass:[GtalkDataMessageStanza class]]) {
    ((GtalkDataMessageStanza *)proto).persistentId = pID;
  }
}

int FIRMessagingGetLastStreamId(GPBMessage *proto) {
  if ([proto isKindOfClass:[GtalkIqStanza class]]) {
    if (((GtalkIqStanza *)proto).hasLastStreamIdReceived) {
      return ((GtalkIqStanza *)proto).lastStreamIdReceived;
    }
  } else if ([proto isKindOfClass:[GtalkDataMessageStanza class]]) {
    if (((GtalkDataMessageStanza *)proto).hasLastStreamIdReceived) {
      return ((GtalkDataMessageStanza *)proto).lastStreamIdReceived;
    }
  } else if ([proto isKindOfClass:[GtalkHeartbeatPing class]]) {
    if (((GtalkHeartbeatPing *)proto).hasLastStreamIdReceived) {
      return ((GtalkHeartbeatPing *)proto).lastStreamIdReceived;
    }
  } else if ([proto isKindOfClass:[GtalkHeartbeatAck class]]) {
    if (((GtalkHeartbeatAck *)proto).hasLastStreamIdReceived) {
      return ((GtalkHeartbeatAck *)proto).lastStreamIdReceived;
    }
  }
  return -1;
}

void FIRMessagingSetLastStreamId(GPBMessage *proto, int sid) {
  if ([proto isKindOfClass:[GtalkIqStanza class]]) {
    ((GtalkIqStanza *)proto).lastStreamIdReceived = sid;
  } else if ([proto isKindOfClass:[GtalkDataMessageStanza class]]) {
    ((GtalkDataMessageStanza *)proto).lastStreamIdReceived = sid;
  } else if ([proto isKindOfClass:[GtalkHeartbeatPing class]]) {
    ((GtalkHeartbeatPing *)proto).lastStreamIdReceived = sid;
  } else if ([proto isKindOfClass:[GtalkHeartbeatAck class]]) {
    ((GtalkHeartbeatAck *)proto).lastStreamIdReceived = sid;
  }
}

#pragma mark - Time

int64_t FIRMessagingCurrentTimestampInSeconds(void) {
  return (int64_t)[[NSDate date] timeIntervalSince1970];
}

int64_t FIRMessagingCurrentTimestampInMilliseconds(void) {
  return (int64_t)(FIRMessagingCurrentTimestampInSeconds() * 1000.0);
}

#pragma mark - App Info

NSString *FIRMessagingCurrentAppVersion(void) {
  NSString *version = [[NSBundle mainBundle] infoDictionary][@"CFBundleShortVersionString"];
  if (![version length]) {
    FIRMessagingLoggerError(kFIRMessagingMessageCodeUtilities000,
                            @"Could not find current app version");
    return @"";
  }
  return version;
}

NSString *FIRMessagingBundleIDByRemovingLastPartFrom(NSString *bundleID) {
  NSString *bundleIDComponentsSeparator = @".";

  NSMutableArray<NSString *> *bundleIDComponents =
      [[bundleID componentsSeparatedByString:bundleIDComponentsSeparator] mutableCopy];
  [bundleIDComponents removeLastObject];

  return [bundleIDComponents componentsJoinedByString:bundleIDComponentsSeparator];
}

NSString *FIRMessagingAppIdentifier(void) {
  NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
#if TARGET_OS_WATCH
  // The code is running in watchKit extension target but the actually bundleID is in the watchKit
  // target. So we need to remove the last part of the bundle ID in watchKit extension to match
  // the one in watchKit target.
  return FIRMessagingBundleIDByRemovingLastPartFrom(bundleID);
#else
  return bundleID;
#endif
}

uint64_t FIRMessagingGetFreeDiskSpaceInMB(void) {
  NSError *error;
  NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);

  NSDictionary *attributesMap =
      [[NSFileManager defaultManager] attributesOfFileSystemForPath:[paths lastObject]
                                                              error:&error];
  if (attributesMap) {
    uint64_t totalSizeInBytes __unused = [attributesMap[NSFileSystemSize] longLongValue];
    uint64_t freeSizeInBytes = [attributesMap[NSFileSystemFreeSize] longLongValue];
    FIRMessagingLoggerDebug(
        kFIRMessagingMessageCodeUtilities001, @"Device has capacity %llu MB with %llu MB free.",
        totalSizeInBytes / kBytesToMegabytesDivisor, freeSizeInBytes / kBytesToMegabytesDivisor);
    return ((double)freeSizeInBytes) / kBytesToMegabytesDivisor;
  } else {
    FIRMessagingLoggerError(kFIRMessagingMessageCodeUtilities002,
                            @"Error in retreiving device's free memory %@", error);
    return 0;
  }
}

NSSearchPathDirectory FIRMessagingSupportedDirectory(void) {
#if TARGET_OS_TV
  return NSCachesDirectory;
#else
  return NSApplicationSupportDirectory;
#endif
}

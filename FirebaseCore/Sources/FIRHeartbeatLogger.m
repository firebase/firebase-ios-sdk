// Copyright 2021 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import <Foundation/Foundation.h>

#import "FirebaseCore/Sources/Private/FIRHeartbeatLogger.h"

#if SWIFT_PACKAGE
@import HeartbeatLogging;
#else
#import <FirebaseCore/FirebaseCore-Swift.h>
#endif  // SWIFT_PACKAGE

#import "FirebaseCore/Sources/Private/FirebaseCoreInternal.h"

NSString *FIRHeaderValueFromHeartbeatsPayload(FIRHeartbeatsPayload *heartbeatsPayload) {
  return [heartbeatsPayload headerValue];
}

@interface FIRHeartbeatLogger ()
@property(nonatomic, readonly) FIRHeartbeatController *heartbeatController;
@property(copy, readonly) NSString * (^userAgentProvider)(void);
@end

@implementation FIRHeartbeatLogger

- (instancetype)initWithAppID:(NSString *)appID {
  return [self initWithAppID:appID userAgentProvider:[[self class] currentUserAgentProvider]];
}

- (instancetype)initWithAppID:(NSString *)appID
            userAgentProvider:(NSString * (^)(void))userAgentProvider {
  self = [super init];
  if (self) {
    _heartbeatController = [[FIRHeartbeatController alloc] initWithId:[appID copy]];
    _userAgentProvider = [userAgentProvider copy];
  }
  return self;
}

+ (NSString * (^)())currentUserAgentProvider {
  return ^NSString * {
    return [FIRApp firebaseUserAgent];
  };
}

- (void)log {
  NSString *userAgent = _userAgentProvider();
  [_heartbeatController log:userAgent];
}

- (FIRHeartbeatsPayload *)flushHeartbeatsIntoPayload {
  FIRHeartbeatsPayload *payload = [_heartbeatController flush];
  return payload;
}

// TODO: Rename to `heartbeatCodeForToday` in future PR's.
- (FIRHeartbeatInfoCode)heartbeatCode {
  FIRHeartbeatsPayload *todaysHeartbeatPayload = [_heartbeatController flushHeartbeatFromToday];

  // If there's a heartbeat for today, the payload's header value will be non-empty.
  if ([[todaysHeartbeatPayload headerValue] length] > 0) {
    return FIRHeartbeatInfoCodeGlobal;
  } else {
    return FIRHeartbeatInfoCodeNone;
  }
}

@end

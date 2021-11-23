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

@interface FIRHeartbeatLogger
@property(nonatomic, readonly) FIRHeartbeatController *heartbeatController;
@end

@implementation FIRHeartbeatLogger

- (instancetype)initWithAppID:(NSString *)appID {
  self = [super init];
  if (self) {
    _heartbeatController = [[FIRHeartbeatController alloc] initWithId:appID];
  }
  return self;
}

- (void)log {
  NSString *agent = [FIRApp firebaseUserAgent];
  [_heartbeatController log:agent];
}

- (NSString *)flushAndGetFlushedHeartbeatsString {
  NSString *payloadString = @"";

  if (/* needsV1ToV2Migration */ YES) {
    payloadString = @"";  // Get from old V1 storage.
    // needsV1ToV2Migration = NO;
  }

  if ([payloadString length] == 0) {
    FIRHeartbeatsPayload *payload = [_heartbeatController flush];
    payloadString = [payload headerValue];
  }

  return payloadString;
}

@end

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

// TODO: Remove in future PR when `FIRHeartbeatInfo` symbol is removed.
#import "FirebaseCore/Sources/Private/FIRHeartbeatInfo.h"

NS_ASSUME_NONNULL_BEGIN

@class FIRHeartbeatsPayload;

/// <#Description#>
/// @param heartbeatsPayload <#heartbeatsPayload description#>
NSString *FIRHeaderValueFromHeartbeatsPayload(FIRHeartbeatsPayload *heartbeatsPayload);

/// A thread safe, synchronized object that logs and flushes platform logging info.
@interface FIRHeartbeatLogger : NSObject

// TODO: Decide how clients get an instance.

- (instancetype)initWithAppID:(NSString *)appID;

/// Asynchronously logs a new heartbeat corresponding to the Firebase User Agent, if needed.
///
/// @note This API is thread-safe.
- (void)log;

/// Flushes heartbeats from storage into a structured payload of heartbeats.
///
/// This API is for clients using platform logging V2.
///
/// @note This API is thread-safe.
/// @return A payload of heartbeats.
- (FIRHeartbeatsPayload *)flushHeartbeatsIntoPayload;

/// Gets the corresponding heartbeat code for the current heartbeat storage state.
///
/// This API is for clients using platform logging V1.
///
/// @note This API is thread-safe.
/// @return Heartbeat code indicating whether or not there is an unsent global heartbeat.
- (FIRHeartbeatInfoCode)heartbeatCode;

@end

NS_ASSUME_NONNULL_END

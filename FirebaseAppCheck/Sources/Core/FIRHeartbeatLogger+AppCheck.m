/*
 * Copyright 2023 Google LLC
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

#import "FirebaseAppCheck/Sources/Core/FIRHeartbeatLogger+AppCheck.h"

/// The HTTP request header key for a heartbeat logging payload.
static NSString *const kFIRHeartbeatLoggerPayloadHeaderKey = @"X-firebase-client";

@implementation FIRHeartbeatLogger (AppCheck)

- (GACAppCheckAPIRequestHook)requestHook {
  return ^(NSMutableURLRequest *request) {
    NSString *heartbeatsValue = [self headerValue];
    if (heartbeatsValue) {
      [request setValue:heartbeatsValue forHTTPHeaderField:kFIRHeartbeatLoggerPayloadHeaderKey];
    }
  };
}

@end

/// Stub used to force the linker to include the categories in this file.
void FIRInclude_FIRHeartbeatLogger_AppCheck_Category(void) {
}

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

#import "FIRMessagingConnection.h"

/**
 * A bunch of different fake connections are used to simulate various connection behaviours.
 * A fake connection that successfully conects to remote host.
 */
// TODO: Split FIRMessagingConnection to make it more testable.
@interface FIRMessagingFakeConnection : FIRMessagingConnection

@property(nonatomic, readwrite, assign) BOOL shouldFakeSuccessLogin;

// timeout caused by heartbeat failure (defaults to 0.5s)
@property(nonatomic, readwrite, assign) NSTimeInterval fakeConnectionTimeout;

/**
 * Should stub the socket disconnect to not fail when called
 */
- (void)mockSocketDisconnect;

/**
 * Calls disconnect on the socket(which should theoretically be mocked by the above method) and
 * let the socket delegate know that it has been disconnected.
 */
- (void)disconnectNow;

/**
 * The fake host to connect to.
 */
+ (NSString *)fakeHost;

/**
 * The fake port used to connect.
 */
+ (int)fakePort;

@end

/**
 * A fake connection that simulates failure a certain number of times before success.
 */
// TODO: Coalesce this with the FIRMessagingFakeConnection itself.
@interface FIRMessagingFakeFailConnection : FIRMessagingFakeConnection

@property(nonatomic, readwrite, assign) int failCount;
@property(nonatomic, readwrite, assign) int signInRequests;

@end

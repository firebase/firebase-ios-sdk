/*
 * Copyright 2026 Google LLC
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

#import <GoogleUtilities/GULUserDefaults.h>
#import <XCTest/XCTest.h>

#import "FirebaseDatabase/Sources/Core/FRepoInfo.h"
#import "FirebaseDatabase/Sources/Realtime/FConnection.h"

// The configured host of the connection, and the user defaults key that
// FRepoInfo saves the host from the server under.
static NSString *const kConfiguredHost = @"connection-host-test.firebaseio.com";
static NSString *const kHostKey = @"firebase:host:connection-host-test.firebaseio.com";
// A host that the server provides.
static NSString *const kServerHost = @"s-usc1a-nss-2001.firebaseio.com";

// Records the calls that a connection makes to its delegate.
@interface FConnectionHostTestDelegate : NSObject <FConnectionDelegate>
@property(nonatomic) BOOL isReady;
@property(nonatomic) NSMutableArray<NSNumber *> *disconnectReasons;
@end

@implementation FConnectionHostTestDelegate
- (instancetype)init {
  self = [super init];
  if (self) {
    _disconnectReasons = [NSMutableArray array];
  }
  return self;
}
- (void)onReady:(FConnection *)fconnection
         atTime:(NSNumber *)timestamp
      sessionID:(NSString *)sessionID {
  self.isReady = YES;
}
- (void)onDataMessage:(FConnection *)fconnection withMessage:(NSDictionary *)message {
}
- (void)onDisconnect:(FConnection *)fconnection withReason:(FDisconnectReason)reason {
  [self.disconnectReasons addObject:@(reason)];
}
- (void)onKill:(FConnection *)fconnection withReason:(NSString *)reason {
}
@end

// Tests how a connection handles the hosts in reset and handshake messages,
// which FRepoInfo saves and uses for the next connections.
@interface FConnectionHostTest : XCTestCase
@property(nonatomic) FRepoInfo *repoInfo;
@property(nonatomic) FConnectionHostTestDelegate *delegate;
@property(nonatomic) FConnection *connection;
@end

@implementation FConnectionHostTest

- (void)setUp {
  [super setUp];
  [[GULUserDefaults standardUserDefaults] removeObjectForKey:kHostKey];
  self.repoInfo = [[FRepoInfo alloc] initWithHost:kConfiguredHost
                                         isSecure:YES
                                    withNamespace:@"connection-host-test"];
  self.delegate = [[FConnectionHostTestDelegate alloc] init];
  self.connection = [[FConnection alloc] initWith:self.repoInfo
                                 andDispatchQueue:dispatch_get_main_queue()
                                      googleAppID:@"1:1234:ios:1234"
                                    lastSessionID:nil
                                    appCheckToken:nil];
  self.connection.delegate = self.delegate;
}

- (void)tearDown {
  [[GULUserDefaults standardUserDefaults] removeObjectForKey:kHostKey];
  // XCTest keeps every test case alive until the end of the run.
  self.connection = nil;
  self.delegate = nil;
  self.repoInfo = nil;
  [super tearDown];
}

- (id)savedHost {
  return [[GULUserDefaults standardUserDefaults] objectForKey:kHostKey];
}

- (NSDictionary *)resetToHost:(id)host {
  return @{@"t" : @"c", @"d" : @{@"t" : @"r", @"d" : host}};
}

- (NSDictionary *)handshakeWithHost:(NSString *)host {
  NSMutableDictionary *handshake =
      [@{@"ts" : @1700000000000, @"v" : @"5", @"s" : @"session-id"} mutableCopy];
  handshake[@"h"] = host;
  return @{@"t" : @"c", @"d" : @{@"t" : @"h", @"d" : handshake}};
}

// A reset to a host that can't be used in a URL used to be saved, and the app
// then crashed when it reconnected, and at every launch. The connection should
// go back to the configured host instead, and close without SERVER_RESET so
// that the reconnect uses the normal backoff.
- (void)checkResetToInvalidHost:(id)host {
  // A host from an earlier redirect.
  self.repoInfo.internalHost = kServerHost;

  [self.connection onMessage:nil withMessage:[self resetToHost:host]];

  XCTAssertEqualObjects(self.delegate.disconnectReasons, @[ @(DISCONNECT_REASON_OTHER) ]);
  XCTAssertEqualObjects(self.repoInfo.internalHost, kConfiguredHost);
  XCTAssertNil([self savedHost]);
}

- (void)testResetToInvalidHostRestoresConfiguredHost {
  [self checkResetToInvalidHost:@"bad host"];
}

// A host that isn't a string isn't valid either.
- (void)testResetToNumberRestoresConfiguredHost {
  [self checkResetToInvalidHost:@5];
}

- (void)testResetToNullRestoresConfiguredHost {
  [self checkResetToInvalidHost:[NSNull null]];
}

- (void)testResetToValidHostSavesHost {
  [self.connection onMessage:nil withMessage:[self resetToHost:kServerHost]];

  XCTAssertEqualObjects(self.delegate.disconnectReasons, @[ @(DISCONNECT_REASON_SERVER_RESET) ]);
  XCTAssertEqualObjects(self.repoInfo.internalHost, kServerHost);
  XCTAssertEqualObjects([self savedHost], kServerHost);
}

// A handshake host that can't be used in a URL used to be saved too. It
// should be ignored without failing the handshake.
- (void)testHandshakeWithInvalidHostKeepsHost {
  [self.connection onMessage:nil withMessage:[self handshakeWithHost:@"bad host"]];

  XCTAssertTrue(self.delegate.isReady);
  XCTAssertEqualObjects(self.delegate.disconnectReasons, @[]);
  XCTAssertEqualObjects(self.repoInfo.internalHost, kConfiguredHost);
  XCTAssertNil([self savedHost]);
}

- (void)testHandshakeWithoutHostKeepsSavedHost {
  self.repoInfo.internalHost = kServerHost;

  [self.connection onMessage:nil withMessage:[self handshakeWithHost:nil]];

  XCTAssertTrue(self.delegate.isReady);
  XCTAssertEqualObjects(self.repoInfo.internalHost, kServerHost);
  XCTAssertEqualObjects([self savedHost], kServerHost);
}

- (void)testHandshakeWithValidHostSavesHost {
  [self.connection onMessage:nil withMessage:[self handshakeWithHost:kServerHost]];

  XCTAssertTrue(self.delegate.isReady);
  XCTAssertEqualObjects(self.repoInfo.internalHost, kServerHost);
  XCTAssertEqualObjects([self savedHost], kServerHost);
}

@end

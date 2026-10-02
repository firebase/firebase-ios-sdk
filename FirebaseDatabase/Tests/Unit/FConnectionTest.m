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

#import <XCTest/XCTest.h>

#import "FirebaseDatabase/Sources/Constants/FConstants.h"
#import "FirebaseDatabase/Sources/Core/FRepoInfo.h"
#import "FirebaseDatabase/Sources/Realtime/FConnection.h"

// onControl: and onHandshake: are internal to FConnection; expose them so the
// malformed-frame handling can be exercised directly.
@interface FConnection (Testing)

- (void)onControl:(NSDictionary *)message;
- (void)onHandshake:(NSDictionary *)handshake;

@end

@interface FConnectionTestDelegate : NSObject <FConnectionDelegate>
@property(nonatomic) BOOL didBecomeReady;
@property(nonatomic) BOOL didReceiveDataMessage;
@end

@implementation FConnectionTestDelegate
- (void)onReady:(FConnection *)fconnection
         atTime:(NSNumber *)timestamp
      sessionID:(NSString *)sessionID {
  self.didBecomeReady = YES;
}
- (void)onDataMessage:(FConnection *)fconnection withMessage:(NSDictionary *)message {
  self.didReceiveDataMessage = YES;
}
- (void)onDisconnect:(FConnection *)fconnection withReason:(FDisconnectReason)reason {
}
- (void)onKill:(FConnection *)fconnection withReason:(NSString *)reason {
}
@end

@interface FConnectionTest : XCTestCase
@end

@implementation FConnectionTest

- (FConnection *)connectionWithDelegate:(FConnectionTestDelegate *)delegate {
  FRepoInfo *info = [[FRepoInfo alloc] initWithHost:@"foo.firebaseio.com"
                                           isSecure:YES
                                      withNamespace:@"foo"];
  FConnection *connection = [[FConnection alloc] initWith:info
                                         andDispatchQueue:dispatch_get_main_queue()
                                              googleAppID:@"1:1234:ios:1234"
                                            lastSessionID:nil
                                            appCheckToken:nil];
  connection.delegate = delegate;
  return connection;
}

// A frame is parsed straight from server JSON, so a non-object frame (e.g. a
// JSON array) does not respond to -objectForKey: and would previously crash the
// client. It should now be ignored.
- (void)testNonDictionaryServerMessageIsIgnored {
  FConnectionTestDelegate *delegate = [[FConnectionTestDelegate alloc] init];
  FConnection *connection = [self connectionWithDelegate:delegate];

  NSArray *arrayFrame = @[ @1, @2, @3 ];
  XCTAssertNoThrow([connection onMessage:nil withMessage:(id)arrayFrame]);
  XCTAssertNoThrow([connection onMessage:nil withMessage:(id) @"not a dict"]);
  XCTAssertFalse(delegate.didReceiveDataMessage);
}

- (void)testControlMessageWithMalformedTypeIsIgnored {
  FConnectionTestDelegate *delegate = [[FConnectionTestDelegate alloc] init];
  FConnection *connection = [self connectionWithDelegate:delegate];

  // Control payload is not a JSON object.
  XCTAssertNoThrow([connection onControl:(id) @"not a dict"]);
  // Control payload has a non-string type.
  NSDictionary *nonStringType = @{kFWPAsyncServerControlMessageType : @5};
  XCTAssertNoThrow([connection onControl:nonStringType]);
}

- (void)testMalformedHandshakeIsIgnored {
  FConnectionTestDelegate *delegate = [[FConnectionTestDelegate alloc] init];
  FConnection *connection = [self connectionWithDelegate:delegate];

  // Handshake is not a JSON object.
  XCTAssertNoThrow([connection onHandshake:(id) @"not a dict"]);
  // Handshake with a non-numeric timestamp.
  NSDictionary *nonNumericTimestamp = @{kFWPAsyncServerHelloTimestamp : @"soon"};
  XCTAssertNoThrow([connection onHandshake:nonNumericTimestamp]);
  // Handshake with a non-string host.
  NSDictionary *nonStringHost =
      @{kFWPAsyncServerHelloTimestamp : @123, kFWPAsyncServerHelloConnectedHost : @5};
  XCTAssertNoThrow([connection onHandshake:nonStringHost]);

  XCTAssertFalse(delegate.didBecomeReady);
}

@end

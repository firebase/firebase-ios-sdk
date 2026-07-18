/*
 * Copyright 2024 Google
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

#import "FirebaseDatabase/Sources/Core/FRepoInfo.h"
#import "FirebaseDatabase/Sources/Realtime/FWebSocketConnection.h"

#if !TARGET_OS_WATCH

@interface FWebSocketConnectionTestDelegate : NSObject <FWebSocketDelegate>
@property(nonatomic) BOOL receivedMessage;
@end

@implementation FWebSocketConnectionTestDelegate
- (void)onMessage:(FWebSocketConnection *)fwebSocket withMessage:(NSDictionary *)message {
  self.receivedMessage = YES;
}
- (void)onDisconnect:(FWebSocketConnection *)fwebSocket wasEverConnected:(BOOL)everConnected {
}
@end

@interface FWebSocketConnectionTest : XCTestCase
@end

@implementation FWebSocketConnectionTest

- (FWebSocketConnection *)connectionWithDelegate:(FWebSocketConnectionTestDelegate *)delegate {
  FRepoInfo *info = [[FRepoInfo alloc] initWithHost:@"foo.firebaseio.com"
                                           isSecure:YES
                                      withNamespace:@"foo"];
  FWebSocketConnection *connection =
      [[FWebSocketConnection alloc] initWith:info
                                    andQueue:dispatch_get_main_queue()
                                 googleAppID:@"1:1234:ios:1234"
                               lastSessionID:nil
                               appCheckToken:nil];
  connection.delegate = delegate;
  return connection;
}

// The realtime protocol is text only. SocketRocket delivers an NSData for a
// binary frame, which does not respond to the NSString selectors the frame
// handler uses. A server sending such a frame previously crashed the client via
// -[NSData intValue]. It should now be ignored.
- (void)testBinaryFrameIsIgnored {
  FWebSocketConnectionTestDelegate *delegate = [[FWebSocketConnectionTestDelegate alloc] init];
  FWebSocketConnection *connection = [self connectionWithDelegate:delegate];

  NSData *binaryFrame = [@"AB" dataUsingEncoding:NSUTF8StringEncoding];
  XCTAssertNoThrow([connection webSocket:nil didReceiveMessage:(id)binaryFrame]);
  XCTAssertFalse(delegate.receivedMessage);
}

- (void)testEmptyBinaryFrameIsIgnored {
  FWebSocketConnectionTestDelegate *delegate = [[FWebSocketConnectionTestDelegate alloc] init];
  FWebSocketConnection *connection = [self connectionWithDelegate:delegate];

  XCTAssertNoThrow([connection webSocket:nil didReceiveMessage:(id)[NSData data]]);
  XCTAssertFalse(delegate.receivedMessage);
}

@end

#endif  // !TARGET_OS_WATCH

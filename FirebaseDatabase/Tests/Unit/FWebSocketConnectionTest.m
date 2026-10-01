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

#import "FirebaseDatabase/Sources/Core/FRepoInfo.h"
#import "FirebaseDatabase/Sources/Realtime/FWebSocketConnection.h"

#if !TARGET_OS_WATCH

@interface FWebSocketConnection (KeepAliveTesting)
- (void)onClosed;
- (void)resetKeepAlive;
@end

@interface FWebSocketTimerSpy : NSObject
@property(nonatomic) BOOL isValid;
@property(nonatomic, strong) NSDate *fireDate;
@property(nonatomic) BOOL invalidatedOnMainThread;
@property(nonatomic) BOOL updatedOnMainThread;
- (void)setInitialFireDate:(NSDate *)fireDate;
@end

@implementation FWebSocketTimerSpy
- (void)setInitialFireDate:(NSDate *)fireDate {
  _fireDate = fireDate;
}

- (void)invalidate {
  self.invalidatedOnMainThread = [NSThread isMainThread];
  self.isValid = NO;
}

- (void)setFireDate:(NSDate *)fireDate {
  self.updatedOnMainThread = [NSThread isMainThread];
  _fireDate = fireDate;
}
@end

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

- (void)testKeepAliveTimerIsAccessedOnMainThread {
  FWebSocketConnectionTestDelegate *delegate = [[FWebSocketConnectionTestDelegate alloc] init];
  FWebSocketConnection *connection = [self connectionWithDelegate:delegate];
  FWebSocketTimerSpy *timer = [[FWebSocketTimerSpy alloc] init];
  timer.isValid = YES;
  [timer setInitialFireDate:[NSDate dateWithTimeIntervalSinceNow:-60]];
  [connection setValue:timer forKey:@"keepAlive"];

  XCTestExpectation *resetExpectation =
      [self expectationWithDescription:@"timer reset on main"];
  dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
    [connection resetKeepAlive];
    dispatch_async(dispatch_get_main_queue(), ^{
      XCTAssertTrue(timer.updatedOnMainThread);
      [resetExpectation fulfill];
    });
  });
  [self waitForExpectations:@[ resetExpectation ] timeout:2];

  XCTestExpectation *closeExpectation =
      [self expectationWithDescription:@"timer invalidated on main"];
  dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
    [connection onClosed];
    dispatch_async(dispatch_get_main_queue(), ^{
      XCTAssertTrue(timer.invalidatedOnMainThread);
      [closeExpectation fulfill];
    });
  });
  [self waitForExpectations:@[ closeExpectation ] timeout:2];
}

@end

#endif  // !TARGET_OS_WATCH

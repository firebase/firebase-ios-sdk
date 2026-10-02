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
- (void)webSocketDidOpen;
- (void)sendStringToWebSocket:(NSString *)string;
@end

static char workerQueueKey;

@interface FWebSocketKeepAliveSpy : FWebSocketConnection
@property(nonatomic) NSUInteger keepAliveCount;
@property(nonatomic) BOOL sentOnWorkerQueue;
@property(nonatomic, copy) NSString *lastSentString;
@property(nonatomic, copy) void (^onKeepAlive)(void);
@end

@implementation FWebSocketKeepAliveSpy
- (void)sendStringToWebSocket:(NSString *)string {
  self.lastSentString = string;
  self.sentOnWorkerQueue = dispatch_get_specific(&workerQueueKey) != NULL;
  self.keepAliveCount++;
  if (self.onKeepAlive) {
    self.onKeepAlive();
  }
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

- (FWebSocketKeepAliveSpy *)keepAliveConnectionOnQueue:(dispatch_queue_t)queue {
  FRepoInfo *info = [[FRepoInfo alloc] initWithHost:@"foo.firebaseio.com"
                                           isSecure:YES
                                      withNamespace:@"foo"];
  dispatch_queue_set_specific(queue, &workerQueueKey, &workerQueueKey, NULL);
  return [[FWebSocketKeepAliveSpy alloc] initWith:info
                                         andQueue:queue
                                      googleAppID:@"1:1234:ios:1234"
                                    lastSessionID:nil
                                    appCheckToken:nil];
}

- (void)testKeepAliveRunsOnWorkerQueueAndResetsInline {
  dispatch_queue_t queue = dispatch_queue_create("keepalive.test", DISPATCH_QUEUE_SERIAL);
  FWebSocketKeepAliveSpy *connection = [self keepAliveConnectionOnQueue:queue];
  XCTestExpectation *sent = [self expectationWithDescription:@"worker keepalive"];
  dispatch_async(queue, ^{
    [connection webSocketDidOpen];
    [connection setValue:[NSDate distantPast] forKey:@"keepAliveFireDate"];
    [connection resetKeepAlive];
    NSDate *fireDate = [connection valueForKey:@"keepAliveFireDate"];
    XCTAssertGreaterThan([fireDate timeIntervalSinceNow], 40.0);
    connection.onKeepAlive = ^{
      XCTAssertEqualObjects(connection.lastSentString, @"0");
      XCTAssertTrue(connection.sentOnWorkerQueue);
      [connection onClosed];
      connection.onKeepAlive = nil;
      [sent fulfill];
    };
    dispatch_source_t timer = [connection valueForKey:@"keepAlive"];
    dispatch_source_set_timer(timer, DISPATCH_TIME_NOW, DISPATCH_TIME_FOREVER, 0);
  });
  [self waitForExpectations:@[ sent ] timeout:2];
}

- (void)testCloseCancelsKeepAliveAndCannotReinstallIt {
  dispatch_queue_t queue = dispatch_queue_create("keepalive.close.test", DISPATCH_QUEUE_SERIAL);
  FWebSocketKeepAliveSpy *connection = [self keepAliveConnectionOnQueue:queue];
  XCTestExpectation *closed = [self expectationWithDescription:@"no keepalive after close"];
  dispatch_async(queue, ^{
    [connection webSocketDidOpen];
    dispatch_source_t timer = [connection valueForKey:@"keepAlive"];
    dispatch_source_set_timer(timer, dispatch_time(DISPATCH_TIME_NOW, 100 * NSEC_PER_MSEC),
                              DISPATCH_TIME_FOREVER, 0);
    [connection onClosed];
    [connection resetKeepAlive];
    [connection webSocketDidOpen];
    XCTAssertNil([connection valueForKey:@"keepAlive"]);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 200 * NSEC_PER_MSEC), queue, ^{
      XCTAssertEqual(connection.keepAliveCount, 0U);
      [closed fulfill];
    });
  });
  [self waitForExpectations:@[ closed ] timeout:2];
}

@end

#endif  // !TARGET_OS_WATCH

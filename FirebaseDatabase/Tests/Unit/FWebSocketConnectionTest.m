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

// Records the disconnects that a connection reports.
@interface FWebSocketConnectionDisconnectRecorder : NSObject <FWebSocketDelegate>
@property(nonatomic) NSInteger disconnectCount;
@property(nonatomic) BOOL wasEverConnected;
@property(nonatomic) XCTestExpectation *disconnectExpectation;
@end

@implementation FWebSocketConnectionDisconnectRecorder
- (void)onMessage:(FWebSocketConnection *)fwebSocket withMessage:(NSDictionary *)message {
}
- (void)onDisconnect:(FWebSocketConnection *)fwebSocket wasEverConnected:(BOOL)everConnected {
  self.disconnectCount++;
  self.wasEverConnected = everConnected;
  [self.disconnectExpectation fulfill];
}
@end

@interface FWebSocketConnection (InvalidURLTesting)
- (void)closeIfNeverConnected;
@end

// A connection URL that NSURL can't parse used to abort the app in
// assert(request.URL) in -[FSRWebSocket initWithURLRequest:...]. Except for the
// FSRWebSocket tests, these tests also run on watchOS, which uses an
// NSURLSession web socket task instead.
@interface FWebSocketConnectionInvalidURLTest : XCTestCase
@end

@implementation FWebSocketConnectionInvalidURLTest

- (FWebSocketConnection *)connectionWithInvalidURLAndDelegate:
    (FWebSocketConnectionDisconnectRecorder *)delegate {
  // NSURL rejects a host with a space.
  FRepoInfo *info = [[FRepoInfo alloc] initWithHost:@"bad host" isSecure:YES withNamespace:@"foo"];
  XCTAssertNil([NSURL URLWithString:[info connectionURL]]);
  FWebSocketConnection *connection =
      [[FWebSocketConnection alloc] initWith:info
                                    andQueue:dispatch_get_main_queue()
                                 googleAppID:@"1:1234:ios:1234"
                               lastSessionID:nil
                               appCheckToken:nil];
  connection.delegate = delegate;
  return connection;
}

- (void)testInvalidURLReportsFailedConnectionAttempt {
  FWebSocketConnectionDisconnectRecorder *delegate =
      [[FWebSocketConnectionDisconnectRecorder alloc] init];
  delegate.disconnectExpectation = [self expectationWithDescription:@"disconnect"];
  FWebSocketConnection *connection = [self connectionWithInvalidURLAndDelegate:delegate];

  [connection open];

  // Reported asynchronously, as a web socket would, so open returns before the
  // delegate is called.
  XCTAssertEqual(delegate.disconnectCount, 0);

  // Reported right away rather than after the 30 second connect timeout, so
  // the connection falls back to the configured host and retries with backoff.
  [self waitForExpectations:@[ delegate.disconnectExpectation ] timeout:5];
  XCTAssertEqual(delegate.disconnectCount, 1);
  XCTAssertFalse(delegate.wasEverConnected);

  // The connect timeout doesn't report it again.
  [connection closeIfNeverConnected];
  XCTAssertEqual(delegate.disconnectCount, 1);
}

// As with a web socket, closing the connection before the failure is reported
// suppresses the report.
- (void)testInvalidURLFailureIsNotReportedAfterClose {
  FWebSocketConnectionDisconnectRecorder *delegate =
      [[FWebSocketConnectionDisconnectRecorder alloc] init];
  FWebSocketConnection *connection = [self connectionWithInvalidURLAndDelegate:delegate];

  [connection open];
  [connection close];

  // The report is dispatched to the main queue before this block.
  XCTestExpectation *reportDispatched = [self expectationWithDescription:@"report dispatched"];
  dispatch_async(dispatch_get_main_queue(), ^{
    [reportDispatched fulfill];
  });
  [self waitForExpectations:@[ reportDispatched ] timeout:5];
  XCTAssertEqual(delegate.disconnectCount, 0);
}

#if !TARGET_OS_WATCH

- (void)testWebSocketWithoutURLIsNil {
  NSURLRequest *request = [[NSURLRequest alloc] init];
  XCTAssertNil(request.URL);

  XCTAssertNil([[FSRWebSocket alloc] initWithURLRequest:request
                                                  queue:dispatch_get_main_queue()
                                            googleAppID:@"1:1234:ios:1234"
                                           andUserAgent:@"user-agent"]);
}

- (void)testWebSocketWithUnsupportedSchemeIsNil {
  NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:@"ftp://example.com/"]];

  XCTAssertNil([[FSRWebSocket alloc] initWithURLRequest:request
                                                  queue:dispatch_get_main_queue()
                                            googleAppID:@"1:1234:ios:1234"
                                           andUserAgent:@"user-agent"]);
}

#endif  // !TARGET_OS_WATCH

@end

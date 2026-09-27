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

#import <OCMock/OCMock.h>
#import <XCTest/XCTest.h>

#import <netinet/in.h>
#import <poll.h>
#import <sys/socket.h>
#import <unistd.h>

#import "FirebaseDatabase/Sources/Core/FRepoInfo.h"
#import "FirebaseDatabase/Sources/Realtime/FWebSocketConnection.h"

#if !TARGET_OS_WATCH

@interface FWebSocketConnection (Testing)
- (void)setWebSocket:(FSRWebSocket *)webSocket;
- (void)closeIfNeverConnected;
@end

@interface FWebSocketConnectionTestDelegate : NSObject <FWebSocketDelegate>
@property(nonatomic) BOOL receivedMessage;
@property(nonatomic) NSInteger disconnectCount;
@property(nonatomic) BOOL wasEverConnected;
@end

@implementation FWebSocketConnectionTestDelegate
- (void)onMessage:(FWebSocketConnection *)fwebSocket withMessage:(NSDictionary *)message {
  self.receivedMessage = YES;
}
- (void)onDisconnect:(FWebSocketConnection *)fwebSocket wasEverConnected:(BOOL)everConnected {
  self.disconnectCount++;
  self.wasEverConnected = everConnected;
}
@end

@interface FWebSocketConnectionTest : XCTestCase
@end

@implementation FWebSocketConnectionTest

- (FWebSocketConnection *)connectionWithDelegate:(FWebSocketConnectionTestDelegate *)delegate {
  return [self connectionToHost:@"foo.firebaseio.com" delegate:delegate];
}

- (FWebSocketConnection *)connectionToHost:(NSString *)host
                                  delegate:(FWebSocketConnectionTestDelegate *)delegate {
  FRepoInfo *info = [[FRepoInfo alloc] initWithHost:host isSecure:YES withNamespace:@"foo"];
  FWebSocketConnection *connection =
      [[FWebSocketConnection alloc] initWith:info
                                    andQueue:dispatch_get_main_queue()
                                 googleAppID:@"1:1234:ios:1234"
                               lastSessionID:nil
                               appCheckToken:nil];
  connection.delegate = delegate;
  return connection;
}

/** Waits up to `timeout` seconds for `fd` to be readable, running the main run loop meanwhile. */
- (BOOL)waitUntilReadable:(int)fd timeout:(NSTimeInterval)timeout {
  NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:timeout];
  while ([deadline timeIntervalSinceNow] > 0) {
    struct pollfd pollFD = {.fd = fd, .events = POLLIN};
    if (poll(&pollFD, 1, 0) > 0) {
      return YES;
    }
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
  }
  return NO;
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

// When a connection attempt times out, the disconnect should be reported right
// away, even if the web socket never reports that it closed. The client
// previously waited for that report, which could take hours if the connection
// was stuck in the TLS handshake, and stayed offline until then.
// https://github.com/firebase/firebase-ios-sdk/issues/9682
- (void)testConnectTimeoutReportsDisconnectWithoutWaitingForWebSocket {
  FWebSocketConnectionTestDelegate *delegate = [[FWebSocketConnectionTestDelegate alloc] init];
  FWebSocketConnection *connection = [self connectionWithDelegate:delegate];
  // A web socket that never reports that it closed.
  id webSocket = OCMClassMock([FSRWebSocket class]);
  [connection setWebSocket:webSocket];

  [connection closeIfNeverConnected];

  OCMVerify([webSocket close]);
  // The connection stops listening to the web socket.
  OCMVerify([webSocket setDelegate:nil]);
  XCTAssertEqual(delegate.disconnectCount, 1);
  XCTAssertFalse(delegate.wasEverConnected);

  // The disconnect isn't reported again if the web socket reports it later.
  [connection webSocket:webSocket didCloseWithCode:0 reason:nil wasClean:NO];
  XCTAssertEqual(delegate.disconnectCount, 1);
}

- (void)testConnectTimeoutAfterCloseDoesNotReportDisconnect {
  FWebSocketConnectionTestDelegate *delegate = [[FWebSocketConnectionTestDelegate alloc] init];
  FWebSocketConnection *connection = [self connectionWithDelegate:delegate];
  id webSocket = OCMClassMock([FSRWebSocket class]);
  [connection setWebSocket:webSocket];

  [connection close];
  [connection closeIfNeverConnected];

  XCTAssertEqual(delegate.disconnectCount, 0);
}

// When a connection attempt times out, the web socket should close the
// connection even if it's stuck in the TLS handshake. It previously waited to
// send its handshake request first, which kept the connection open until the
// OS gave up on it, possibly hours later.
// https://github.com/firebase/firebase-ios-sdk/issues/9682
- (void)testConnectTimeoutClosesConnectionStuckInTLSHandshake {
  // Stop at the first failure, so that a failed wait doesn't lead to a blocking
  // accept or read.
  self.continueAfterFailure = NO;
  // A local server that accepts the connection but never answers the TLS
  // handshake.
  int server = socket(AF_INET, SOCK_STREAM, 0);
  XCTAssertGreaterThanOrEqual(server, 0);
  [self addTeardownBlock:^{
    close(server);
  }];
  struct sockaddr_in address = {0};
  address.sin_len = sizeof(address);
  address.sin_family = AF_INET;
  address.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
  socklen_t addressLength = sizeof(address);
  XCTAssertEqual(bind(server, (struct sockaddr *)&address, addressLength), 0);
  XCTAssertEqual(listen(server, 1), 0);
  XCTAssertEqual(getsockname(server, (struct sockaddr *)&address, &addressLength), 0);
  NSString *host = [NSString stringWithFormat:@"127.0.0.1:%d", ntohs(address.sin_port)];

  FWebSocketConnectionTestDelegate *delegate = [[FWebSocketConnectionTestDelegate alloc] init];
  FWebSocketConnection *connection = [self connectionToHost:host delegate:delegate];
  [connection open];

  XCTAssertTrue([self waitUntilReadable:server timeout:5]);
  int client = accept(server, NULL, NULL);
  XCTAssertGreaterThanOrEqual(client, 0);
  [self addTeardownBlock:^{
    close(client);
  }];
  // Wait for the TLS ClientHello, then give the web socket time to queue its
  // handshake request.
  char buffer[4096];
  XCTAssertTrue([self waitUntilReadable:client timeout:5]);
  XCTAssertGreaterThan(read(client, buffer, sizeof(buffer)), 0);
  [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];

  [connection closeIfNeverConnected];
  XCTAssertEqual(delegate.disconnectCount, 1);

  // Read until the connection is closed. The client may send a TLS alert first.
  BOOL closed = NO;
  while (!closed && [self waitUntilReadable:client timeout:5]) {
    closed = read(client, buffer, sizeof(buffer)) <= 0;
  }
  XCTAssertTrue(closed);
  XCTAssertEqual(delegate.disconnectCount, 1);
}

@end

#endif  // !TARGET_OS_WATCH

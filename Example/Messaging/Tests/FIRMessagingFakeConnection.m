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

#import "Example/Messaging/Tests/FIRMessagingFakeConnection.h"

#import <OCMock/OCMock.h>

#import "Firebase/Messaging/Protos/GtalkCore.pbobjc.h"

#import "Firebase/Messaging/FIRMessagingSecureSocket.h"
#import "Firebase/Messaging/FIRMessagingUtilities.h"

static NSString *const kHost = @"localhost";
static const int kPort = 6234;

@interface FIRMessagingSecureSocket ()

@property(nonatomic, readwrite, assign) FIRMessagingSecureSocketState state;

@end

@interface FIRMessagingConnection ()

@property(nonatomic, readwrite, strong) FIRMessagingSecureSocket *socket;

- (void)setupConnectionSocket;
- (void)connectToSocket:(FIRMessagingSecureSocket *)socket;
- (NSTimeInterval)connectionTimeoutInterval;
- (void)sendHeartbeatPing;
- (void)secureSocket:(FIRMessagingSecureSocket *)socket
      didReceiveData:(NSData *)data
             withTag:(int8_t)tag;

@end

@implementation FIRMessagingFakeConnection

- (void)signIn {

  // use this if you don't really want to mock/stub the login behaviour. In case
  // you want to stub the login behavoiur you should do these things manually in
  // your test and add custom logic in between as required for your testing.
  [self setupConnectionSocket];

  id socketMock = OCMPartialMock(self.socket);
  self.socket = socketMock;
  [[[socketMock stub]
      andDo:^(NSInvocation *invocation) {
        if (self.shouldFakeSuccessLogin) {
          [self willFakeSuccessfulLoginToFCM];
        }
        self.socket.state = kFIRMessagingSecureSocketOpen;
        [self.socket.delegate secureSocketDidConnect:self.socket];
      }]
      connectToHost:kHost
               port:kPort
          onRunLoop:[OCMArg any]];

  [self connectToSocket:socketMock];
}

- (NSTimeInterval)connectionTimeoutInterval {
  if (self.fakeConnectionTimeout) {
    return self.fakeConnectionTimeout;
  } else {
    return 0.5;  // 0.5s
  }
}

- (void)mockSocketDisconnect {
  id mockSocket = self.socket;
  [[[mockSocket stub] andDo:^(NSInvocation *invocation) {
    self.socket.state = kFIRMessagingSecureSocketClosed;
  }] disconnect];
}

- (void)disconnectNow {
  [self.socket disconnect];
  [self.socket.delegate didDisconnectWithSecureSocket:self.socket];
}

+ (NSString *)fakeHost {
  return @"localhost";
}

+ (int)fakePort {
  return 6234;
}

- (void)willFakeSuccessfulLoginToFCM {
  id mockSocket = self.socket;
  [[[mockSocket stub]
      andDo:^(NSInvocation *invocation) {
        // mock successful login

        GtalkLoginResponse *response = [[GtalkLoginResponse alloc] init];
        [response setId_p:@""];
        [self secureSocket:self.socket
            didReceiveData:[response data]
                   withTag:kFIRMessagingProtoTagLoginResponse];
      }]
      sendData:[OCMArg any]
       withTag:kFIRMessagingProtoTagLoginRequest
         rmqId:[OCMArg isNil]];
}

@end

@implementation FIRMessagingFakeFailConnection

- (void)signIn {
  self.signInRequests++;
  [self setupConnectionSocket];
  id mockSocket = OCMPartialMock(self.socket);
  self.socket = mockSocket;
  [[[mockSocket stub]
      andDo:^(NSInvocation *invocation) {
        [self mockSocketDisconnect];
        if (self.signInRequests <= self.failCount) {
          // do nothing -- should timeout
        } else {
          // since we will always fail once we would disconnect the socket before
          // we ever try again thus mock the disconnect to change the state and
          // prevent any assertions
          [self willFakeSuccessfulLoginToFCM];
          self.socket.state = kFIRMessagingSecureSocketOpen;
          [self.socket.delegate secureSocketDidConnect:self.socket];
        }
      }]
      connectToHost:kHost
               port:kPort
          onRunLoop:[OCMArg any]];

  [self connectToSocket:mockSocket];
}

@end

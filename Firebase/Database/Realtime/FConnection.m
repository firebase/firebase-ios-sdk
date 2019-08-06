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

#import "FConnection.h"
#import "FConstants.h"
#import <FirebaseCore/FIRLogger.h>

typedef enum {
    REALTIME_STATE_CONNECTING = 0,
    REALTIME_STATE_CONNECTED = 1,
    REALTIME_STATE_DISCONNECTED = 2,
} FConnectionState;

@interface FConnection () {
    FConnectionState state;
}

@property(nonatomic, strong) FWebSocketConnection *conn;
@property(nonatomic, strong) FRepoInfo *repoInfo;

@end

#pragma mark -
#pragma mark FConnection implementation

@implementation FConnection

@synthesize delegate;
@synthesize conn;
@synthesize repoInfo;

#pragma mark -
#pragma mark Initializers

- (id)initWith:(FRepoInfo *)aRepoInfo
    andDispatchQueue:(dispatch_queue_t)queue
       lastSessionID:(NSString *)lastSessionID {
    self = [super init];
    if (self) {
        state = REALTIME_STATE_CONNECTING;
        self.repoInfo = aRepoInfo;
        self.conn = [[FWebSocketConnection alloc] initWith:self.repoInfo
                                                  andQueue:queue
                                             lastSessionID:lastSessionID];
        self.conn.delegate = self;
    }
    return self;
}

#pragma mark -
#pragma mark Public method implementation

- (void)open {
    FFLog(@"I-RDB082001", @"Calling open in FConnection");
    [self.conn open];
}

- (void)closeWithReason:(FDisconnectReason)reason {
    if (state != REALTIME_STATE_DISCONNECTED) {
        FFLog(@"I-RDB082002", @"Closing realtime connection.");
        state = REALTIME_STATE_DISCONNECTED;

        if (self.conn) {
            FFLog(@"I-RDB082003", @"Calling close again.");
            [self.conn close];
            self.conn = nil;
        }

        [self.delegate onDisconnect:self withReason:reason];
    }
}

- (void)close {
    [self closeWithReason:DISCONNECT_REASON_OTHER];
}

- (void)sendRequest:(NSDictionary *)dataMsg sensitive:(BOOL)sensitive {
    // since this came from the persistent connection, wrap it in a data message
    // envelope
    NSDictionary *msg = @{
        kFWPRequestType : kFWPRequestTypeData,
        kFWPRequestDataPayload : dataMsg
    };
    [self sendData:msg sensitive:sensitive];
}

#pragma mark -
#pragma mark Helpers

- (void)sendData:(NSDictionary *)data sensitive:(BOOL)sensitive {
    if (state != REALTIME_STATE_CONNECTED) {
        @throw [[NSException alloc]
            initWithName:@"InvalidConnectionState"
                  reason:@"Tried to send data on an unconnected FConnection"
                userInfo:nil];
    } else {
        if (sensitive) {
            FFLog(@"I-RDB082004", @"Sending data (contents hidden)");
        } else {
            FFLog(@"I-RDB082005", @"Sending: %@", data);
        }
        [self.conn send:data];
    }
}

#pragma mark -
#pragma mark FWebSocketConnectinDelegate implementation

// Corresponds to onConnectionLost in JS
- (void)onDisconnect:(FWebSocketConnection *)fwebSocket
    wasEverConnected:(BOOL)everConnected {

    self.conn = nil;
    if (!everConnected && state == REALTIME_STATE_CONNECTING) {
        FFLog(@"I-RDB082006", @"Realtime connection failed.");

        // Since we failed to connect at all, clear any cached entry for this
        // namespace in case the machine went away
        [self.repoInfo clearInternalHostCache];
    } else if (state == REALTIME_STATE_CONNECTED) {
        FFLog(@"I-RDB082007", @"Realtime connection lost.");
    }

    [self close];
}

// Corresponds to onMessageReceived in JS
- (void)onMessage:(FWebSocketConnection *)fwebSocket
      withMessage:(NSDictionary *)message {
    NSString *rawMessageType =
        [message objectForKey:kFWPAsyncServerEnvelopeType];
    if (rawMessageType != nil) {
        if ([rawMessageType isEqualToString:kFWPAsyncServerDataMessage]) {
            [self onDataMessage:[message
                                    objectForKey:kFWPAsyncServerEnvelopeData]];
        } else if ([rawMessageType
                       isEqualToString:kFWPAsyncServerControlMessage]) {
            [self onControl:[message objectForKey:kFWPAsyncServerEnvelopeData]];
        } else {
            FFLog(@"I-RDB082008", @"Unrecognized server packet type: %@",
                  rawMessageType);
        }
    } else {
        FFLog(@"I-RDB082009", @"Unrecognized raw server packet received: %@",
              message);
    }
}

- (void)onDataMessage:(NSDictionary *)message {
    // we don't do anything with data messages, just kick them up a level
    FFLog(@"I-RDB082010", @"Got data message: %@", message);
    [self.delegate onDataMessage:self withMessage:message];
}

- (void)onControl:(NSDictionary *)message {
    FFLog(@"I-RDB082011", @"Got control message: %@", message);
    NSString *type = [message objectForKey:kFWPAsyncServerControlMessageType];
    if ([type isEqualToString:kFWPAsyncServerControlMessageShutdown]) {
        NSString *reason =
            [message objectForKey:kFWPAsyncServerControlMessageData];
        [self onConnectionShutdownWithReason:reason];
    } else if ([type isEqualToString:kFWPAsyncServerControlMessageReset]) {
        NSString *host =
            [message objectForKey:kFWPAsyncServerControlMessageData];
        [self onReset:host];
    } else if ([type isEqualToString:kFWPAsyncServerHello]) {
        NSDictionary *handshakeData =
            [message objectForKey:kFWPAsyncServerControlMessageData];
        [self onHandshake:handshakeData];
    } else {
        FFLog(@"I-RDB082012",
              @"Unknown control message returned from server: %@", message);
    }
}

- (void)onConnectionShutdownWithReason:(NSString *)reason {
    FFLog(@"I-RDB082013",
          @"Connection shutdown command received. Shutting down...");

    [self.delegate onKill:self withReason:reason];
    [self close];
}

- (void)onHandshake:(NSDictionary *)handshake {
    NSNumber *timestamp =
        [handshake objectForKey:kFWPAsyncServerHelloTimestamp];
    //    NSString* version = [handshake
    //    objectForKey:kFWPAsyncServerHelloVersion];
    NSString *host = [handshake objectForKey:kFWPAsyncServerHelloConnectedHost];
    NSString *sessionID = [handshake objectForKey:kFWPAsyncServerHelloSession];

    self.repoInfo.internalHost = host;

    if (state == REALTIME_STATE_CONNECTING) {
        [self.conn start];
        [self onConnection:self.conn readyAtTime:timestamp sessionID:sessionID];
    }
}

- (void)onConnection:(FWebSocketConnection *)conn
         readyAtTime:(NSNumber *)timestamp
           sessionID:(NSString *)sessionID {
    FFLog(@"I-RDB082014", @"Realtime connection established");
    state = REALTIME_STATE_CONNECTED;

    [self.delegate onReady:self atTime:timestamp sessionID:sessionID];
}

- (void)onReset:(NSString *)host {
    FFLog(
        @"I-RDB082015",
        @"Got a reset; killing connection to: %@; Updating internalHost to: %@",
        repoInfo.internalHost, host);
    self.repoInfo.internalHost = host;

    // Explicitly close the connection with SERVER_RESET so calling code knows
    // to reconnect immediately.
    [self closeWithReason:DISCONNECT_REASON_SERVER_RESET];
}

@end

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

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, FIRMessagingSecureSocketState) {
  kFIRMessagingSecureSocketNotOpen = 0,
  kFIRMessagingSecureSocketOpening,
  kFIRMessagingSecureSocketOpen,
  kFIRMessagingSecureSocketClosing,
  kFIRMessagingSecureSocketClosed,
  kFIRMessagingSecureSocketError
};

@class FIRMessagingSecureSocket;

@protocol FIRMessagingSecureSocketDelegate <NSObject>

- (void)secureSocket:(FIRMessagingSecureSocket *)socket
      didReceiveData:(NSData *)data
             withTag:(int8_t)tag;
- (void)secureSocket:(FIRMessagingSecureSocket *)socket
    didSendProtoWithTag:(int8_t)tag
                  rmqId:(NSString *)rmqId;
- (void)secureSocketDidConnect:(FIRMessagingSecureSocket *)socket;
- (void)didDisconnectWithSecureSocket:(FIRMessagingSecureSocket *)socket;

@end

/**
 * This manages the input/output streams connected to the MCS server. Used to receive data from
 * the server and send to it over the wire.
 */
@interface FIRMessagingSecureSocket : NSObject

@property(nonatomic, readwrite, weak) id<FIRMessagingSecureSocketDelegate> delegate;
@property(nonatomic, readonly, assign) FIRMessagingSecureSocketState state;

- (void)connectToHost:(NSString *)host port:(NSUInteger)port onRunLoop:(NSRunLoop *)runLoop;
- (void)disconnect;
- (void)sendData:(NSData *)data withTag:(int8_t)tag rmqId:(NSString *)rmqId;

@end

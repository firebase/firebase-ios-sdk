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

@interface FIRMessagingPacket : NSObject

+ (FIRMessagingPacket *)packetWithTag:(int8_t)tag rmqId:(NSString *)rmqId data:(NSData *)data;

@property(nonatomic, readonly, strong) NSData *data;
@property(nonatomic, readonly, assign) int8_t tag;
// not sent over the wire required for bookkeeping
@property(nonatomic, readonly, assign) NSString *rmqId;

@end


/**
 * A queue of the packets(protos) that need to be send over the wire.
 */
@interface FIRMessagingPacketQueue : NSObject

@property(nonatomic, readonly, assign) NSUInteger count;
@property(nonatomic, readonly, assign) BOOL isEmpty;

- (void)push:(FIRMessagingPacket *)packet;
- (void)pushHead:(FIRMessagingPacket *)packet;
- (FIRMessagingPacket *)pop;

@end

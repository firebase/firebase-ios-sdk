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

#import "Firebase/Messaging/FIRMessagingPacketQueue.h"

#import "Firebase/Messaging/FIRMessagingDefines.h"

@interface FIRMessagingPacket ()

@property(nonatomic, readwrite, strong) NSData *data;
@property(nonatomic, readwrite, assign) int8_t tag;
@property(nonatomic, readwrite, assign) NSString *rmqId;

@end

@implementation FIRMessagingPacket

+ (FIRMessagingPacket *)packetWithTag:(int8_t)tag rmqId:(NSString *)rmqId data:(NSData *)data {
  return [[self alloc] initWithTag:tag rmqId:rmqId data:data];
}

- (instancetype)init {
  FIRMessagingInvalidateInitializer();
}

- (instancetype)initWithTag:(int8_t)tag rmqId:(NSString *)rmqId data:(NSData *)data {
  self = [super init];
  if (self != nil) {
    _data = data;
    _tag = tag;
    _rmqId = rmqId;
  }
  return self;
}

- (NSString *)description {
  if ([self.rmqId length]) {
    return [NSString stringWithFormat:@"<Packet: Tag - %d, Length - %lu>, RmqId - %@", self.tag,
                                      _FIRMessaging_UL(self.data.length), self.rmqId];
  } else {
    return [NSString stringWithFormat:@"<Packet: Tag - %d, Length - %lu>", self.tag,
                                      _FIRMessaging_UL(self.data.length)];
  }
}

@end

@interface FIRMessagingPacketQueue ()

@property(nonatomic, readwrite, strong) NSMutableArray *packetsContainer;

@end

@implementation FIRMessagingPacketQueue
;

- (id)init {
  self = [super init];
  if (self) {
    _packetsContainer = [[NSMutableArray alloc] init];
  }
  return self;
}

- (BOOL)isEmpty {
  return self.packetsContainer.count == 0;
}

- (NSUInteger)count {
  return self.packetsContainer.count;
}

- (void)push:(FIRMessagingPacket *)packet {
  [self.packetsContainer addObject:packet];
}

- (void)pushHead:(FIRMessagingPacket *)packet {
  [self.packetsContainer insertObject:packet atIndex:0];
}

- (FIRMessagingPacket *)pop {
  if (!self.isEmpty) {
    FIRMessagingPacket *packet = self.packetsContainer[0];
    [self.packetsContainer removeObjectAtIndex:0];
    return packet;
  }
  return nil;
}

@end

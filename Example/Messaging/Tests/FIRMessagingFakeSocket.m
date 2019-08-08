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

#import "Example/Messaging/Tests/FIRMessagingFakeSocket.h"

#import "Firebase/Messaging/FIRMessagingConstants.h"
#import "Firebase/Messaging/FIRMessagingDefines.h"

@interface FIRMessagingSecureSocket() <NSStreamDelegate>

@property(nonatomic, readwrite, assign) FIRMessagingSecureSocketState state;
@property(nonatomic, readwrite, strong) NSInputStream *inStream;
@property(nonatomic, readwrite, strong) NSOutputStream *outStream;

@property(nonatomic, readwrite, assign) BOOL isInStreamOpen;
@property(nonatomic, readwrite, assign) BOOL isOutStreamOpen;

@property(nonatomic, readwrite, strong) NSRunLoop *runLoop;

@end

@interface FIRMessagingFakeSocket ()

@property(nonatomic, readwrite, assign) int8_t bufferSize;

@end

@implementation FIRMessagingFakeSocket

- (instancetype)initWithBufferSize:(uint8_t)bufferSize {
  self = [super init];
  if (self) {
    _bufferSize = bufferSize;
  }
  return self;
}

- (void)connectToHost:(NSString *)host
                 port:(NSUInteger)port
            onRunLoop:(NSRunLoop *)runLoop {
  self.state = kFIRMessagingSecureSocketOpening;
  self.runLoop = runLoop;

  CFReadStreamRef inputStreamRef = nil;
  CFWriteStreamRef outputStreamRef = nil;

  CFStreamCreateBoundPair(NULL,
                          &inputStreamRef,
                          &outputStreamRef,
                          self.bufferSize);

  self.inStream = CFBridgingRelease(inputStreamRef);
  self.outStream = CFBridgingRelease(outputStreamRef);
  if (!self.inStream || !self.outStream) {
    NSAssert(NO, @"Cannot create a fake socket");
    return;
  }

  self.isInStreamOpen = NO;
  self.isOutStreamOpen = NO;

  [self openStream:self.outStream];
  [self openStream:self.inStream];
}

- (void)openStream:(NSStream *)stream {
  NSAssert(stream, @"Cannot open nil stream");
  if (stream) {
    stream.delegate = self;
    [stream scheduleInRunLoop:self.runLoop forMode:NSDefaultRunLoopMode];
    [stream open];
  }
}

@end

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

#import "FIRMessagingSecureSocket.h"

#import "GPBMessage.h"
#import "GPBCodedOutputStream.h"
#import "GPBUtilities.h"

#import "FIRMessagingCodedInputStream.h"
#import "FIRMessagingDefines.h"
#import "FIRMessagingLogger.h"
#import "FIRMessagingPacketQueue.h"

static const NSUInteger kMaxBufferLength = 1024 * 1024;  // 1M
static const NSUInteger kBufferLengthIncrement = 16 * 1024;  // 16k
static const uint8_t kVersion = 40;
static const uint8_t kInvalidTag = -1;

typedef NS_ENUM(NSUInteger, FIRMessagingSecureSocketReadResult) {
  kFIRMessagingSecureSocketReadResultNone,
  kFIRMessagingSecureSocketReadResultIncomplete,
  kFIRMessagingSecureSocketReadResultCorrupt,
  kFIRMessagingSecureSocketReadResultSuccess
};

static int32_t LogicalRightShift32(int32_t value, int32_t spaces) {
  return (int32_t)((uint32_t)(value) >> spaces);
}

static NSUInteger SerializedSize(int32_t value) {
  NSUInteger bytes = 0;
  while (YES) {
    if ((value & ~0x7F) == 0) {
      bytes += sizeof(uint8_t);
      return bytes;
    } else {
      bytes += sizeof(uint8_t);
      value = LogicalRightShift32(value, 7);
    }
  }
}

@interface FIRMessagingSecureSocket() <NSStreamDelegate>

@property(nonatomic, readwrite, assign) FIRMessagingSecureSocketState state;
@property(nonatomic, readwrite, strong) NSInputStream *inStream;
@property(nonatomic, readwrite, strong) NSOutputStream *outStream;

@property(nonatomic, readwrite, strong) NSMutableData *inputBuffer;
@property(nonatomic, readwrite, assign) NSUInteger inputBufferLength;
@property(nonatomic, readwrite, strong) NSMutableData *outputBuffer;
@property(nonatomic, readwrite, assign) NSUInteger outputBufferLength;

@property(nonatomic, readwrite, strong) FIRMessagingPacketQueue *packetQueue;
@property(nonatomic, readwrite, assign) BOOL isVersionSent;
@property(nonatomic, readwrite, assign) BOOL isVersionReceived;
@property(nonatomic, readwrite, assign) BOOL isInStreamOpen;
@property(nonatomic, readwrite, assign) BOOL isOutStreamOpen;

@property(nonatomic, readwrite, strong) NSRunLoop *runLoop;
@property(nonatomic, readwrite, strong) NSString *currentRmqIdBeingSent;
@property(nonatomic, readwrite, assign) int8_t currentProtoTypeBeingSent;

@end

@implementation FIRMessagingSecureSocket

- (instancetype)init {
  self = [super init];
  if (self) {
    _state = kFIRMessagingSecureSocketNotOpen;
    _inputBuffer = [NSMutableData dataWithLength:kBufferLengthIncrement];
    _packetQueue = [[FIRMessagingPacketQueue alloc] init];
    _currentProtoTypeBeingSent = kInvalidTag;
  }
  return self;
}

- (void)dealloc {
  [self disconnect];
}

- (void)connectToHost:(NSString *)host
                 port:(NSUInteger)port
            onRunLoop:(NSRunLoop *)runLoop {
  _FIRMessagingDevAssert(host != nil, @"Invalid host");
  _FIRMessagingDevAssert(runLoop != nil, @"Invalid runloop");
  _FIRMessagingDevAssert(self.state == kFIRMessagingSecureSocketNotOpen, @"Socket is already connected");

  if (!host || self.state != kFIRMessagingSecureSocketNotOpen) {
    return;
  }

  FIRMessagingLoggerDebug(kFIRMessagingMessageCodeSecureSocket000,
                          @"Opening secure socket to FIRMessaging service");
  self.state = kFIRMessagingSecureSocketOpening;
  self.runLoop = runLoop;
  CFReadStreamRef inputStreamRef;
  CFWriteStreamRef outputStreamRef;
  CFStreamCreatePairWithSocketToHost(NULL,
                                     (__bridge CFStringRef)host,
                                     (int)port,
                                     &inputStreamRef,
                                     &outputStreamRef);
  self.inStream = CFBridgingRelease(inputStreamRef);
  self.outStream = CFBridgingRelease(outputStreamRef);
  if (!self.inStream || !self.outStream) {
    FIRMessagingLoggerDebug(kFIRMessagingMessageCodeSecureSocket001,
                            @"Failed to initialize socket.");
    return;
  }

  self.isInStreamOpen = NO;
  self.isOutStreamOpen = NO;

  BOOL isVOIPSocket = NO;

#if FIRMessaging_PROBER
  isVOIPSocket = YES;
#endif

  [self openStream:self.outStream isVOIPStream:isVOIPSocket];
  [self openStream:self.inStream isVOIPStream:isVOIPSocket];
}

- (void)disconnect {
  if (self.state == kFIRMessagingSecureSocketClosing) {
    return;
  }
  if (!self.inStream && !self.outStream) {
    FIRMessagingLoggerDebug(kFIRMessagingMessageCodeSecureSocket002,
                            @"The socket is not open or already closed.");
    _FIRMessagingDevAssert(self.state == kFIRMessagingSecureSocketClosed || self.state == kFIRMessagingSecureSocketNotOpen,
                  @"Socket is already disconnected.");
    return;
  }

  self.state = kFIRMessagingSecureSocketClosing;
  if (self.inStream) {
    [self closeStream:self.inStream];
    self.inStream = nil;
  }
  if (self.outStream) {
    [self closeStream:self.outStream];
    self.outStream = nil;
  }
  self.state = kFIRMessagingSecureSocketClosed;
  [self.delegate didDisconnectWithSecureSocket:self];
}

- (void)sendData:(NSData *)data withTag:(int8_t)tag rmqId:(NSString *)rmqId {
  [self.packetQueue push:[FIRMessagingPacket packetWithTag:tag rmqId:rmqId data:data]];
  if ([self.outStream hasSpaceAvailable]) {
    [self performWrite];
  }
}

#pragma mark - NSStreamDelegate

- (void)stream:(NSStream *)stream handleEvent:(NSStreamEvent)eventCode {
  switch (eventCode) {
    case NSStreamEventHasBytesAvailable:
      if (self.state != kFIRMessagingSecureSocketOpen) {
        FIRMessagingLoggerDebug(kFIRMessagingMessageCodeSecureSocket003,
                                @"Try to read from socket that is not opened");
        return;
      }
      _FIRMessagingDevAssert(stream == self.inStream, @"Incorrect stream");
      if (![self performRead]) {
        FIRMessagingLoggerDebug(kFIRMessagingMessageCodeSecureSocket004,
                                @"Error occured when reading incoming stream");
        [self disconnect];
      }
      break;
    case NSStreamEventEndEncountered:
      FIRMessagingLoggerDebug(
          kFIRMessagingMessageCodeSecureSocket005, @"%@ end encountered",
          stream == self.inStream
              ? @"Input stream"
              : (stream == self.outStream ? @"Output stream" : @"Unknown stream"));
      [self disconnect];
      break;
    case NSStreamEventOpenCompleted:
      if (stream == self.inStream) {
        self.isInStreamOpen = YES;
      } else if (stream == self.outStream) {
        self.isOutStreamOpen = YES;
      }
      if (self.isInStreamOpen && self.isOutStreamOpen) {
        FIRMessagingLoggerDebug(kFIRMessagingMessageCodeSecureSocket006,
                                @"Secure socket to FIRMessaging service opened");
        self.state = kFIRMessagingSecureSocketOpen;
        [self.delegate secureSocketDidConnect:self];
      }
      break;
    case NSStreamEventErrorOccurred: {
      FIRMessagingLoggerDebug(
          kFIRMessagingMessageCodeSecureSocket007, @"%@ error occurred",
          stream == self.inStream
              ? @"Input stream"
              : (stream == self.outStream ? @"Output stream" : @"Unknown stream"));
      [self disconnect];
      break;
    }
    case NSStreamEventHasSpaceAvailable:
      if (self.state != kFIRMessagingSecureSocketOpen) {
        FIRMessagingLoggerDebug(kFIRMessagingMessageCodeSecureSocket008,
                                @"Try to write to socket that is not opened");
        return;
      }
      _FIRMessagingDevAssert(stream == self.outStream, @"Incorrect stream");
      [self performWrite];
      break;
    default:
      break;
  }
}

#pragma mark - Private

- (void)openStream:(NSStream *)stream isVOIPStream:(BOOL)isVOIPStream {
  _FIRMessagingDevAssert(stream != nil, @"Invalid stream");
  _FIRMessagingDevAssert(self.runLoop != nil, @"Invalid runloop");

  if (stream) {
    _FIRMessagingDevAssert([stream streamStatus] == NSStreamStatusNotOpen, @"Stream already open");
    if ([stream streamStatus] != NSStreamStatusNotOpen) {
      FIRMessagingLoggerDebug(kFIRMessagingMessageCodeSecureSocket009,
                              @"stream should not be open.");
      return;
    }
    [stream setProperty:NSStreamSocketSecurityLevelNegotiatedSSL
                 forKey:NSStreamSocketSecurityLevelKey];
    if (isVOIPStream) {
      [stream setProperty:NSStreamNetworkServiceTypeVoIP
                   forKey:NSStreamNetworkServiceType];
    }
    stream.delegate = self;
    [stream scheduleInRunLoop:self.runLoop forMode:NSDefaultRunLoopMode];
    [stream open];
  }
}

- (void)closeStream:(NSStream *)stream {
  _FIRMessagingDevAssert(stream != nil, @"Invalid stream");
  _FIRMessagingDevAssert(self.runLoop != nil, @"Invalid runloop");

  if (stream) {
    [stream close];
    [stream removeFromRunLoop:self.runLoop forMode:NSDefaultRunLoopMode];
    stream.delegate = nil;
  }
}

- (BOOL)performRead {
  _FIRMessagingDevAssert(self.state == kFIRMessagingSecureSocketOpen, @"Socket should be open");

  if (!self.isVersionReceived) {
    self.isVersionReceived = YES;
    uint8_t versionByte = 0;
    NSInteger bytesRead = [self.inStream read:&versionByte maxLength:sizeof(uint8_t)];
    if (bytesRead != sizeof(uint8_t) || kVersion != versionByte) {
      FIRMessagingLoggerDebug(kFIRMessagingMessageCodeSecureSocket010,
                              @"Version do not match. Received %d, Expecting %d", versionByte,
                              kVersion);
      return NO;
    }
  }

  while (YES) {
    BOOL isInputBufferValid = [self.inputBuffer length] > 0;
    _FIRMessagingDevAssert(isInputBufferValid,
                  @"Invalid input buffer size %lu. Used bytes length %lu, buffer content: %@",
                  _FIRMessaging_UL([self.inputBuffer length]),
                  _FIRMessaging_UL(self.inputBufferLength),
                  self.inputBuffer);
    if (!isInputBufferValid) {
      FIRMessagingLoggerDebug(kFIRMessagingMessageCodeSecureSocket011,
                              @"Input buffer is not valid.");
      return NO;
    }

    if (![self.inStream hasBytesAvailable]) {
      break;
    }

    // try to read more data
    uint8_t *unusedBufferPtr = (uint8_t *)self.inputBuffer.mutableBytes + self.inputBufferLength;
    NSUInteger unusedBufferLength = [self.inputBuffer length] - self.inputBufferLength;
    NSInteger bytesRead = [self.inStream read:unusedBufferPtr maxLength:unusedBufferLength];
    if (bytesRead <= 0) {
      FIRMessagingLoggerDebug(kFIRMessagingMessageCodeSecureSocket012,
                              @"Failed to read input stream. Bytes read %ld, Used buffer size %lu, "
                              @"Unused buffer size %lu",
                              _FIRMessaging_UL(bytesRead), _FIRMessaging_UL(self.inputBufferLength),
                              _FIRMessaging_UL(unusedBufferLength));
      break;
    }
    // did successfully read some more data
    self.inputBufferLength += (NSUInteger)bytesRead;

    if ([self.inputBuffer length] <= self.inputBufferLength) {
      // shouldn't be reading more than 1MB of data in one go
      if ([self.inputBuffer length] + kBufferLengthIncrement > kMaxBufferLength) {
        FIRMessagingLoggerDebug(kFIRMessagingMessageCodeSecureSocket013,
                                @"Input buffer exceed 1M, disconnect socket");
        return NO;
      }
      FIRMessagingLoggerDebug(kFIRMessagingMessageCodeSecureSocket014,
                              @"Input buffer limit exceeded. Used input buffer size %lu, "
                              @"Total input buffer size %lu. No unused buffer left. "
                              @"Increase buffer size.",
                              _FIRMessaging_UL(self.inputBufferLength),
                              _FIRMessaging_UL([self.inputBuffer length]));
      [self.inputBuffer increaseLengthBy:kBufferLengthIncrement];
      _FIRMessagingDevAssert([self.inputBuffer length] > self.inputBufferLength, @"Invalid buffer size");
    }

    while (self.inputBufferLength > 0 && [self.inputBuffer length] > 0) {
      _FIRMessagingDevAssert([self.inputBuffer length] >= self.inputBufferLength,
                             @"Buffer longer than length");
      NSRange inputRange = NSMakeRange(0, self.inputBufferLength);
      size_t protoBytes = 0;
      // read the actual proto data coming in
      FIRMessagingSecureSocketReadResult readResult =
          [self processCurrentInputBuffer:[self.inputBuffer subdataWithRange:inputRange]
                                outOffset:&protoBytes];
      // Corrupt data encountered, stop processing.
      if (readResult == kFIRMessagingSecureSocketReadResultCorrupt) {
        return NO;
        // Incomplete data, keep trying to read by loading more from the stream.
      } else if (readResult == kFIRMessagingSecureSocketReadResultIncomplete) {
        break;
      }
      _FIRMessagingDevAssert(self.inputBufferLength >= protoBytes, @"More bytes than buffer can handle");
      // we have read (0, protoBytes) of data in the inputBuffer
      if (protoBytes == self.inputBufferLength) {
        // did completely read the buffer data can be reset for further processing
        self.inputBufferLength = 0;
      } else {
        // delete processed bytes while maintaining the buffer size.
        NSUInteger prevLength __unused = [self.inputBuffer length];
        // delete the processed bytes
        [self.inputBuffer replaceBytesInRange:NSMakeRange(0, protoBytes) withBytes:NULL length:0];
        // reallocate more data
        [self.inputBuffer increaseLengthBy:protoBytes];
        _FIRMessagingDevAssert([self.inputBuffer length] == prevLength,
                               @"Invalid input buffer size %lu. Used bytes length %lu, "
                               @"buffer content: %@",
                               _FIRMessaging_UL([self.inputBuffer length]),
                               _FIRMessaging_UL(self.inputBufferLength),
                               self.inputBuffer);
        self.inputBufferLength -= protoBytes;
      }
    }
  }
  return YES;
}

- (FIRMessagingSecureSocketReadResult)processCurrentInputBuffer:(NSData *)readData
                                             outOffset:(size_t *)outOffset {
  *outOffset = 0;

  FIRMessagingCodedInputStream *input = [[FIRMessagingCodedInputStream alloc] initWithData:readData];
  int8_t rawTag;
  if (![input readTag:&rawTag]) {
    return kFIRMessagingSecureSocketReadResultIncomplete;
  }
  int32_t length;
  if (![input readLength:&length]) {
    return kFIRMessagingSecureSocketReadResultIncomplete;
  }
  // NOTE tag can be zero for |HeartbeatPing|, and length can be zero for |Close| proto
  _FIRMessagingDevAssert(rawTag >= 0 && length >= 0, @"Invalid tag or length");
  if (rawTag < 0 || length < 0) {
    FIRMessagingLoggerDebug(kFIRMessagingMessageCodeSecureSocket015, @"Buffer data corrupted.");
    return kFIRMessagingSecureSocketReadResultCorrupt;
  }
  NSData *data = [input readDataWithLength:(uint32_t)length];
  if (data == nil) {
    FIRMessagingLoggerDebug(kFIRMessagingMessageCodeSecureSocket016,
                            @"Incomplete data, buffered data length %ld, expected length %d",
                            _FIRMessaging_UL(self.inputBufferLength), length);
    return kFIRMessagingSecureSocketReadResultIncomplete;
  }
  [self.delegate secureSocket:self didReceiveData:data withTag:rawTag];
  *outOffset = input.offset;
  return kFIRMessagingSecureSocketReadResultSuccess;
}

- (void)performWrite {
  _FIRMessagingDevAssert(self.state == kFIRMessagingSecureSocketOpen, @"Invalid socket state");

  if (!self.isVersionSent) {
    self.isVersionSent = YES;
    uint8_t versionByte = kVersion;
    [self.outStream write:&versionByte maxLength:sizeof(uint8_t)];
  }

  while (!self.packetQueue.isEmpty && self.outStream.hasSpaceAvailable) {
    if (self.outputBuffer.length == 0) {
      // serialize new packets only when the output buffer is flushed.
      FIRMessagingPacket *packet = [self.packetQueue pop];
      self.currentRmqIdBeingSent = packet.rmqId;
      self.currentProtoTypeBeingSent = packet.tag;
      NSUInteger length = SerializedSize(packet.tag) +
          SerializedSize((int)packet.data.length) + packet.data.length;
      self.outputBuffer = [NSMutableData dataWithLength:length];
      GPBCodedOutputStream *output = [GPBCodedOutputStream streamWithData:self.outputBuffer];
      [output writeRawVarint32:packet.tag];
      [output writeBytesNoTag:packet.data];
      self.outputBufferLength = 0;
    }

    // flush the output buffer.
    NSInteger written = [self.outStream write:self.outputBuffer.bytes + self.outputBufferLength
                                    maxLength:self.outputBuffer.length - self.outputBufferLength];
    if (written <= 0) {
      continue;
    }
    self.outputBufferLength += (NSUInteger)written;
    if (self.outputBufferLength >= self.outputBuffer.length) {
      self.outputBufferLength = 0;
      self.outputBuffer = nil;
      [self.delegate secureSocket:self
              didSendProtoWithTag:self.currentProtoTypeBeingSent
                            rmqId:self.currentRmqIdBeingSent];
      self.currentRmqIdBeingSent = nil;
      self.currentProtoTypeBeingSent = kInvalidTag;
    }
  }
}

@end

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

#import "FirebaseMessaging/Sources/FIRMessagingCodedInputStream.h"

#import "FirebaseMessaging/Sources/FIRMMessageCode.h"
#import "FirebaseMessaging/Sources/FIRMessagingLogger.h"

typedef struct {
  const void *bytes;
  size_t bufferSize;
  size_t bufferPos;
} BufferState;

static BOOL CheckSize(BufferState *state, size_t size) {
  size_t newSize = state->bufferPos + size;
  if (newSize > state->bufferSize) {
    return NO;
  }
  return YES;
}

static BOOL ReadRawByte(BufferState *state, int8_t *output) {
  if (state == NULL || output == NULL) {
    FIRMessagingLoggerDebug(kFIRMessagingCodeInputStreamInvalidParameters, @"Invalid parameters.");
  }
  if (output != nil && CheckSize(state, sizeof(int8_t))) {
    *output = ((int8_t *)state->bytes)[state->bufferPos++];
    return YES;
  }
  return NO;
}

static BOOL ReadRawVarInt32(BufferState *state, int32_t *output) {
  if (state == NULL || output == NULL) {
    FIRMessagingLoggerDebug(kFIRMessagingCodeInputStreamInvalidParameters, @"Invalid parameters.");
    return NO;
  }
  int8_t tmp = 0;
  if (!ReadRawByte(state, &tmp)) {
    return NO;
  }
  if (tmp >= 0) {
    *output = tmp;
    return YES;
  }
  int32_t result = tmp & 0x7f;
  if (!ReadRawByte(state, &tmp)) {
    return NO;
  }
  if (tmp >= 0) {
    result |= tmp << 7;
  } else {
    result |= (tmp & 0x7f) << 7;
    if (!ReadRawByte(state, &tmp)) {
      return NO;
    }
    if (tmp >= 0) {
      result |= tmp << 14;
    } else {
      result |= (tmp & 0x7f) << 14;
      if (!ReadRawByte(state, &tmp)) {
        return NO;
      }
      if (tmp >= 0) {
        result |= tmp << 21;
      } else {
        result |= (tmp & 0x7f) << 21;
        if (!ReadRawByte(state, &tmp)) {
          return NO;
        }
        result |= tmp << 28;
        if (tmp < 0) {
          // Discard upper 32 bits.
          for (int i = 0; i < 5; ++i) {
            if (!ReadRawByte(state, &tmp)) {
              return NO;
            }
            if (tmp >= 0) {
              *output = result;
              return YES;
            }
          }
          return NO;
        }
      }
    }
  }
  *output = result;
  return YES;
}

@interface FIRMessagingCodedInputStream ()

@property(nonatomic, readwrite, strong) NSData *buffer;
@property(nonatomic, readwrite, assign) BufferState state;

@end

@implementation FIRMessagingCodedInputStream
;

- (instancetype)initWithData:(NSData *)data {
  self = [super init];
  if (self) {
    _buffer = data;
    _state.bytes = _buffer.bytes;
    _state.bufferSize = _buffer.length;
  }
  return self;
}

- (size_t)offset {
  return _state.bufferPos;
}

- (BOOL)readTag:(int8_t *)tag {
  return ReadRawByte(&_state, tag);
}

- (BOOL)readLength:(int32_t *)length {
  return ReadRawVarInt32(&_state, length);
}

- (NSData *)readDataWithLength:(uint32_t)length {
  if (!CheckSize(&_state, length)) {
    return nil;
  }
  const void *bytesToRead = _state.bytes + _state.bufferPos;
  NSData *result = [NSData dataWithBytes:bytesToRead length:length];
  _state.bufferPos += length;
  return result;
}

@end

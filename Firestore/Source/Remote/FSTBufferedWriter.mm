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

#import <Protobuf/GPBProtocolBuffers.h>

#import "Firestore/Source/Remote/FSTBufferedWriter.h"

NS_ASSUME_NONNULL_BEGIN

@implementation FSTBufferedWriter {
  GRXWriterState _state;
  NSMutableArray<NSData *> *_queue;

  id<GRXWriteable> _writeable;
}

- (instancetype)init {
  if (self = [super init]) {
    _state = GRXWriterStateNotStarted;
    _queue = [[NSMutableArray alloc] init];
  }
  return self;
}

#pragma mark - GRXWriteable implementation

/** Push the next value of the sequence to the receiving object. */
- (void)writeValue:(id)value {
  if (_state == GRXWriterStateStarted && _queue.count == 0) {
    // Skip the queue.
    [_writeable writeValue:value];
  } else {
    // Buffer the new value. Note that the value is assumed to be transient and doesn't need to
    // be copied.
    [_queue addObject:value];
  }
}

/**
 * Signal that the sequence is completed, or that an error ocurred. After this message is sent to
 * the receiver, neither it nor writeValue: may be called again.
 */
- (void)writesFinishedWithError:(nullable NSError *)error {
  // Unimplemented. If we ever wanted to implement sender-side initiated half close we could do so
  // by buffering (or sending) and error.
  [self doesNotRecognizeSelector:_cmd];
}

#pragma mark GRXWriter implementation
// The GRXWriter implementation defines the send side of the RPC stream. Once the RPC is ready it
// will call startWithWriteable passing a GRXWriteable into which requests can be written but only
// when the GRXWriter is in the started state.

/**
 * Called by GRPCCall when it is ready to accept for the first request. Requests should be written
 * to the passed writeable.
 *
 * GRPCCall will synchronize on the receiver around this call.
 */
- (void)startWithWriteable:(id<GRXWriteable>)writeable {
  _state = GRXWriterStateStarted;
  _writeable = writeable;
}

/**
 * Called by GRPCCall to implement flow control on the sending side of the stream. After each
 * writeValue: on the requestsWriteable, GRPCCall will call setState:GRXWriterStatePaused to apply
 * backpressure. Once the stream is ready to accept another message, GRPCCall will call
 * setState:GRXWriterStateStarted.
 *
 * GRPCCall will synchronize on the receiver around this call.
 */
- (void)setState:(GRXWriterState)newState {
  // Manual transitions are only allowed from the started or paused states.
  if (_state == GRXWriterStateNotStarted || _state == GRXWriterStateFinished) {
    return;
  }

  switch (newState) {
    case GRXWriterStateFinished:
      _state = newState;
      // Per GRXWriter's contract, setting the state to Finished manually means one doesn't wish the
      // writeable to be messaged anymore.
      _queue = nil;
      _writeable = nil;
      return;
    case GRXWriterStatePaused:
      _state = newState;
      return;
    case GRXWriterStateStarted:
      if (_state == GRXWriterStatePaused) {
        _state = newState;
        [self writeBufferedMessages];
      }
      return;
    case GRXWriterStateNotStarted:
      return;
  }
}

- (void)finishWithError:(nullable NSError *)error {
  [_writeable writesFinishedWithError:error];
  self.state = GRXWriterStateFinished;
}

- (void)writeBufferedMessages {
  while (_state == GRXWriterStateStarted && _queue.count > 0) {
    id value = _queue[0];
    [_queue removeObjectAtIndex:0];

    // In addition to writing the value here GRPC will apply backpressure by pausing the GRXWriter
    // wrapping this buffer. That writer must call -pauseMessages which will cause this loop to
    // exit. Synchronization is not required since the callback happens within the body of the
    // writeValue implementation.
    [_writeable writeValue:value];
  }
}

@end

NS_ASSUME_NONNULL_END

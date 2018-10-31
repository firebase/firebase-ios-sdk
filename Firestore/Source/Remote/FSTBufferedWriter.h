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
#import <RxLibrary/GRXWriteable.h>
#import <RxLibrary/GRXWriter.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * A buffered GRXWriter.
 *
 * GRPC only allows a single message to be written to a channel at a time. While the channel is
 * sending, GRPC sets the state of the GRXWriter representing the request stream to
 * GRXWriterStatePaused. Once the channel is ready to accept more messages GRPC sets the state of
 * the writer to GRXWriterStateStarted.
 *
 * This class is NOT thread safe, even though it is accessed from multiple threads. To conform with
 * the contract GRPC uses, all method calls on the FSTBufferedWriter must be @synchronized on the
 * receiver.
 */
@interface FSTBufferedWriter : GRXWriter <GRXWriteable>

/**
 * Writes a message into the buffer. Must be called inside an @synchronized block on the receiver.
 */
- (void)writeValue:(id)value;

@end

NS_ASSUME_NONNULL_END

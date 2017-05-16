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

@interface FIRMessagingFakeSocket : FIRMessagingSecureSocket

/**
 * Initialize socket with a given buffer size. Designated Initializer.
 *
 *  @param bufferSize  The buffer size used to connect the input and the output stream. Note
 *                     when we write data to the output stream it's read in terms of this buffer
 *                     size. So for tests using `FIRMessagingFakeSocket` you should use an appropriate
 *                     buffer size in terms of what you are writing to the buffer and what should
 *                     be read. Since there is no "flush" operation in NSStream we would have to
 *                     live with this.
 *
 *  @see {FIRMessagingSecureSocketTest} for example usage.
 *  @return A fake secure socket.
 */
- (instancetype)initWithBufferSize:(uint8_t)bufferSize;

@end

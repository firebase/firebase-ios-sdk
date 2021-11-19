/*
 * Copyright 2021 Google LLC
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

import GRPC
import NIOCore
import Darwin


@objc public class ByteBufferShim: NSObject {
    var buffer : ByteBuffer;
    
  /// Constuct an empty buffer.
    @objc public override init() {
            buffer = ByteBufferAllocator.init().buffer(capacity: 0);
    }
    
    @objc public init(slices: [SliceShim]) {
        buffer = ByteBufferAllocator.init().buffer(capacity: 0);
        super.init();
        Dump(slices: slices);
    }

  /// Buffer size in bytes.
    @objc public func Length() -> Int {
        return buffer.readableBytes;
    }
    
  /// Dump (read) the buffer contents into \a slices.
    @objc public func Dump(slices: [SliceShim]) -> Void {
        for slice in slices {
            buffer.writeBytes(UnsafeRawBufferPointer(start: slice.get(), count: slice.size()));
        }
    }
};


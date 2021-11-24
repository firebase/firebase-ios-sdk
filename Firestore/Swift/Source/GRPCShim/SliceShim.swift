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

import NIOCore

@objc public class SliceShim: NSObject {
  private let buffer: UnsafeMutablePointer<Int8>
  private let length: Int

  @objc public init(buf: UnsafePointer<Int8>, len: Int) {
    length = len
    buffer = UnsafeMutablePointer<Int8>.allocate(capacity: len)
    buffer.initialize(from: buf, count: len)
  }

  @objc public init(str: String) {
    buffer = strdup(str)
    length = str.lengthOfBytes(using: .utf8)
  }

  @objc public func size() -> Int {
    return length
  }

  @objc public func begin() -> UnsafeMutablePointer<Int8> {
    return buffer
  }
}

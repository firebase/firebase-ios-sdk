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

#include "Firestore/core/src/util/byte_stream_apple.h"

#include <string>
#include <utility>

#include "Firestore/core/src/util/string_apple.h"
#include "Firestore/core/src/util/string_util.h"

namespace firebase {
namespace firestore {
namespace util {

StreamReadResult ByteStreamApple::ReadUntil(char delim, size_t max_length) {
  size_t found_at = std::string::npos;
  size_t last_pos = 0;
  while (buffer_.size() < max_length) {
    auto read = ReadToBuffer(max_length - buffer_.size());
    if (read < 0) {
      return ErrorResult();
    }

    found_at = buffer_.find(delim, last_pos);
    last_pos = buffer_.size();
    if (found_at != std::string::npos || read == 0) {
      break;
    }
  }

  // One last try since the loop might break because eof or max_length reached.
  if (found_at == std::string::npos) {
    found_at = buffer_.find(delim);
  }

  // Still not found, return the whole `buffer_` and clear it.
  if (found_at == std::string::npos) {
    auto read_result = StreamReadResult(std::move(buffer_), eof());
    buffer_.clear();
    return read_result;
  }

  // Found, return the proper substring and erase the substring.
  std::string result = buffer_.substr(0, found_at);
  buffer_.erase(0, found_at);
  auto read_result = StreamReadResult(std::move(result), eof());
  return read_result;
}

StreamReadResult ByteStreamApple::Read(size_t max_length) {
  // Serve from buffer_
  if (buffer_.size() >= max_length) {
    std::string result = buffer_.substr(0, max_length);
    buffer_.erase(0, max_length);
    auto read_result = StreamReadResult(std::move(result), eof());
    return read_result;
  }

  auto read = ReadToBuffer(max_length - buffer_.size());
  if (read < 0) {
    return ErrorResult();
  }
  if (read == 0) {
    return EofResult();
  }

  auto read_result = StreamReadResult(std::move(buffer_), eof());
  buffer_.clear();
  return read_result;
}

int32_t ByteStreamApple::ReadToBuffer(size_t max_length) {
  std::string result(max_length + 1, '\0');
  auto* data_ptr = reinterpret_cast<uint8_t*>(&result[0]);
  NSInteger read = [input_ read:data_ptr maxLength:max_length];

  if (read > 0) {
    buffer_.append(result.substr(0, static_cast<unsigned long>(read)));
  }

  return static_cast<int32_t>(read);
}

StreamReadResult ByteStreamApple::EofResult() {
  return StreamReadResult(std::move(buffer_), true);
}

StreamReadResult ByteStreamApple::ErrorResult() {
  return StreamReadResult(
      Status::FromNSError(input_.streamError),
      input_.streamStatus == NSStreamStatus::NSStreamStatusAtEnd);
}

bool ByteStreamApple::eof() const {
  return buffer_.empty() &&
         input_.streamStatus == NSStreamStatus::NSStreamStatusAtEnd;
}

}  // namespace util
}  // namespace firestore
}  // namespace firebase

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

#include "Firestore/core/src/util/string_apple.h"
#include "Firestore/core/src/util/string_util.h"

namespace firebase {
namespace firestore {
namespace util {

StreamReadResult ByteStreamNSInputStream::ReadUntil(char delim, size_t max_length) {
  size_t found_at = std::string::npos;
  do {
    found_at = buffer_.find(delim);
    if(found_at != std::string::npos) {
      break;
    }
    auto read = ReadToBuffer(max_length - buffer_.size());
    if (read < 0) {
      return ErrorResult();
    }
    if(read == 0) {
      break;
    }

  } while(buffer_.size() < max_length);

  // One last try since the loop might break because eof or max_length reached.
  if(found_at == std::string::npos) {
    found_at = buffer_.find(delim);
  }

  // Still not found, return the whole `buffer_` and clear it.
  if(found_at == std::string::npos) {
    std::string buffer_copy(buffer_);
    buffer_.clear();
    auto read_result = StreamReadResult(
        std::move(buffer_copy),
        eof());
    return read_result;
  }

  // Found, return the proper substring and erase it.
  std::string result = buffer_.substr(0, found_at);
  buffer_.erase(0, found_at);
  auto read_result = StreamReadResult(
      std::move(result),
      eof());
  return read_result;
}

StreamReadResult ByteStreamNSInputStream::Read(size_t max_length) {
  if(input_.streamStatus == NSStreamStatus::NSStreamStatusError) {
    return ErrorResult();
  }
  if(input_.streamStatus == NSStreamStatus::NSStreamStatusAtEnd) {
    return EofResult();
  }
  if(input_.streamStatus != NSStreamStatus::NSStreamStatusOpen) {
    return StreamReadResult(
        Status::FromErrno(Error::kErrorDataLoss,
                          "Reading a NSInputStream that is not open"),
        eof());
  }

  auto read = ReadToBuffer(max_length);
  if (read < 0) {
    return ErrorResult();
  }
  if(read == 0) {
    return EofResult();
  }

  std::string buffer_copy(buffer_);
  buffer_.clear();
  auto read_result = StreamReadResult(
      std::move(buffer_),
      eof());
  return read_result;
}

int32_t ByteStreamNSInputStream::ReadToBuffer(size_t max_length) {
  std::string result(max_length + 1, '\0');
  auto* data_ptr = (uint8_t*)result.data();
  NSInteger read = [input_ read:data_ptr maxLength:max_length];

  if(read > 0) {
    buffer_.append(result.substr(0, static_cast<unsigned long>(read)));
  }

  return static_cast<int32_t>(read);
}

StreamReadResult ByteStreamNSInputStream::EofResult() {
  return StreamReadResult(
      buffer_,
      true);
}

StreamReadResult ByteStreamNSInputStream::ErrorResult(){
  std::string desc;
  if(input_.streamError != NULL) {
    desc = MakeString(input_.streamError.localizedDescription);
  }
  return StreamReadResult(
      Status::FromErrno(Error::kErrorDataLoss,
                        "Reading NSInputStream failed with error: " + desc),
      input_.streamStatus == NSStreamStatus::NSStreamStatusAtEnd);
}

bool ByteStreamNSInputStream::eof() {
  return buffer_.empty() && input_.streamStatus == NSStreamStatus::NSStreamStatusAtEnd;
}

}  // namespace util
}  // namespace firestore
}  // namespace firebase

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

#include "Firestore/core/test/unit/util/byte_stream_test.h"

#include <sstream>

#include "Firestore/core/src/util/byte_stream_cpp.h"
#include "absl/memory/memory.h"

namespace firebase {
namespace firestore {
namespace util {
namespace {

class ByteStreamCppFactory : public ByteStreamFactory {
  std::unique_ptr<ByteStream> CreateByteStream(
      const std::string& data) override {
    return absl::make_unique<ByteStreamCpp>(
        absl::make_unique<std::stringstream>(std::stringstream(data)));
  }
};

std::unique_ptr<ByteStreamFactory> ExecutorFactory() {
  return absl::make_unique<ByteStreamCppFactory>();
}

INSTANTIATE_TEST_SUITE_P(ByteStreamCppTest,
                         ByteStreamTest,
                         ::testing::Values(ExecutorFactory));

}  // namespace
}  // namespace util
}  // namespace firestore
}  // namespace firebase

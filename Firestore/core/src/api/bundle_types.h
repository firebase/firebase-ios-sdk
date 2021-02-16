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
#ifndef FIRESTORE_CORE_SRC_API_BUNDLE_TYPES_H_
#define FIRESTORE_CORE_SRC_API_BUNDLE_TYPES_H_

namespace firebase {
namespace firestore {

enum class TaskState { Error, Running, Success };

class LoadBundleTaskProgress {
 public:
  LoadBundleTaskProgress(uint32_t documents_loaded,
                         uint32_t total_documents,
                         uint64_t bytes_loaded,
                         uint64_t total_bytes,
                         TaskState state)
      : documents_loaded_(documents_loaded),
        total_documents_(total_documents),
        bytes_loaded_(bytes_loaded),
        total_bytes_(total_bytes),
        state_(state){};

  uint32_t documents_loaded() const {
    return documents_loaded_;
  }

  uint32_t total_documents() const {
    return total_documents_;
  }

  uint64_t bytes_loaded() const {
    return bytes_loaded_;
  }

  uint64_t total_bytes() const {
    return total_bytes_;
  }

  TaskState state() const {
    return state_;
  }

 private:
  uint32_t documents_loaded_ = 0;
  uint32_t total_documents_ = 0;
  uint64_t bytes_loaded_ = 0;
  uint64_t total_bytes_ = 0;
  TaskState state_ = TaskState::Running;
};

}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_API_BUNDLE_TYPES_H_

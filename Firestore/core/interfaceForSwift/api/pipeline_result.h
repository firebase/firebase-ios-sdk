// Copyright 2025 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#ifndef FIRESTORE_CORE_INTERFACEFORSWIFT_API_PIPELINE_RESULT_H_
#define FIRESTORE_CORE_INTERFACEFORSWIFT_API_PIPELINE_RESULT_H_

#include <atomic>
#include <iostream>
#include <memory>

namespace firebase {

class Timestamp;

namespace firestore {

namespace api {

class Firestore;
class DocumentReference;

extern std::atomic<int> next_id;

class PipelineResult {
 public:
  PipelineResult(std::shared_ptr<Firestore> firestore,
                 std::shared_ptr<Timestamp> execution_time,
                 std::shared_ptr<Timestamp> update_time,
                 std::shared_ptr<Timestamp> create_time);

  // Copy constructor
  PipelineResult(const PipelineResult& other)
      : id_(next_id.fetch_add(1)),
        firestore_(other.firestore_),
        execution_time_(other.execution_time_),
        update_time_(other.update_time_),
        create_time_(other.create_time_) {
    std::cout << "zzyzx PipelineResult[" << id_ << "]@"
              << reinterpret_cast<std::uintptr_t>(this)
              << "(const PipelineResult&) other.id=" << other.id_ << std::endl;
    long n = execution_time_.use_count();
    std::cout << "Calling copy ctor when refer count is:" << n << std::endl;
  }

  // Copy assignment operator
  PipelineResult& operator=(const PipelineResult& other) {
    std::cout << "zzyzx PipelineResult[" << id_ << "]@"
              << reinterpret_cast<std::uintptr_t>(this)
              << ".operator=(const PipelineResult&) other.id_=" << other.id_
              << std::endl;
    if (this != &other) {
      firestore_ = other.firestore_;
      execution_time_ = other.execution_time_;
      update_time_ = other.update_time_;
      create_time_ = other.create_time_;
    }
    return *this;
  }

  static PipelineResult GetTestResult(std::shared_ptr<Firestore> firestore);

  ~PipelineResult() {
    std::cout << "zzyzx PipelineResult[" << id_ << "]@"
              << reinterpret_cast<std::uintptr_t>(this) << "~PipelineResult()"
              << std::endl;
    long n = execution_time_.use_count();
    std::cout << "Calling destructor when refer count is:" << n << std::endl;
  }

  int id_;
  std::shared_ptr<Firestore> firestore_;
  std::shared_ptr<Timestamp> execution_time_;
  std::shared_ptr<Timestamp> update_time_;
  std::shared_ptr<Timestamp> create_time_;
};

}  // namespace api

}  // namespace firestore
}  // namespace firebase
#endif  // FIRESTORE_CORE_INTERFACEFORSWIFT_API_PIPELINE_RESULT_H_

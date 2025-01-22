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

#include <iostream>

#include "Firestore/core/include/firebase/firestore/timestamp.h"
#include "Firestore/core/interfaceForSwift/api/pipeline_result.h"

namespace firebase {
namespace firestore {

namespace api {

std::atomic<int> next_id(0);

PipelineResult::PipelineResult(std::shared_ptr<Firestore> firestore,
                               std::shared_ptr<Timestamp> execution_time,
                               std::shared_ptr<Timestamp> update_time,
                               std::shared_ptr<Timestamp> create_time)
    : id_(next_id.fetch_add(1)),
      firestore_(firestore),
      execution_time_(execution_time),
      update_time_(update_time),
      create_time_(create_time) {
  std::cout << "zzyzx PipelineResult[" << id_ << "]@"
            << reinterpret_cast<std::uintptr_t>(this) << "()" << std::endl;
}

PipelineResult PipelineResult::GetTestResult(
    std::shared_ptr<Firestore> firestore) {
  return PipelineResult(firestore, std::make_shared<Timestamp>(0, 0),
                        std::make_shared<Timestamp>(0, 0),
                        std::make_shared<Timestamp>(0, 0));
}

}  // namespace api

}  // namespace firestore
}  // namespace firebase

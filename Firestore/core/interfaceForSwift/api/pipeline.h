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

#ifndef FIRESTORE_CORE_INTERFACEFORSWIFT_API_PIPELINE_H_
#define FIRESTORE_CORE_INTERFACEFORSWIFT_API_PIPELINE_H_

#include <functional>
#include <memory>
#include <vector>
#include "pipeline_result.h"
#include "stage.h"

namespace firebase {
namespace firestore {

namespace core {
template <typename T>
class EventListener;
}  // namespace core

namespace api {

class Firestore;
class PipelineResult;

using PipelineSnapshotListener =
    std::unique_ptr<core::EventListener<std::vector<PipelineResult>>>;

class Pipeline {
 public:
  Pipeline(std::shared_ptr<Firestore> firestore, Stage stage);

  void GetPipelineResult(PipelineSnapshotListener callback) const;

  std::shared_ptr<Firestore> GetFirestore() const {
    return firestore_;
  }

 private:
  std::shared_ptr<Firestore> firestore_;
  Stage stage_;
};

}  // namespace api

}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_INTERFACEFORSWIFT_API_PIPELINE_H_

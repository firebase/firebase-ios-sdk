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

#ifndef FIRESTORE_CORE_INTERFACEFORSWIFT_API_PIPELINESOURCE_H_
#define FIRESTORE_CORE_INTERFACEFORSWIFT_API_PIPELINESOURCE_H_

#include <memory>
#include <string>
#include <vector>

#include "Pipeline.h"

namespace firebase {
namespace firestore {

namespace api {

class Firestore;
class DocumentReference;

class PipelineSource {
 public:
  explicit PipelineSource(std::shared_ptr<Firestore> firestore);

  Pipeline GetCollection(std::string collection_path) const;

  Pipeline GetCollectionGroup(std::string collection_id) const;

  Pipeline GetDatabase() const;

  Pipeline GetDocuments(std::vector<DocumentReference> docs) const;

 private:
  std::shared_ptr<Firestore> firestore_;
};

}  // namespace api

}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_INTERFACEFORSWIFT_API_PIPELINESOURCE_H_

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

#include "Firestore/core/interfaceForSwift/api/PipelineSource.h"

#include <string>

#include "Firestore/core/interfaceForSwift/api/CollectionStage.h"
#include "Firestore/core/src/api/document_reference.h"
#include "Firestore/core/src/api/firestore.h"

namespace firebase {
namespace firestore {

namespace api {

PipelineSource::PipelineSource(std::shared_ptr<Firestore> firestore)
    : firestore_(firestore) {
  std::cout << "PipelineSource constructs" << std::endl;
}

Pipeline PipelineSource::GetCollection(std::string collection_path) const {
  return {firestore_, Collection{collection_path}};
}

// TODO
Pipeline PipelineSource::GetCollectionGroup(std::string collection_id) const {
  return {firestore_, Collection{collection_id}};
}

Pipeline PipelineSource::GetDatabase() const {
  return {firestore_, Collection{"path"}};
}

// TODO
Pipeline PipelineSource::GetDocuments(std::vector<DocumentReference>) const {
  return {firestore_, Collection{"path"}};
}

}  // namespace api

}  // namespace firestore
}  // namespace firebase

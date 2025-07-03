/*
 * Copyright 2024 LLC
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

#include <string>
#include <vector>

#include "Firestore/core/src/api/api_fwd.h"
#include "Firestore/core/src/called_by_swift/include/pipeline.h"

namespace firebase {
namespace firestore {
namespace core {
class PipelineSource {
 public:
  explicit PipelineSource();

  // Creates a new Pipeline that operates on the specified Firestore collection.
  Pipeline GetCollection(const std::string collection_path);

  // Creates a new Pipeline that operates on a specific set of Firestore
  // documents.
  Pipeline GetDocuments(const std::vector<api::DocumentReference> docs);
};
}  // namespace core
}  // namespace firestore
}  // namespace firebase

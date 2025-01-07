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

#ifndef FIREBASE_COLLECTION_GROUP_STAGE_H
#define FIREBASE_COLLECTION_GROUP_STAGE_H

#include <string>
#include "stage.h"

namespace firebase {
namespace firestore {

namespace api {

class Collection : public Stage {
 public:
  Collection(std::string collection_path);

 private:
  std::string collection_path_;
};

}  // namespace api

}  // namespace firestore
}  // namespace firebase

#endif  // FIREBASE_COLLECTION_GROUP_STAGE_H

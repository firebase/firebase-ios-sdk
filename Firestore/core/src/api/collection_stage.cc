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

#include "Firestore/core/src/api/collection_stage.h"
#include <iostream>

namespace firebase {
namespace firestore {

namespace api {

Collection::Collection(std::string collection_path)
    : collection_path_(collection_path) {
  std::cout << "Calling Pipeline Collection ctor" << std::endl;
}

}  // namespace api

}  // namespace firestore
}  // namespace firebase

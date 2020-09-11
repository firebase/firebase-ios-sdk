// Copyright 2020 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#include "Firestore/core/src/api/compiler_info.h"

#include "Firestore/core/src/util/compiler_info.h"

namespace firebase {
namespace firestore {
namespace api {

std::string GetFullCompilerInfo() {
  return util::GetFullCompilerInfo();
}

}  // namespace api
}  // namespace firestore
}  // namespace firebase

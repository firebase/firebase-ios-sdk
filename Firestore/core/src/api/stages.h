/*
 * Copyright 2025 Google LLC
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

#ifndef FIRESTORE_CORE_SRC_API_STAGES_H_
#define FIRESTORE_CORE_SRC_API_STAGES_H_

#include <string>

#include "Firestore/Protos/nanopb/google/firestore/v1/document.nanopb.h"
#include "Firestore/core/src/api/expressions.h"

namespace firebase {
namespace firestore {
namespace api {

class Stage {
 public:
  Stage() = default;
  virtual ~Stage() = default;

  virtual google_firestore_v1_Pipeline_Stage to_proto() const = 0;
};

class CollectionSource : public Stage {
 public:
  CollectionSource(std::string path) : path_(path) {};
  ~CollectionSource() override = default;

  google_firestore_v1_Pipeline_Stage to_proto() const override;

 private:
  std::string path_;
};

class Where : public Stage {
 public:
  Where(std::shared_ptr<Expr> expr) : expr_(expr) {};
  ~Where() override = default;

  google_firestore_v1_Pipeline_Stage to_proto() const override;

 private:
  std::shared_ptr<Expr> expr_;
};

}  // namespace api
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_API_STAGES_H_

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

#include "Firestore/core/src/core/pipeline_util.h"

#include <utility>
#include <vector>

#include "Firestore/core/src/api/expressions.h"
#include "Firestore/core/src/api/realtime_pipeline.h"
#include "Firestore/core/src/api/stages.h"
#include "Firestore/core/src/model/mutable_document.h"
#include "Firestore/core/src/remote/serializer.h"

namespace firebase {
namespace firestore {
namespace core {

namespace {

auto NewKeyOrdering() {
  return api::Ordering(
      std::make_shared<api::Field>(model::FieldPath::KeyFieldPath()),
      api::Ordering::Direction::ASCENDING);
}

}  // namespace

std::vector<std::shared_ptr<api::EvaluableStage>> RewriteStages(
    const std::vector<std::shared_ptr<api::EvaluableStage>>& stages) {
  bool has_order = false;
  std::vector<std::shared_ptr<api::EvaluableStage>> new_stages;
  for (const auto& stage : stages) {
    // For stages that provide ordering semantics
    if (stage->name() == "sort") {
      auto sort_stage = std::static_pointer_cast<api::SortStage>(stage);
      has_order = true;

      // Ensure we have a stable ordering
      bool includes_key_ordering = false;
      for (const auto& order : sort_stage->orders()) {
        auto field = dynamic_cast<const api::Field*>(order.expr());
        if (field != nullptr && field->field_path().IsKeyFieldPath()) {
          includes_key_ordering = true;
          break;
        }
      }

      if (includes_key_ordering) {
        new_stages.push_back(stage);
      } else {
        auto copy = sort_stage->orders();
        copy.push_back(NewKeyOrdering());
        new_stages.push_back(std::make_shared<api::SortStage>(std::move(copy)));
      }
    } else if (stage->name() ==
               "limit") {  // For stages whose semantics depend on ordering
      if (!has_order) {
        new_stages.push_back(std::make_shared<api::SortStage>(
            std::vector<api::Ordering>{NewKeyOrdering()}));
        has_order = true;
      }
      new_stages.push_back(stage);
    } else {
      // TODO(wuandy): Handle add_fields and select and such
      new_stages.push_back(stage);
    }
  }

  if (!has_order) {
    new_stages.push_back(std::make_shared<api::SortStage>(
        std::vector<api::Ordering>{NewKeyOrdering()}));
  }

  return new_stages;
}

}  // namespace core
}  // namespace firestore
}  // namespace firebase

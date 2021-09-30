/*
 * Copyright 2019 Google
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

#ifndef FIRESTORE_CORE_TEST_UNIT_TESTUTIL_VIEW_TESTING_H_
#define FIRESTORE_CORE_TEST_UNIT_TESTUTIL_VIEW_TESTING_H_

#include <initializer_list>
#include <vector>

#include "Firestore/core/src/core/core_fwd.h"
#include "Firestore/core/src/model/model_fwd.h"
#include "absl/types/optional.h"

namespace firebase {
namespace firestore {

namespace remote {
class TargetChange;
}  // namespace remote

namespace testutil {

/** Converts a list of documents to a sorted map. */
model::DocumentMap DocUpdates(const std::vector<model::Document>& docs);

/**
 * Computes changes to the view with the docs and then applies them and returns
 * the snapshot.
 */
absl::optional<core::ViewSnapshot> ApplyChanges(
    core::View* view,
    const std::vector<model::Document>& docs,
    const absl::optional<remote::TargetChange>& target_change);

/**
 * Creates a test target change that acks all 'docs' and  marks the target as
 * CURRENT.
 */
remote::TargetChange AckTarget(model::DocumentKeySet docs);

remote::TargetChange AckTarget(std::initializer_list<model::Document> docs);

/** Creates a test target change that marks the target as CURRENT  */
remote::TargetChange MarkCurrent();

}  // namespace testutil
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_TEST_UNIT_TESTUTIL_VIEW_TESTING_H_

/*
 * Copyright 2022 Google LLC
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

#include "Firestore/core/src/model/target_index_matcher.h"

#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace model {

TEST(TargetIndexMatcher, CanUseMergeJoin) {
 Query q = query("collId").filter(filter("a", "==", 1)).filter(filter("b", "==", 2));
    validateServesTarget(q, "a", FieldIndex.Segment.Kind.ASCENDING);
    validateServesTarget(q, "b", FieldIndex.Segment.Kind.ASCENDING);

    q =
        query("collId")
            .filter(filter("a", "==", 1))
            .filter(filter("b", "==", 2))
            .orderBy(orderBy("__name__", "desc"));
    validateServesTarget(
        q, "a", FieldIndex.Segment.Kind.ASCENDING, "__name__", FieldIndex.Segment.Kind.DESCENDING);
    validateServesTarget(
        q, "b", FieldIndex.Segment.Kind.ASCENDING, "__name__", FieldIndex.Segment.Kind.DESCENDING);
}

}  //  namespace model
}  //  namespace firestore
}  //  namespace firebase

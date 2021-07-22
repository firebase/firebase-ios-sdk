/*
 * Copyright 2021 Google LLC
 *
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

#include "Firestore/core/src/nanopb/nanopb_util.h"
#include "Firestore/Protos/nanopb/google/firestore/v1/document.nanopb.h"
#include "Firestore/core/src/nanopb/message.h"
#include "Firestore/core/test/unit/testutil/testutil.h"

#include "gmock/gmock.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace nanopb {
namespace {

using testing::ElementsAre;
using testutil::Value;

TEST(NanopbUtilTest, SetsRepeatedField) {
  Message<google_firestore_v1_ArrayValue> m;
  std::vector<google_firestore_v1_Value> values{
      *Value(1).release(), *Value(2).release(), *Value(3).release()};
  SetRepeatedField(&m->values, &m->values_count, values);
  EXPECT_EQ(values, std::vector<google_firestore_v1_Value>(
                        m->values, m->values + m->values_count));
}

TEST(NanopbUtilTest, SetsRepeatedFieldWithConverter) {
  Message<google_firestore_v1_ArrayValue> m;
  std::vector<int> values{1, 2, 3};
  SetRepeatedField(&m->values, &m->values_count, values,
                   [](const int& v) { return *Value(v).release(); });
  EXPECT_THAT(std::vector<google_firestore_v1_Value>(
                  m->values, m->values + m->values_count),
              ElementsAre(*Value(1).release(), *Value(2).release(),
                          *Value(3).release()));
}

}  //  namespace
}  //  namespace nanopb
}  //  namespace firestore
}  //  namespace firebase

/*
 * Copyright 2018 Google
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

#include "Firestore/core/src/firebase/firestore/model/field_value.h"
#include "Firestore/core/src/firebase/firestore/util/firebase_assert.h"

namespace firebase {
namespace firestore {
namespace model {

int FieldValue::DefaultCompare(const FieldValue& other) const {
  int diff = type_order() - other.type_order();
  FIREBASE_ASSERT_MESSAGE_WITH_EXPRESSION(
      diff != 0, type_order() == other.type_order(),
      "Default compareTo should not be used for values of same type.");
  if (diff > 0) {
    return 1;
  } else {
    return -1;
  }
}

int NullValue::Compare(const FieldValue& other) const {
  if (type() == other.type()) {
    return 0;
  } else {
    return DefaultCompare(other);
  }
}

const NullValue NullValue::kInstance;

int BooleanValue::Compare(const FieldValue& other) const {
  if (type() == other.type()) {
    return value_ == static_cast<const BooleanValue&>(other).value_ ? 0 : value_ ? 1 : -1;
  } else {
    return DefaultCompare(other);
  }
}

const BooleanValue BooleanValue::kTrueValue(true);
const BooleanValue BooleanValue::kFalseValue(false);

}  // namespace model
}  // namespace firestore
}  // namespace firebase

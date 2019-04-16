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

#include "Firestore/core/src/firebase/firestore/model/field_value.h"

#import "Firestore/Source/Model/FSTFieldValue.h"

namespace firebase {
namespace firestore {
namespace model {

FSTFieldValue* FieldValue::Wrap() && {
  return [FSTDelegateValue delegateWithValue:std::move(*this)];
}

}  // namespace model
}  // namespace firestore
}  // namespace firebase

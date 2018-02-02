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

#include "Firestore/core/src/firebase/firestore/remote/serializer.h"

// TODO(rsgowman): These are (currently!) unnecessary includes. Adding for now
// to ensure we can find nanopb's generated header files.
#include "Firestore/Protos/nanopb/google/protobuf/timestamp.pb.h"
#include "Firestore/Protos/nanopb/google/firestore/v1beta1/document.pb.h"


namespace firebase {
namespace firestore {
namespace remote {

Serializer::Serializer() {
}

}  // namespace remote
}  // namespace firestore
}  // namespace firebase

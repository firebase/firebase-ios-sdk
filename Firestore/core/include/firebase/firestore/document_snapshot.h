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

#ifndef FIRESTORE_CORE_INCLUDE_FIREBASE_FIRESTORE_DOCUMENT_SNAPSHOT_H_
#define FIRESTORE_CORE_INCLUDE_FIREBASE_FIRESTORE_DOCUMENT_SNAPSHOT_H_

namespace firebase {
namespace firestore {

/**
 * A DocumentSnapshot contains data read from a document in your Firestore
 * database. The data can be extracted with the data() method or by using
 * FooValue() to access a specific field, where Foo is the type of that field.
 *
 * For a DocumentSnapshot that points to a non-existing document, any data
 * access will cause a failed assertion. You can use the exists() method to
 * explicitly verify a documents existence.
 */
// TODO(zxu123): add more methods to complete the class and make it useful.
class DocumentSnapshot {};

}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_INCLUDE_FIREBASE_FIRESTORE_DOCUMENT_SNAPSHOT_H_

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

#ifndef FSTFuzzTestSerializer_h
#define FSTFuzzTestSerializer_h

namespace firebase {
namespace firestore {
namespace fuzzing {

// Fuzz-test the deserialization process in Firestore. The Serializer reads raw
// bytes and converts them to a model object.
int FuzzTestDeserialization(const uint8_t *data, size_t size);

NSString *GetSerializerDictionaryLocation(NSString *resources_location);

// The location where the Serializer corpus is stored. This corpus is a special
// case because we generate its binary protos during the build process.
NSString *GetSerializerCorpusLocation(NSString *resources_location);

// Fuzz-test creating FIRFieldPath objects.
int FuzzTestFieldPath(const uint8_t *data, size_t size);

NSString *GetFieldPathDictionaryLocation(NSString *resources_location);

NSString *GetFieldPathCorpusLocation(NSString *resources_location);


}  // namespace fuzzing
}  // namespace firestore
}  // namespace firebase
#endif /* FSTFuzzTestSerializer_h */

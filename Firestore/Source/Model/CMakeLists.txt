# Copyright 2019 Google
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Public types to be used both internally and externally.
if(APPLE)
  cc_library(
    firebase_firestore_objc_model
    SOURCES
      FSTDocument.h
      FSTDocument.mm
      FSTDocumentKey.h
      FSTDocumentKey.mm
      FSTFieldValue.h
      FSTFieldValue.mm
      FSTMutation.h
      FSTMutation.mm
      FSTMutationBatch.h
      FSTMutationBatch.mm
    DEPENDS
      firebase_firestore_model
      firebase_firestore_objc_api
      firebase_firestore_objc_immutable
      firebase_firestore_util
  )

  target_compile_options(
    firebase_firestore_objc_model PRIVATE
    -Wno-unused-parameter
  )
endif()

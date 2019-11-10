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

if(APPLE)
  podspec_version(
    firestore_version
    ${PROJECT_SOURCE_DIR}/FirebaseFirestore.podspec
  )

  objc_framework(
    FirebaseFirestore
    HEADERS
      Public/FirebaseFirestore.h
      Public/FIRCollectionReference.h
      Public/FIRDocumentChange.h
      Public/FIRDocumentReference.h
      Public/FIRDocumentSnapshot.h
      Public/FIRFieldPath.h
      Public/FIRFieldValue.h
      Public/FIRFirestore.h
      Public/FIRFirestoreErrors.h
      Public/FIRFirestoreSettings.h
      Public/FIRFirestoreSource.h
      Public/FIRGeoPoint.h
      Public/FIRListenerRegistration.h
      Public/FIRQuery.h
      Public/FIRQuerySnapshot.h
      Public/FIRSnapshotMetadata.h
      Public/FIRTimestamp.h
      Public/FIRTransaction.h
      Public/FIRWriteBatch.h
    SOURCES
      API/FIRCollectionReference+Internal.h
      API/FIRCollectionReference.mm
      API/FIRDocumentChange+Internal.h
      API/FIRDocumentChange.mm
      API/FIRDocumentReference+Internal.h
      API/FIRDocumentReference.mm
      API/FIRDocumentSnapshot+Internal.h
      API/FIRDocumentSnapshot.mm
      API/FIRFieldPath+Internal.h
      API/FIRFieldPath.mm
      API/FIRFieldValue+Internal.h
      API/FIRFieldValue.mm
      API/FIRFirestore+Internal.h
      API/FIRFirestore.mm
      API/FIRFirestoreSettings+Internal.h
      API/FIRFirestoreSettings.mm
      API/FIRFirestoreSource+Internal.h
      API/FIRFirestoreSource.mm
      API/FIRFirestoreVersion.h
      API/FIRFirestoreVersion.mm
      API/FIRGeoPoint+Internal.h
      API/FIRGeoPoint.mm
      API/FIRListenerRegistration+Internal.h
      API/FIRListenerRegistration.mm
      API/FIRQuery+Internal.h
      API/FIRQuery.mm
      API/FIRQuerySnapshot+Internal.h
      API/FIRQuerySnapshot.mm
      API/FIRSnapshotMetadata+Internal.h
      API/FIRSnapshotMetadata.mm
      API/FIRTimestamp.m
      API/FIRTimestamp+Internal.h
      API/FIRTransaction+Internal.h
      API/FIRTransaction.mm
      API/FIRWriteBatch+Internal.h
      API/FIRWriteBatch.mm
      API/FSTFirestoreComponent.h
      API/FSTFirestoreComponent.mm
      API/FSTUserDataConverter.h
      API/FSTUserDataConverter.mm
      API/converters.h
      API/converters.mm
      Core/FSTTypes.h
      Util/FSTClasses.h
    DEPENDS
      absl_strings
      firebase_firestore_api
  )
endif()

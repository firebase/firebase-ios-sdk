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

#ifndef FIRESTORE_CORE_TEST_FIREBASE_FIRESTORE_TESTUTIL_XCGMOCK_H_
#define FIRESTORE_CORE_TEST_FIREBASE_FIRESTORE_TESTUTIL_XCGMOCK_H_

#if !defined(__OBJC__)
#error "This header only supports Objective-C++"
#endif  // !defined(__OBJC__)

#import <XCTest/XCTest.h>

#include <iostream>
#include <sstream>
#include <string>
#include <utility>

#include "Firestore/core/src/firebase/firestore/util/string_apple.h"
#include "gmock/gmock.h"

namespace firebase {
namespace firestore {
namespace testutil {

template <typename M>
class XcTestRecorder {
 public:
  XcTestRecorder(M matcher, XCTestCase* test_case, const char* file, int line)
      : formatter_(std::move(matcher)),
        test_case_(test_case),
        file_(file),
        line_(line) {
  }

  template <typename T>
  void Match(const char* text, const T& value) const {
    testing::AssertionResult result = formatter_(text, value);
    if (!result) {
      RecordFailure(result.message());
    }
  }

  void RecordFailure(const char* message) const {
    [test_case_
        recordFailureWithDescription:[NSString stringWithUTF8String:message]
                              inFile:[NSString stringWithUTF8String:file_]
                              atLine:line_
                            expected:true];
  }

 private:
  testing::internal::PredicateFormatterFromMatcher<M> formatter_;

  XCTestCase* test_case_;
  const char* file_;
  int line_;
};

template <typename M>
XcTestRecorder<M> MakeXcTestRecorder(M matcher,
                                     XCTestCase* test_case,
                                     const char* file,
                                     int line) {
  return XcTestRecorder<M>(std::move(matcher), test_case, file, line);
}

#define XC_ASSERT_THAT(actual, matcher)                                \
  do {                                                                 \
    auto recorder = firebase::firestore::testutil::MakeXcTestRecorder( \
        matcher, self, __FILE__, __LINE__);                            \
    recorder.Match(#actual, actual);                                   \
  } while (0)

/**
 * Prints the -description of an Objective-C object to the given ostream.
 */
inline void ObjcPrintTo(id value, std::ostream* os) {
  // Force the result type to NSString* or we can't resolve MakeString.
  NSString* description = [value description];
  *os << util::MakeString(description);
}

}  // namespace testutil
}  // namespace firestore
}  // namespace firebase

#define OBJC_PRINT_TO(objc_class)                            \
  @class objc_class;                                         \
  inline void PrintTo(objc_class* value, std::ostream* os) { \
    firebase::firestore::testutil::ObjcPrintTo(value, os);   \
  }

// Define overloads for Objective-C types. Note that each type must be
// explicitly overloaded here because `id` cannot be implicitly converted to
// void* under ARC. If `id` could be converted to void*, then a single overload
// of `operator<<` would be sufficient.

// Select Foundation types
OBJC_PRINT_TO(NSObject);
OBJC_PRINT_TO(NSArray);
OBJC_PRINT_TO(NSDictionary);
OBJC_PRINT_TO(NSNumber);
OBJC_PRINT_TO(NSString);

// Declare all Firestore Objective-C classes printable.
//
// Regenerate with:
// find Firestore/Source -name \*.h \
//   | xargs sed -n '/@interface/{ s/<.*//; p; }' \
//   | awk '{ print "OBJC_PRINT_TO(" $2 ");" }' \
//   | sort -u

OBJC_PRINT_TO(FIRCollectionReference);
OBJC_PRINT_TO(FIRDocumentChange);
OBJC_PRINT_TO(FIRDocumentReference);
OBJC_PRINT_TO(FIRDocumentSnapshot);
OBJC_PRINT_TO(FIRFieldPath);
OBJC_PRINT_TO(FIRFieldValue);
OBJC_PRINT_TO(FIRFirestore);
OBJC_PRINT_TO(FIRFirestoreSettings);
OBJC_PRINT_TO(FIRGeoPoint);
OBJC_PRINT_TO(FIRQuery);
OBJC_PRINT_TO(FIRQueryDocumentSnapshot);
OBJC_PRINT_TO(FIRQuerySnapshot);
OBJC_PRINT_TO(FIRSnapshotMetadata);
OBJC_PRINT_TO(FIRTimestamp);
OBJC_PRINT_TO(FIRTransaction);
OBJC_PRINT_TO(FIRWriteBatch);
OBJC_PRINT_TO(FSTArrayRemoveFieldValue);
OBJC_PRINT_TO(FSTArrayUnionFieldValue);
OBJC_PRINT_TO(FSTArrayValue);
OBJC_PRINT_TO(FSTDelegateValue);
OBJC_PRINT_TO(FSTDeleteFieldValue);
OBJC_PRINT_TO(FSTDocumentKeyReference);
OBJC_PRINT_TO(FSTDocumentSet);
OBJC_PRINT_TO(FSTEventManager);
OBJC_PRINT_TO(FSTFirestoreClient);
OBJC_PRINT_TO(FSTFirestoreComponent);
OBJC_PRINT_TO(FSTLRUGarbageCollector);
OBJC_PRINT_TO(FSTLevelDB);
OBJC_PRINT_TO(FSTLevelDBLRUDelegate);
OBJC_PRINT_TO(FSTListenerRegistration);
OBJC_PRINT_TO(FSTLocalDocumentsView);
OBJC_PRINT_TO(FSTLocalSerializer);
OBJC_PRINT_TO(FSTLocalStore);
OBJC_PRINT_TO(FSTLocalViewChanges);
OBJC_PRINT_TO(FSTLocalWriteResult);
OBJC_PRINT_TO(FSTMemoryEagerReferenceDelegate);
OBJC_PRINT_TO(FSTMemoryLRUReferenceDelegate);
OBJC_PRINT_TO(FSTMemoryPersistence);
OBJC_PRINT_TO(FSTNumericIncrementFieldValue);
OBJC_PRINT_TO(FSTSerializerBeta);
OBJC_PRINT_TO(FSTServerTimestampFieldValue);
OBJC_PRINT_TO(FSTStringValue);
OBJC_PRINT_TO(FSTSyncEngine);
OBJC_PRINT_TO(FSTUserDataConverter);

#endif  // FIRESTORE_CORE_TEST_FIREBASE_FIRESTORE_TESTUTIL_XCGMOCK_H_

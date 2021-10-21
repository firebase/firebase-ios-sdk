/*
 * Copyright 2017 Google
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

#import <Foundation/Foundation.h>

#include <string>
#include <vector>

#include "Firestore/Protos/nanopb/google/firestore/v1/document.nanopb.h"
#include "Firestore/core/src/model/model_fwd.h"
#include "Firestore/core/src/nanopb/message.h"
#include "absl/strings/string_view.h"

@class FIRGeoPoint;
@class FSTDocumentKeyReference;
@class FSTUserDataReader;

namespace model = firebase::firestore::model;

NS_ASSUME_NONNULL_BEGIN

/**
 * Takes an array of "equality group" arrays and asserts that the compare: selector returns the
 * same as compare: on the indexes of the "equality groups" (NSOrderedSame for items in the same
 * group).
 */
#define FSTAssertComparisons(values)                                                               \
  do {                                                                                             \
    for (NSUInteger i = 0; i < [values count]; i++) {                                              \
      for (id left in values[i]) {                                                                 \
        for (NSUInteger j = 0; j < [values count]; j++) {                                          \
          for (id right in values[j]) {                                                            \
            NSComparisonResult expected = [@(i) compare:@(j)];                                     \
            NSComparisonResult result = [left compare:right];                                      \
            NSComparisonResult inverseResult = [right compare:left];                               \
            XCTAssertEqual(result, expected, @"comparing %@ with %@ at (%lu, %lu)", left, right,   \
                           (unsigned long)i, (unsigned long)j);                                    \
            XCTAssertEqual(inverseResult, -expected, @"comparing %@ with %@ at (%lu, %lu)", right, \
                           left, (unsigned long)j, (unsigned long)i);                              \
          }                                                                                        \
        }                                                                                          \
      }                                                                                            \
    }                                                                                              \
  } while (0)

static NSString *kExceptionPrefix = @"FIRESTORE INTERNAL ASSERTION FAILED: ";

// Remove possible exception-prefix.
inline NSString *FSTRemoveExceptionPrefix(NSString *exception) {
  if ([exception hasPrefix:kExceptionPrefix]) {
    return [exception substringFromIndex:kExceptionPrefix.length];
  } else {
    return exception;
  }
}

inline NSString *FSTTakeMessagePrefix(NSString *exception, NSInteger length) {
  return [exception substringToIndex:length];
}

// Helper for validating API exceptions.
#define FSTAssertThrows(expression, exceptionReason, ...)               \
  do {                                                                  \
    BOOL didThrow = NO;                                                 \
    @try {                                                              \
      (void)(expression);                                               \
    } @catch (NSException * exception) {                                \
      didThrow = YES;                                                   \
      XCTAssertEqualObjects(FSTRemoveExceptionPrefix(exception.reason), \
                            FSTRemoveExceptionPrefix(exceptionReason)); \
    }                                                                   \
    XCTAssertTrue(didThrow, ##__VA_ARGS__);                             \
  } while (0)

// Helper for validating API exceptions.
#define FSTAssertExceptionPrefix(expression, prefix, ...)                   \
  do {                                                                      \
    BOOL didThrow = NO;                                                     \
    @try {                                                                  \
      (void)(expression);                                                   \
    } @catch (NSException * exception) {                                    \
      didThrow = YES;                                                       \
      NSString *expectedMessage = FSTRemoveExceptionPrefix(prefix);         \
      NSString *actualMessage = FSTRemoveExceptionPrefix(exception.reason); \
      NSInteger length = expectedMessage.length;                            \
      XCTAssertEqualObjects(FSTTakeMessagePrefix(actualMessage, length),    \
                            FSTTakeMessagePrefix(expectedMessage, length)); \
    }                                                                       \
    XCTAssertTrue(didThrow, ##__VA_ARGS__);                                 \
  } while (0)

/** Creates a new NSDate from components. Note that year, month, and day are all one-based. */
NSDate *FSTTestDate(int year, int month, int day, int hour, int minute, int second);

/**
 * Creates a new NSData from the var args of bytes, must be terminated with a negative byte
 */
NSData *FSTTestData(int bytes, ...);

// Note that FIRGeoPoint is a model class in addition to an API class, so we put this helper here
// instead of FSTAPIHelpers.h
/** Creates a new GeoPoint from the latitude and longitude values */
FIRGeoPoint *FSTTestGeoPoint(double latitude, double longitude);

/** Creates a user data converter set up for a generic project. */
FSTUserDataReader *FSTTestUserDataReader();

/**
 * Creates a new NSDateComponents from components. Note that year, month, and day are all
 * one-based.
 */
NSDateComponents *FSTTestDateComponents(
    int year, int month, int day, int hour, int minute, int second);

/** Wraps a plain value into a Message proto. */
firebase::firestore::nanopb::Message<firebase::firestore::google_firestore_v1_Value>
    FSTTestFieldValue(id _Nullable value);

/** Wraps a NSDictionary value into an ObjectValue instance. */
model::ObjectValue FSTTestObjectValue(NSDictionary<NSString *, id> *data);

/** A convenience method for creating document keys for tests. */
model::DocumentKey FSTTestDocKey(NSString *path);

/** Allow tests to just use an int literal for versions. */
typedef int64_t FSTTestSnapshotVersion;

/**
 * A convenience method for creating a document reference from a path string.
 */
FSTDocumentKeyReference *FSTTestRef(std::string projectID, std::string databaseID, NSString *path);

/** Creates a set mutation for the document key at the given path. */
model::SetMutation FSTTestSetMutation(NSString *path, NSDictionary<NSString *, id> *values);

/** Creates a patch mutation for the document key at the given path. */
model::PatchMutation FSTTestPatchMutation(
    NSString *path,
    NSDictionary<NSString *, id> *values,
    const std::vector<firebase::firestore::model::FieldPath> &updateMask);

/** Creates a delete mutation for the document key at the given path. */
model::DeleteMutation FSTTestDeleteMutation(NSString *path);

NS_ASSUME_NONNULL_END

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

#import "Firestore/Source/API/FIRDocumentReference+Internal.h"
#import "Firestore/Source/Core/FSTTypes.h"
#import "Firestore/Source/Model/FSTDocumentDictionary.h"
#import "Firestore/Source/Model/FSTDocumentKeySet.h"

@class FIRGeoPoint;
@class FSTDeleteMutation;
@class FSTDeletedDocument;
@class FSTDocument;
@class FSTDocumentKeyReference;
@class FSTDocumentSet;
@class FSTFieldPath;
@class FSTFieldValue;
@class FSTLocalViewChanges;
@class FSTPatchMutation;
@class FSTQuery;
@class FSTRemoteEvent;
@class FSTResourceName;
@class FSTResourcePath;
@class FSTSetMutation;
@class FSTSnapshotVersion;
@class FSTSortOrder;
@class FSTTargetChange;
@class FSTTimestamp;
@class FSTTransformMutation;
@class FSTView;
@class FSTViewSnapshot;
@class FSTObjectValue;
@protocol FSTFilter;

NS_ASSUME_NONNULL_BEGIN

#if __cplusplus
extern "C" {
#endif

#define FSTAssertIsKindOfClass(value, classType)             \
  do {                                                       \
    XCTAssertEqualObjects([value class], [classType class]); \
  } while (0);

/**
 * Asserts that the given NSSet of FSTDocumentKeys contains exactly the given expected keys.
 * This is a macro instead of a method so that the failure shows up on the right line.
 *
 * @param actualSet An NSSet of FSTDocumentKeys.
 * @param expectedArray A sorted array of keys that actualSet must be equal to (after converting
 *     to an array and sorting).
 */
#define FSTAssertEqualSets(actualSet, expectedArray)                \
  do {                                                              \
    NSArray<FSTDocumentKey *> *actual = [(actualSet)allObjects];    \
    actual = [actual sortedArrayUsingSelector:@selector(compare:)]; \
    XCTAssertEqualObjects(actual, (expectedArray));                 \
  } while (0)

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
                           i, j);                                                                  \
            XCTAssertEqual(inverseResult, -expected, @"comparing %@ with %@ at (%lu, %lu)", right, \
                           left, j, i);                                                            \
          }                                                                                        \
        }                                                                                          \
      }                                                                                            \
    }                                                                                              \
  } while (0)

/**
 * Takes an array of "equality group" arrays and asserts that the isEqual: selector returns TRUE
 * if-and-only-if items are in the same group.
 *
 * Additionally checks that the hash: selector returns the same value for items in the same group.
 */
#define FSTAssertEqualityGroups(values)                                                          \
  do {                                                                                           \
    for (NSUInteger i = 0; i < [values count]; i++) {                                            \
      for (id left in values[i]) {                                                               \
        for (NSUInteger j = 0; j < [values count]; j++) {                                        \
          for (id right in values[j]) {                                                          \
            if (i == j) {                                                                        \
              XCTAssertEqualObjects(left, right);                                                \
              XCTAssertEqual([left hash], [right hash], @"comparing hash of %@ with hash of %@", \
                             left, right);                                                       \
            } else {                                                                             \
              XCTAssertNotEqualObjects(left, right);                                             \
            }                                                                                    \
          }                                                                                      \
        }                                                                                        \
      }                                                                                          \
    }                                                                                            \
  } while (0)

// Helper for validating API exceptions.
#define FSTAssertThrows(expression, exceptionReason, ...)       \
  ({                                                            \
    BOOL __didThrow = NO;                                       \
    @try {                                                      \
      (void)(expression);                                       \
    } @catch (NSException * exception) {                        \
      __didThrow = YES;                                         \
      XCTAssertEqualObjects(exception.reason, exceptionReason); \
    }                                                           \
    XCTAssertTrue(__didThrow, ##__VA_ARGS__);                   \
  })

/** Creates a new FSTTimestamp from components. Note that year, month, and day are all one-based. */
FSTTimestamp *FSTTestTimestamp(int year, int month, int day, int hour, int minute, int second);

/** Creates a new NSDate from components. Note that year, month, and day are all one-based. */
NSDate *FSTTestDate(int year, int month, int day, int hour, int minute, int second);

/**
 * Creates a new NSData from the var args of bytes, must be terminated with a negative byte
 */
NSData *FSTTestData(int bytes, ...);

/** Creates a new GeoPoint from the latitude and longitude values */
FIRGeoPoint *FSTTestGeoPoint(double latitude, double longitude);

/**
 * Creates a new NSDateComponents from components. Note that year, month, and day are all
 * one-based.
 */
NSDateComponents *FSTTestDateComponents(
    int year, int month, int day, int hour, int minute, int second);

FSTFieldPath *FSTTestFieldPath(NSString *field);

/** Wraps a plain value into an FSTFieldValue instance. */
FSTFieldValue *FSTTestFieldValue(id _Nullable value);

/** Wraps a NSDictionary value into an FSTObjectValue instance. */
FSTObjectValue *FSTTestObjectValue(NSDictionary<NSString *, id> *data);

/** A convenience method for creating document keys for tests. */
FSTDocumentKey *FSTTestDocKey(NSString *path);

/** A convenience method for creating a document key set for tests. */
FSTDocumentKeySet *FSTTestDocKeySet(NSArray<FSTDocumentKey *> *keys);

/** Allow tests to just use an int literal for versions. */
typedef int64_t FSTTestSnapshotVersion;

/** A convenience method for creating snapshot versions for tests. */
FSTSnapshotVersion *FSTTestVersion(FSTTestSnapshotVersion version);

/** A convenience method for creating docs for tests. */
FSTDocument *FSTTestDoc(NSString *path,
                        FSTTestSnapshotVersion version,
                        NSDictionary<NSString *, id> *data,
                        BOOL hasMutations);

/** A convenience method for creating deleted docs for tests. */
FSTDeletedDocument *FSTTestDeletedDoc(NSString *path, FSTTestSnapshotVersion version);

/** A convenience method for creating resource paths from a path string. */
FSTResourcePath *FSTTestPath(NSString *path);

/**
 * A convenience method for creating a document reference from a path string.
 */
FSTDocumentKeyReference *FSTTestRef(NSString *projectID, NSString *databaseID, NSString *path);

/** A convenience method for creating a query for the given path (without any other filters). */
FSTQuery *FSTTestQuery(NSString *path);

/**
 * A convenience method to create a FSTFilter using a string representation for both field
 * and operator (<, <=, ==, >=, >).
 */
id<FSTFilter> FSTTestFilter(NSString *field, NSString *op, id value);

/** A convenience method for creating sort orders. */
FSTSortOrder *FSTTestOrderBy(NSString *field, NSString *direction);

/**
 * Creates an NSComparator that will compare FSTDocuments by the given fieldPath string then by
 * key.
 */
NSComparator FSTTestDocComparator(NSString *fieldPath);

/**
 * Creates a FSTDocumentSet based on the given comparator, initially containing the given
 * documents.
 */
FSTDocumentSet *FSTTestDocSet(NSComparator comp, NSArray<FSTDocument *> *docs);

/** Computes changes to the view with the docs and then applies them and returns the snapshot. */
FSTViewSnapshot *_Nullable FSTTestApplyChanges(FSTView *view,
                                               NSArray<FSTMaybeDocument *> *docs,
                                               FSTTargetChange *_Nullable targetChange);

/** Creates a set mutation for the document key at the given path. */
FSTSetMutation *FSTTestSetMutation(NSString *path, NSDictionary<NSString *, id> *values);

/** Creates a patch mutation for the document key at the given path. */
FSTPatchMutation *FSTTestPatchMutation(NSString *path,
                                       NSDictionary<NSString *, id> *values,
                                       NSArray<FSTFieldPath *> *_Nullable updateMask);

FSTTransformMutation *FSTTestTransformMutation(NSString *path,
                                               NSArray<NSString *> *serverTimestampFields);

/** Creates a delete mutation for the document key at the given path. */
FSTDeleteMutation *FSTTestDeleteMutation(NSString *path);

/** Converts a list of documents to a sorted map. */
FSTMaybeDocumentDictionary *FSTTestDocUpdates(NSArray<FSTMaybeDocument *> *docs);

/** Creates a remote event with changes to a document. */
FSTRemoteEvent *FSTTestUpdateRemoteEvent(FSTMaybeDocument *doc,
                                         NSArray<NSNumber *> *updatedInTargets,
                                         NSArray<NSNumber *> *removedFromTargets);

/** Creates a test view changes. */
FSTLocalViewChanges *FSTTestViewChanges(FSTQuery *query,
                                        NSArray<NSString *> *addedKeys,
                                        NSArray<NSString *> *removedKeys);

/** Creates a resume token to match the given snapshot version. */
NSData *_Nullable FSTTestResumeTokenFromSnapshotVersion(FSTTestSnapshotVersion watchSnapshot);

#if __cplusplus
}  // extern "C"
#endif

NS_ASSUME_NONNULL_END

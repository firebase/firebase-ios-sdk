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

#include <vector>

#import "Firestore/Source/Core/FSTTypes.h"
#import "Firestore/Source/Model/FSTDocumentDictionary.h"
#import "Firestore/Source/Remote/FSTRemoteEvent.h"

#include "Firestore/core/src/firebase/firestore/model/field_path.h"
#include "Firestore/core/src/firebase/firestore/model/field_value.h"
#include "Firestore/core/src/firebase/firestore/model/resource_path.h"
#include "absl/strings/string_view.h"

@class FIRGeoPoint;
@class FSTDeleteMutation;
@class FSTDeletedDocument;
@class FSTDocument;
@class FSTDocumentKeyReference;
@class FSTDocumentSet;
@class FSTFieldValue;
@class FSTFilter;
@class FSTLocalViewChanges;
@class FSTPatchMutation;
@class FSTQuery;
@class FSTRemoteEvent;
@class FSTSetMutation;
@class FSTSortOrder;
@class FSTTargetChange;
@class FIRTimestamp;
@class FSTTransformMutation;
@class FSTView;
@class FSTViewSnapshot;
@class FSTObjectValue;

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

static NSString *kExceptionPrefix = @"FIRESTORE INTERNAL ASSERTION FAILED: ";

// Remove possible exception-prefix.
inline NSString *FSTRemoveExceptionPrefix(NSString *exception) {
  if ([exception hasPrefix:kExceptionPrefix]) {
    return [exception substringFromIndex:kExceptionPrefix.length];
  } else {
    return exception;
  }
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

/**
 * An implementation of FSTTargetMetadataProvider that provides controlled access to the
 * `FSTTargetMetadataProvider` callbacks. Any target accessed via these callbacks must be
 * registered beforehand via the factory methods or via `setSyncedKeys:forQueryData:`.
 */
@interface FSTTestTargetMetadataProvider : NSObject <FSTTargetMetadataProvider>

/**
 * Creates an FSTTestTargetMetadataProvider that behaves as if there's an established listen for
 * each of the given targets, where each target has previously seen query results containing just
 * the given documentKey.
 *
 * Internally this means that the `remoteKeysForTarget` callback for these targets will return just
 * the documentKey and that the provided targets will be returned as active from the
 * `queryDataForTarget` target.
 */
+ (instancetype)providerWithSingleResultForKey:(firebase::firestore::model::DocumentKey)documentKey
                                       targets:(NSArray<FSTBoxedTargetID *> *)targets;

/**
 * Creates an FSTTestTargetMetadataProvider that behaves as if there's an established listen for
 * each of the given targets, where each target has not seen any previous document.
 *
 * Internally this means that the `remoteKeysForTarget` callback for these targets will return an
 * empty set of document keys and that the provided targets will be returned as active from the
 * `queryDataForTarget` target.
 */
+ (instancetype)providerWithEmptyResultForKey:(firebase::firestore::model::DocumentKey)documentKey
                                      targets:(NSArray<FSTBoxedTargetID *> *)targets;

/** Sets or replaces the local state for the provided query data. */
- (void)setSyncedKeys:(firebase::firestore::model::DocumentKeySet)keys
         forQueryData:(FSTQueryData *)queryData;

@end

/** Creates a new FIRTimestamp from components. Note that year, month, and day are all one-based. */
FIRTimestamp *FSTTestTimestamp(int year, int month, int day, int hour, int minute, int second);

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

/**
 * Creates a new NSDateComponents from components. Note that year, month, and day are all
 * one-based.
 */
NSDateComponents *FSTTestDateComponents(
    int year, int month, int day, int hour, int minute, int second);

/** Wraps a plain value into an FSTFieldValue instance. */
FSTFieldValue *FSTTestFieldValue(id _Nullable value);

/** Wraps a NSDictionary value into an FSTObjectValue instance. */
FSTObjectValue *FSTTestObjectValue(NSDictionary<NSString *, id> *data);

/** A convenience method for creating document keys for tests. */
FSTDocumentKey *FSTTestDocKey(NSString *path);

/** Allow tests to just use an int literal for versions. */
typedef int64_t FSTTestSnapshotVersion;

/** A convenience method for creating docs for tests. */
FSTDocument *FSTTestDoc(const absl::string_view path,
                        FSTTestSnapshotVersion version,
                        NSDictionary<NSString *, id> *data,
                        BOOL hasMutations);

/** A convenience method for creating deleted docs for tests. */
FSTDeletedDocument *FSTTestDeletedDoc(const absl::string_view path, FSTTestSnapshotVersion version);

/**
 * A convenience method for creating a document reference from a path string.
 */
FSTDocumentKeyReference *FSTTestRef(const absl::string_view projectID,
                                    const absl::string_view databaseID,
                                    NSString *path);

/** A convenience method for creating a query for the given path (without any other filters). */
FSTQuery *FSTTestQuery(const absl::string_view path);

/**
 * A convenience method to create a FSTFilter using a string representation for both field
 * and operator (<, <=, ==, >=, >, array_contains).
 */
FSTFilter *FSTTestFilter(const absl::string_view field, NSString *op, id value);

/** A convenience method for creating sort orders. */
FSTSortOrder *FSTTestOrderBy(const absl::string_view field, NSString *direction);

/**
 * Creates an NSComparator that will compare FSTDocuments by the given fieldPath string then by
 * key.
 */
NSComparator FSTTestDocComparator(const absl::string_view fieldPath);

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
FSTPatchMutation *FSTTestPatchMutation(
    const absl::string_view path,
    NSDictionary<NSString *, id> *values,
    const std::vector<firebase::firestore::model::FieldPath> &updateMask);

/**
 * Creates a FSTTransformMutation by parsing any FIRFieldValue sentinels in the provided data. The
 * data is expected to use dotted-notation for nested fields (i.e.
 * @{ @"foo.bar": [FIRFieldValue ...] } and must not contain any non-sentinel data.
 */
FSTTransformMutation *FSTTestTransformMutation(NSString *path, NSDictionary<NSString *, id> *data);

/** Creates a delete mutation for the document key at the given path. */
FSTDeleteMutation *FSTTestDeleteMutation(NSString *path);

/** Converts a list of documents to a sorted map. */
FSTMaybeDocumentDictionary *FSTTestDocUpdates(NSArray<FSTMaybeDocument *> *docs);

/** Creates a remote event that inserts a new document. */
FSTRemoteEvent *FSTTestAddedRemoteEvent(FSTMaybeDocument *doc, NSArray<NSNumber *> *addedToTargets);

/** Creates a remote event with changes to a document. */
FSTRemoteEvent *FSTTestUpdateRemoteEvent(FSTMaybeDocument *doc,
                                         NSArray<NSNumber *> *updatedInTargets,
                                         NSArray<NSNumber *> *removedFromTargets);

/** Creates a test view changes. */
FSTLocalViewChanges *FSTTestViewChanges(FSTQuery *query,
                                        NSArray<NSString *> *addedKeys,
                                        NSArray<NSString *> *removedKeys);

/** Creates a test target change that acks all 'docs' and  marks the target as CURRENT  */
FSTTargetChange *FSTTestTargetChangeAckDocuments(firebase::firestore::model::DocumentKeySet docs);

/** Creates a test target change that marks the target as CURRENT  */
FSTTargetChange *FSTTestTargetChangeMarkCurrent();

/** Creates a test target change. */
FSTTargetChange *FSTTestTargetChange(firebase::firestore::model::DocumentKeySet added,
                                     firebase::firestore::model::DocumentKeySet modified,
                                     firebase::firestore::model::DocumentKeySet removed,
                                     NSData *resumeToken,
                                     BOOL current);

/** Creates a resume token to match the given snapshot version. */
NSData *_Nullable FSTTestResumeTokenFromSnapshotVersion(FSTTestSnapshotVersion watchSnapshot);

#if __cplusplus
}  // extern "C"
#endif

NS_ASSUME_NONNULL_END

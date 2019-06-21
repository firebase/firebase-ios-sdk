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
#include <unordered_map>
#include <vector>

#import "Firestore/Source/Model/FSTDocument.h"

#include "Firestore/core/src/firebase/firestore/core/view_snapshot.h"
#include "Firestore/core/src/firebase/firestore/model/document_map.h"
#include "Firestore/core/src/firebase/firestore/model/document_set.h"
#include "Firestore/core/src/firebase/firestore/model/field_path.h"
#include "Firestore/core/src/firebase/firestore/model/field_value.h"
#include "Firestore/core/src/firebase/firestore/model/resource_path.h"
#include "Firestore/core/src/firebase/firestore/model/types.h"
#include "Firestore/core/src/firebase/firestore/remote/remote_event.h"
#include "absl/strings/string_view.h"
#include "absl/types/optional.h"

@class FIRGeoPoint;
@class FSTDeleteMutation;
@class FSTDeletedDocument;
@class FSTDocument;
@class FSTDocumentKeyReference;
@class FSTFilter;
@class FSTLocalViewChanges;
@class FSTPatchMutation;
@class FSTQuery;
@class FSTSetMutation;
@class FSTSortOrder;
@class FIRTimestamp;
@class FSTTransformMutation;
@class FSTView;
@class FSTObjectValue;

namespace firebase {
namespace firestore {
namespace remote {

class RemoteEvent;

}  // namespace remote
}  // namespace firestore
}  // namespace firebase

namespace model = firebase::firestore::model;

NS_ASSUME_NONNULL_BEGIN

#define FSTAssertIsKindOfClass(value, classType)             \
  do {                                                       \
    XCTAssertEqualObjects([value class], [classType class]); \
  } while (0);

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

// Helper to compare vectors containing Objective-C objects.
#define FSTAssertEqualVectors(v1, v2)                                \
  do {                                                               \
    XCTAssertEqual(v1.size(), v2.size(), @"Vector length mismatch"); \
    for (size_t i = 0; i < v1.size(); i++) {                         \
      XCTAssertEqualObjects(v1[i], v2[i]);                           \
    }                                                                \
  } while (0)

/**
 * An implementation of `TargetMetadataProvider` that provides controlled access to the
 * `TargetMetadataProvider` callbacks. Any target accessed via these callbacks must be
 * registered beforehand via the factory methods or via `setSyncedKeys:forQueryData:`.
 */
namespace firebase {
namespace firestore {
namespace remote {

class TestTargetMetadataProvider : public TargetMetadataProvider {
 public:
  /**
   * Creates a `TestTargetMetadataProvider` that behaves as if there's an established listen for
   * each of the given targets, where each target has previously seen query results containing just
   * the given `document_key`.
   *
   * Internally this means that the `GetRemoteKeysForTarget` callback for these targets will return
   * just the `document_key` and that the provided targets will be returned as active from the
   * `GetQueryDataForTarget` target.
   */
  static TestTargetMetadataProvider CreateSingleResultProvider(
      model::DocumentKey document_key, const std::vector<model::TargetId> &targets);
  static TestTargetMetadataProvider CreateSingleResultProvider(
      model::DocumentKey document_key,
      const std::vector<model::TargetId> &targets,
      const std::vector<model::TargetId> &limbo_targets);

  /**
   * Creates an `TestTargetMetadataProvider` that behaves as if there's an established listen for
   * each of the given targets, where each target has not seen any previous document.
   *
   * Internally this means that the `GetRemoteKeysForTarget` callback for these targets will return
   * an empty set of document keys and that the provided targets will be returned as active from the
   * `GetQueryDataForTarget` target.
   */
  static TestTargetMetadataProvider CreateEmptyResultProvider(
      const model::DocumentKey &document_key, const std::vector<model::TargetId> &targets);

  /** Sets or replaces the local state for the provided query data. */
  void SetSyncedKeys(model::DocumentKeySet keys, FSTQueryData *query_data);

  model::DocumentKeySet GetRemoteKeysForTarget(model::TargetId target_id) const override;
  FSTQueryData *GetQueryDataForTarget(model::TargetId target_id) const override;

 private:
  std::unordered_map<model::TargetId, model::DocumentKeySet> synced_keys_;
  std::unordered_map<model::TargetId, FSTQueryData *> query_data_;
};

}  // namespace remote
}  // namespace firestore
}  // namespace firebase

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

/** Wraps a plain value into an FieldValue instance. */
model::FieldValue FSTTestFieldValue(id _Nullable value);

/** Wraps a NSDictionary value into an FSTObjectValue instance. */
model::ObjectValue FSTTestObjectValue(NSDictionary<NSString *, id> *data);

/** A convenience method for creating document keys for tests. */
firebase::firestore::model::DocumentKey FSTTestDocKey(NSString *path);

/** Allow tests to just use an int literal for versions. */
typedef int64_t FSTTestSnapshotVersion;

/** A convenience method for creating docs for tests. */
FSTDocument *FSTTestDoc(const absl::string_view path,
                        FSTTestSnapshotVersion version,
                        NSDictionary<NSString *, id> *data,
                        model::DocumentState documentState);

/** A convenience method for creating deleted docs for tests. */
FSTDeletedDocument *FSTTestDeletedDoc(const absl::string_view path,
                                      FSTTestSnapshotVersion version,
                                      BOOL hasCommittedMutations);

/** A convenience method for creating unknown docs for tests. */
FSTUnknownDocument *FSTTestUnknownDoc(const absl::string_view path, FSTTestSnapshotVersion version);
/**
 * A convenience method for creating a document reference from a path string.
 */
FSTDocumentKeyReference *FSTTestRef(std::string projectID, std::string databaseID, NSString *path);

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
model::DocumentComparator FSTTestDocComparator(const absl::string_view fieldPath);

/**
 * Creates a DocumentSet based on the given comparator, initially containing the given
 * documents.
 */
model::DocumentSet FSTTestDocSet(model::DocumentComparator comp, NSArray<FSTDocument *> *docs);

/** Computes changes to the view with the docs and then applies them and returns the snapshot. */
absl::optional<firebase::firestore::core::ViewSnapshot> FSTTestApplyChanges(
    FSTView *view,
    NSArray<FSTMaybeDocument *> *docs,
    const absl::optional<firebase::firestore::remote::TargetChange> &targetChange);

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
firebase::firestore::model::MaybeDocumentMap FSTTestDocUpdates(NSArray<FSTMaybeDocument *> *docs);

/** Creates a remote event that inserts a new document. */
firebase::firestore::remote::RemoteEvent FSTTestAddedRemoteEvent(
    FSTMaybeDocument *doc, const std::vector<firebase::firestore::model::TargetId> &addedToTargets);

/** Creates a remote event with changes to a document. */
firebase::firestore::remote::RemoteEvent FSTTestUpdateRemoteEvent(
    FSTMaybeDocument *doc,
    const std::vector<firebase::firestore::model::TargetId> &updatedInTargets,
    const std::vector<firebase::firestore::model::TargetId> &removedFromTargets);

/** Creates a remote event with changes to a document. Allows for identifying limbo targets */
firebase::firestore::remote::RemoteEvent FSTTestUpdateRemoteEventWithLimboTargets(
    FSTMaybeDocument *doc,
    const std::vector<firebase::firestore::model::TargetId> &updatedInTargets,
    const std::vector<firebase::firestore::model::TargetId> &removedFromTargets,
    const std::vector<firebase::firestore::model::TargetId> &limboTargets);

/** Creates a test view changes. */
FSTLocalViewChanges *FSTTestViewChanges(firebase::firestore::model::TargetId targetID,
                                        NSArray<NSString *> *addedKeys,
                                        NSArray<NSString *> *removedKeys);

/** Creates a test target change that acks all 'docs' and  marks the target as CURRENT  */
firebase::firestore::remote::TargetChange FSTTestTargetChangeAckDocuments(
    firebase::firestore::model::DocumentKeySet docs);

/** Creates a test target change that marks the target as CURRENT  */
firebase::firestore::remote::TargetChange FSTTestTargetChangeMarkCurrent();

/** Creates a resume token to match the given snapshot version. */
NSData *_Nullable FSTTestResumeTokenFromSnapshotVersion(FSTTestSnapshotVersion watchSnapshot);

NS_ASSUME_NONNULL_END

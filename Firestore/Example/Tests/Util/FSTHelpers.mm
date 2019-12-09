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

#import "Firestore/Example/Tests/Util/FSTHelpers.h"

#import <FirebaseFirestore/FIRFieldPath.h>
#import <FirebaseFirestore/FIRGeoPoint.h>
#import <FirebaseFirestore/FIRTimestamp.h>

#include <cinttypes>
#include <list>
#include <set>
#include <utility>

#import "Firestore/Source/API/FIRFieldPath+Internal.h"
#import "Firestore/Source/API/FSTUserDataConverter.h"

#include "Firestore/core/src/firebase/firestore/core/filter.h"
#include "Firestore/core/src/firebase/firestore/core/view.h"
#include "Firestore/core/src/firebase/firestore/core/view_snapshot.h"
#include "Firestore/core/src/firebase/firestore/local/local_view_changes.h"
#include "Firestore/core/src/firebase/firestore/local/query_data.h"
#include "Firestore/core/src/firebase/firestore/model/database_id.h"
#include "Firestore/core/src/firebase/firestore/model/delete_mutation.h"
#include "Firestore/core/src/firebase/firestore/model/document.h"
#include "Firestore/core/src/firebase/firestore/model/document_key.h"
#include "Firestore/core/src/firebase/firestore/model/document_key_set.h"
#include "Firestore/core/src/firebase/firestore/model/document_set.h"
#include "Firestore/core/src/firebase/firestore/model/field_mask.h"
#include "Firestore/core/src/firebase/firestore/model/field_transform.h"
#include "Firestore/core/src/firebase/firestore/model/field_value.h"
#include "Firestore/core/src/firebase/firestore/model/patch_mutation.h"
#include "Firestore/core/src/firebase/firestore/model/precondition.h"
#include "Firestore/core/src/firebase/firestore/model/resource_path.h"
#include "Firestore/core/src/firebase/firestore/model/set_mutation.h"
#include "Firestore/core/src/firebase/firestore/model/transform_mutation.h"
#include "Firestore/core/src/firebase/firestore/model/transform_operation.h"
#include "Firestore/core/src/firebase/firestore/remote/remote_event.h"
#include "Firestore/core/src/firebase/firestore/remote/watch_change.h"
#include "Firestore/core/src/firebase/firestore/util/string_apple.h"
#include "Firestore/core/test/firebase/firestore/remote/fake_target_metadata_provider.h"
#include "Firestore/core/test/firebase/firestore/testutil/testutil.h"
#include "absl/memory/memory.h"

namespace testutil = firebase::firestore::testutil;
namespace util = firebase::firestore::util;
using firebase::firestore::core::Direction;
using firebase::firestore::core::Filter;
using firebase::firestore::core::ParsedUpdateData;
using firebase::firestore::core::Query;
using firebase::firestore::core::View;
using firebase::firestore::core::ViewChange;
using firebase::firestore::core::ViewSnapshot;
using firebase::firestore::local::LocalViewChanges;
using firebase::firestore::local::QueryData;
using firebase::firestore::local::QueryPurpose;
using firebase::firestore::model::DatabaseId;
using firebase::firestore::model::DeleteMutation;
using firebase::firestore::model::Document;
using firebase::firestore::model::DocumentComparator;
using firebase::firestore::model::DocumentKey;
using firebase::firestore::model::DocumentKeySet;
using firebase::firestore::model::DocumentSet;
using firebase::firestore::model::DocumentState;
using firebase::firestore::model::FieldMask;
using firebase::firestore::model::FieldPath;
using firebase::firestore::model::FieldTransform;
using firebase::firestore::model::FieldValue;
using firebase::firestore::model::MaybeDocument;
using firebase::firestore::model::MaybeDocumentMap;
using firebase::firestore::model::NoDocument;
using firebase::firestore::model::ObjectValue;
using firebase::firestore::model::PatchMutation;
using firebase::firestore::model::Precondition;
using firebase::firestore::model::ResourcePath;
using firebase::firestore::model::SetMutation;
using firebase::firestore::model::ServerTimestampTransform;
using firebase::firestore::model::SnapshotVersion;
using firebase::firestore::model::TargetId;
using firebase::firestore::model::TransformMutation;
using firebase::firestore::model::TransformOperation;
using firebase::firestore::model::UnknownDocument;
using firebase::firestore::nanopb::ByteString;
using firebase::firestore::remote::DocumentWatchChange;
using firebase::firestore::remote::FakeTargetMetadataProvider;
using firebase::firestore::remote::RemoteEvent;
using firebase::firestore::remote::TargetChange;
using firebase::firestore::remote::WatchChangeAggregator;
using firebase::firestore::testutil::OrderBy;
using firebase::firestore::testutil::Query;

NS_ASSUME_NONNULL_BEGIN

/** A string sentinel that can be used with FSTTestPatchMutation() to mark a field for deletion. */
static NSString *const kDeleteSentinel = @"<DELETE>";

FIRTimestamp *FSTTestTimestamp(int year, int month, int day, int hour, int minute, int second) {
  NSDate *date = FSTTestDate(year, month, day, hour, minute, second);
  return [FIRTimestamp timestampWithDate:date];
}

NSDate *FSTTestDate(int year, int month, int day, int hour, int minute, int second) {
  NSDateComponents *comps = FSTTestDateComponents(year, month, day, hour, minute, second);
  return [[NSCalendar currentCalendar] dateFromComponents:comps];
}

NSData *FSTTestData(int bytes, ...) {
  va_list args;
  va_start(args, bytes); /* Initialize the argument list. */

  NSMutableData *data = [NSMutableData data];

  int next = bytes;
  while (next >= 0) {
    uint8_t byte = (uint8_t)next;
    [data appendBytes:&byte length:1];
    next = va_arg(args, int);
  }

  va_end(args);
  return [data copy];
}

FIRGeoPoint *FSTTestGeoPoint(double latitude, double longitude) {
  return [[FIRGeoPoint alloc] initWithLatitude:latitude longitude:longitude];
}

NSDateComponents *FSTTestDateComponents(
    int year, int month, int day, int hour, int minute, int second) {
  NSDateComponents *comps = [[NSDateComponents alloc] init];
  comps.year = year;
  comps.month = month;
  comps.day = day;
  comps.hour = hour;
  comps.minute = minute;
  comps.second = second;

  // Force time zone to UTC to avoid these values changing due to daylight saving.
  comps.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
  return comps;
}

FSTUserDataConverter *FSTTestUserDataConverter() {
  FSTUserDataConverter *converter =
      [[FSTUserDataConverter alloc] initWithDatabaseID:DatabaseId("project")
                                          preConverter:^id _Nullable(id _Nullable input) {
                                            return input;
                                          }];
  return converter;
}

FieldValue FSTTestFieldValue(id _Nullable value) {
  FSTUserDataConverter *converter = FSTTestUserDataConverter();
  // HACK: We use parsedQueryValue: since it accepts scalars as well as arrays / objects, and
  // our tests currently use FSTTestFieldValue() pretty generically so we don't know the intent.
  return [converter parsedQueryValue:value];
}

ObjectValue FSTTestObjectValue(NSDictionary<NSString *, id> *data) {
  FieldValue wrapped = FSTTestFieldValue(data);
  HARD_ASSERT(wrapped.type() == FieldValue::Type::Object, "Unsupported value: %s", data);
  return ObjectValue(std::move(wrapped));
}

DocumentKey FSTTestDocKey(NSString *path) {
  return DocumentKey::FromPathString(util::MakeString(path));
}

FSTDocumentKeyReference *FSTTestRef(std::string projectID, std::string database, NSString *path) {
  return [[FSTDocumentKeyReference alloc] initWithKey:FSTTestDocKey(path)
                                           databaseID:DatabaseId(projectID, database)];
}

SetMutation FSTTestSetMutation(NSString *path, NSDictionary<NSString *, id> *values) {
  return SetMutation(FSTTestDocKey(path), FSTTestObjectValue(values), Precondition::None());
}

PatchMutation FSTTestPatchMutation(const absl::string_view path,
                                   NSDictionary<NSString *, id> *values,
                                   const std::vector<FieldPath> &updateMask) {
  BOOL merge = !updateMask.empty();

  __block ObjectValue objectValue = ObjectValue::Empty();
  __block std::set<FieldPath> fieldMaskPaths;
  [values enumerateKeysAndObjectsUsingBlock:^(NSString *key, id value, BOOL *stop) {
    const FieldPath path = testutil::Field(util::MakeString(key));
    fieldMaskPaths.insert(path);
    if (![value isEqual:kDeleteSentinel]) {
      FieldValue parsedValue = FSTTestFieldValue(value);
      objectValue = objectValue.Set(path, std::move(parsedValue));
    }
  }];

  DocumentKey key = testutil::Key(path);
  Precondition precondition = merge ? Precondition::None() : Precondition::Exists(true);
  FieldMask mask(merge ? std::set<FieldPath>(updateMask.begin(), updateMask.end())
                       : fieldMaskPaths);
  return PatchMutation(key, objectValue, mask, precondition);
}

TransformMutation FSTTestTransformMutation(NSString *path, NSDictionary<NSString *, id> *data) {
  DocumentKey key{testutil::Resource(util::MakeString(path))};
  FSTUserDataConverter *converter = FSTTestUserDataConverter();
  ParsedUpdateData result = [converter parsedUpdateData:data];
  HARD_ASSERT(result.data().size() == 0,
              "FSTTestTransformMutation() only expects transforms; no other data");
  return TransformMutation(key, result.field_transforms());
}

DeleteMutation FSTTestDeleteMutation(NSString *path) {
  return DeleteMutation(FSTTestDocKey(path), Precondition::None());
}

MaybeDocumentMap FSTTestDocUpdates(const std::vector<MaybeDocument> &docs) {
  MaybeDocumentMap updates;
  for (const MaybeDocument &doc : docs) {
    updates = updates.insert(doc.key(), doc);
  }
  return updates;
}

absl::optional<ViewSnapshot> FSTTestApplyChanges(View *view,
                                                 const std::vector<MaybeDocument> &docs,
                                                 const absl::optional<TargetChange> &targetChange) {
  ViewChange change =
      view->ApplyChanges(view->ComputeDocumentChanges(FSTTestDocUpdates(docs)), targetChange);
  return change.snapshot();
}

RemoteEvent FSTTestAddedRemoteEvent(const MaybeDocument &doc,
                                    const std::vector<TargetId> &addedToTargets) {
  std::vector<MaybeDocument> docs{doc};
  return FSTTestAddedRemoteEvent(docs, addedToTargets);
}

RemoteEvent FSTTestAddedRemoteEvent(const std::vector<MaybeDocument> &docs,
                                    const std::vector<TargetId> &addedToTargets) {
  HARD_ASSERT(!docs.empty(), "Cannot pass empty docs array");

  const ResourcePath &collectionPath = docs[0].key().path().PopLast();
  auto metadataProvider =
      FakeTargetMetadataProvider::CreateEmptyResultProvider(collectionPath, addedToTargets);
  WatchChangeAggregator aggregator{&metadataProvider};
  for (const MaybeDocument &doc : docs) {
    HARD_ASSERT(!doc.is_document() || !Document(doc).has_local_mutations(),
                "Docs from remote updates shouldn't have local changes.");
    DocumentWatchChange change{addedToTargets, {}, doc.key(), doc};
    aggregator.HandleDocumentChange(change);
  }
  return aggregator.CreateRemoteEvent(docs[0].version());
}

TargetChange FSTTestTargetChangeMarkCurrent() {
  return {ByteString(),
          /*current=*/true,
          /*added_documents=*/DocumentKeySet{},
          /*modified_documents=*/DocumentKeySet{},
          /*removed_documents=*/DocumentKeySet{}};
}

TargetChange FSTTestTargetChangeAckDocuments(DocumentKeySet docs) {
  return {ByteString(),
          /*current=*/true,
          /*added_documents*/ std::move(docs),
          /*modified_documents*/ DocumentKeySet{},
          /*removed_documents*/ DocumentKeySet{}};
}

RemoteEvent FSTTestUpdateRemoteEventWithLimboTargets(
    const MaybeDocument &doc,
    const std::vector<TargetId> &updatedInTargets,
    const std::vector<TargetId> &removedFromTargets,
    const std::vector<TargetId> &limboTargets) {
  HARD_ASSERT(!doc.is_document() || !Document(doc).has_local_mutations(),
              "Docs from remote updates shouldn't have local changes.");
  DocumentWatchChange change{updatedInTargets, removedFromTargets, doc.key(), doc};

  std::vector<TargetId> listens = updatedInTargets;
  listens.insert(listens.end(), removedFromTargets.begin(), removedFromTargets.end());

  auto metadataProvider =
      FakeTargetMetadataProvider::CreateSingleResultProvider(doc.key(), listens, limboTargets);
  WatchChangeAggregator aggregator{&metadataProvider};
  aggregator.HandleDocumentChange(change);
  return aggregator.CreateRemoteEvent(doc.version());
}

RemoteEvent FSTTestUpdateRemoteEvent(const MaybeDocument &doc,
                                     const std::vector<TargetId> &updatedInTargets,
                                     const std::vector<TargetId> &removedFromTargets) {
  return FSTTestUpdateRemoteEventWithLimboTargets(doc, updatedInTargets, removedFromTargets, {});
}

/** Creates a resume token to match the given snapshot version. */
NSData *_Nullable FSTTestResumeTokenFromSnapshotVersion(FSTTestSnapshotVersion snapshotVersion) {
  if (snapshotVersion == 0) {
    return nil;
  }

  NSString *snapshotString = [NSString stringWithFormat:@"snapshot-%" PRId64, snapshotVersion];
  return [snapshotString dataUsingEncoding:NSUTF8StringEncoding];
}

LocalViewChanges TestViewChanges(TargetId targetID,
                                 NSArray<NSString *> *addedKeys,
                                 NSArray<NSString *> *removedKeys) {
  DocumentKeySet added;
  for (NSString *keyPath in addedKeys) {
    added = added.insert(testutil::Key(util::MakeString(keyPath)));
  }
  DocumentKeySet removed;
  for (NSString *keyPath in removedKeys) {
    removed = removed.insert(testutil::Key(util::MakeString(keyPath)));
  }
  return LocalViewChanges(targetID, std::move(added), std::move(removed));
}

NS_ASSUME_NONNULL_END

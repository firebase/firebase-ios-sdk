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

#import <FirebaseFirestore/FIRFieldValue.h>
#import <FirebaseFirestore/FIRGeoPoint.h>

#include <set>

#import "Firestore/Source/API/FSTUserDataConverter.h"

#include "Firestore/core/src/core/user_data.h"
#include "Firestore/core/src/model/delete_mutation.h"
#include "Firestore/core/src/model/patch_mutation.h"
#include "Firestore/core/src/model/resource_path.h"
#include "Firestore/core/src/model/set_mutation.h"

#import <Firestore/core/test/unit/testutil/testutil.h>

namespace testutil = firebase::firestore::testutil;
namespace util = firebase::firestore::util;

using firebase::firestore::core::ParsedSetData;
using firebase::firestore::core::ParsedUpdateData;
using firebase::firestore::model::DatabaseId;
using firebase::firestore::model::DeleteMutation;
using firebase::firestore::model::DocumentKey;
using firebase::firestore::model::FieldMask;
using firebase::firestore::model::FieldPath;
using firebase::firestore::model::FieldValue;
using firebase::firestore::model::ObjectValue;
using firebase::firestore::model::PatchMutation;
using firebase::firestore::model::Precondition;
using firebase::firestore::model::SetMutation;

NS_ASSUME_NONNULL_BEGIN

/** A string sentinel that can be used with FSTTestPatchMutation() to mark a field for deletion. */
static NSString *const kDeleteSentinel = @"<DELETE>";

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
  FSTUserDataConverter *converter = FSTTestUserDataConverter();
  ParsedSetData result = [converter parsedSetData:values];
  return SetMutation(FSTTestDocKey(path), result.data(), Precondition::None(),
                     result.field_transforms());
}

PatchMutation FSTTestPatchMutation(NSString *path,
                                   NSDictionary<NSString *, id> *values,
                                   const std::vector<FieldPath> &updateMask) {
  // Replace '<DELETE>' sentinel from JSON.
  NSMutableDictionary *mutableValues = [values mutableCopy];
  [mutableValues enumerateKeysAndObjectsUsingBlock:^(NSString *key, id value, BOOL *) {
    if ([value isEqual:kDeleteSentinel]) {
      const FieldPath fieldPath = testutil::Field(util::MakeString(key));
      mutableValues[key] = [FIRFieldValue fieldValueForDelete];
    }
  }];

  FSTUserDataConverter *converter = FSTTestUserDataConverter();
  ParsedUpdateData parsed = [converter parsedUpdateData:mutableValues];

  DocumentKey key = FSTTestDocKey(path);

  BOOL merge = !updateMask.empty();
  Precondition precondition = merge ? Precondition::None() : Precondition::Exists(true);
  return PatchMutation(key, parsed.data(), parsed.fieldMask(), precondition,
                       parsed.field_transforms());
}

DeleteMutation FSTTestDeleteMutation(NSString *path) {
  return DeleteMutation(FSTTestDocKey(path), Precondition::None());
}

NS_ASSUME_NONNULL_END

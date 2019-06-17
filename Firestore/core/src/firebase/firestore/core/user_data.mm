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

#include "Firestore/core/src/firebase/firestore/core/user_data.h"

#include <utility>

#import "Firestore/Source/Model/FSTMutation.h"

#include "Firestore/core/src/firebase/firestore/api/input_validation.h"
#include "absl/strings/match.h"

namespace firebase {
namespace firestore {
namespace core {

using api::ThrowInvalidArgument;
using model::DocumentKey;
using model::FieldMask;
using model::FieldPath;
using model::FieldTransform;
using model::ObjectValue;
using model::Precondition;
using model::TransformOperation;

#pragma mark - ParseAccumulator

ParseContext ParseAccumulator::RootContext() {
  return ParseContext{
      this, absl::make_unique<FieldPath>(FieldPath::EmptyPath()), false};
}

bool ParseAccumulator::Contains(const FieldPath& field_path) const {
  for (const FieldPath& field : field_mask_) {
    if (field_path.IsPrefixOf(field)) {
      return true;
    }
  }

  for (const FieldTransform& field_transform : field_transforms_) {
    if (field_path.IsPrefixOf(field_transform.path())) {
      return true;
    }
  }

  return false;
}

void ParseAccumulator::AddToFieldMask(FieldPath field_path) {
  field_mask_.insert(std::move(field_path));
}

void ParseAccumulator::AddToFieldTransforms(
    FieldPath field_path,
    std::unique_ptr<TransformOperation> transform_operation) {
  field_transforms_.emplace_back(std::move(field_path),
                                 std::move(transform_operation));
}

ParsedSetData ParseAccumulator::MergeData(ObjectValue data) && {
  return ParsedSetData{std::move(data), FieldMask{std::move(field_mask_)},
                       std::move(field_transforms_)};
}

ParsedSetData ParseAccumulator::MergeData(ObjectValue data,
                                          model::FieldMask user_field_mask) && {
  std::vector<FieldTransform> covered_field_transforms;

  for (FieldTransform& field_transform : field_transforms_) {
    if (user_field_mask.covers(field_transform.path())) {
      covered_field_transforms.push_back(std::move(field_transform));
    }
  }

  return ParsedSetData{std::move(data), std::move(user_field_mask),
                       std::move(covered_field_transforms)};
}

ParsedSetData ParseAccumulator::SetData(ObjectValue data) && {
  return ParsedSetData{std::move(data), std::move(field_transforms_)};
}

ParsedUpdateData ParseAccumulator::UpdateData(ObjectValue data) && {
  return ParsedUpdateData{data, FieldMask{std::move(field_mask_)},
                          std::move(field_transforms_)};
}

#pragma mark - ParseContext

namespace {

const char* RESERVED_FIELD_DESIGNATOR = "__";

}  // namespace

ParseContext ParseContext::ChildContext(const std::string& field_name) {
  std::unique_ptr<FieldPath> path;
  if (path_) {
    path = absl::make_unique<FieldPath>(path_->Append(field_name));
  }

  ParseContext context{accumulator_, std::move(path), false};
  context.ValidatePathSegment(field_name);
  return context;
}

ParseContext ParseContext::ChildContext(const FieldPath& fieldPath) {
  std::unique_ptr<FieldPath> path;
  if (path_) {
    path = absl::make_unique<FieldPath>(path_->Append(fieldPath));
  }

  ParseContext context{accumulator_, std::move(path), false};
  context.ValidatePath();
  return context;
}

ParseContext ParseContext::ChildContext(size_t array_index) {
  // TODO(b/34871131): We don't support array paths right now; make path null.
  (void)array_index;
  return {accumulator_, /* path= */ nullptr, /* array_element= */ true};
}

/**
 * Returns a string that can be appended to error messages indicating what field
 * caused the error.
 */
std::string ParseContext::FieldDescription() const {
  // TODO(b/34871131): Remove nullptr check once we have proper paths for fields
  // within arrays.
  if (!path_ || path_->empty()) {
    return "";
  } else {
    return util::StringFormat(" (found in field %s)", path_->CanonicalString());
  }
}

bool ParseContext::write() const {
  switch (accumulator_->data_source()) {
    case UserDataSource::Set:       // Falls through.
    case UserDataSource::MergeSet:  // Falls through.
    case UserDataSource::Update:
      return true;
    case UserDataSource::Argument:
      return false;
    default:
      ThrowInvalidArgument("Unexpected case for UserDataSource: %s",
                           accumulator_->data_source());
  }
}

void ParseContext::ValidatePath() const {
  // TODO(b/34871131): Remove nullptr check once we have proper paths for fields
  // within arrays.
  if (!path_) {
    return;
  }
  for (const std::string& segment : *path_) {
    ValidatePathSegment(segment);
  }
}

void ParseContext::ValidatePathSegment(absl::string_view segment) const {
  absl::string_view designator{RESERVED_FIELD_DESIGNATOR};
  if (write() && absl::StartsWith(segment, designator) &&
      absl::EndsWith(segment, designator)) {
    ThrowInvalidArgument("Document fields cannot begin and end with %s%s",
                         RESERVED_FIELD_DESIGNATOR, FieldDescription());
  }
}

void ParseContext::AddToFieldMask(FieldPath field_path) {
  accumulator_->AddToFieldMask(std::move(field_path));
}

void ParseContext::AddToFieldTransforms(
    FieldPath field_path,
    std::unique_ptr<TransformOperation> transform_operation) {
  accumulator_->AddToFieldTransforms(std::move(field_path),
                                     std::move(transform_operation));
}

#pragma mark - ParsedSetData

ParsedSetData::ParsedSetData(ObjectValue data,
                             std::vector<FieldTransform> field_transforms)
    : data_{std::move(data)},
      field_transforms_{std::move(field_transforms)},
      patch_{false} {
}

ParsedSetData::ParsedSetData(ObjectValue data,
                             FieldMask field_mask,
                             std::vector<FieldTransform> field_transforms)
    : data_{std::move(data)},
      field_mask_{std::move(field_mask)},
      field_transforms_{std::move(field_transforms)},
      patch_{true} {
}

std::vector<FSTMutation*> ParsedSetData::ToMutations(
    const DocumentKey& key, const Precondition& precondition) && {
  std::vector<FSTMutation*> mutations;
  if (patch_) {
    FSTMutation* mutation =
        [[FSTPatchMutation alloc] initWithKey:key
                                    fieldMask:std::move(field_mask_)
                                        value:data_
                                 precondition:precondition];
    mutations.push_back(mutation);
  } else {
    FSTMutation* mutation = [[FSTSetMutation alloc] initWithKey:key
                                                          value:std::move(data_)
                                                   precondition:precondition];
    mutations.push_back(mutation);
  }

  if (!field_transforms_.empty()) {
    FSTMutation* mutation =
        [[FSTTransformMutation alloc] initWithKey:key
                                  fieldTransforms:field_transforms_];
    mutations.push_back(mutation);
  }

  return mutations;
}

#pragma mark - ParsedUpdateData

ParsedUpdateData::ParsedUpdateData(
    ObjectValue data,
    model::FieldMask field_mask,
    std::vector<model::FieldTransform> field_transforms)
    : data_{std::move(data)},
      field_mask_{std::move(field_mask)},
      field_transforms_{std::move(field_transforms)} {
}

std::vector<FSTMutation*> ParsedUpdateData::ToMutations(
    const DocumentKey& key, const Precondition& precondition) && {
  std::vector<FSTMutation*> mutations;

  FSTMutation* mutation =
      [[FSTPatchMutation alloc] initWithKey:key
                                  fieldMask:std::move(field_mask_)
                                      value:std::move(data_)
                               precondition:precondition];
  mutations.push_back(mutation);

  if (!field_transforms_.empty()) {
    FSTMutation* mutation =
        [[FSTTransformMutation alloc] initWithKey:key
                                  fieldTransforms:std::move(field_transforms_)];
    mutations.push_back(mutation);
  }

  return mutations;
}

}  // namespace core
}  // namespace firestore
}  // namespace firebase

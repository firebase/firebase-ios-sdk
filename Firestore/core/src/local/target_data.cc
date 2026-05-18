/*
 * Copyright 2026 Google
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

#include "Firestore/core/src/local/target_data.h"

#include <ostream>
#include <sstream>
#include <utility>

namespace firebase {
namespace firestore {
namespace local {
namespace {

using core::Target;
using core::TargetOrPipeline;
using model::ListenSequenceNumber;
using model::RemoteTargetId;
using model::SnapshotVersion;
using model::TargetId;
using nanopb::ByteString;

// MARK: - QueryPurpose

const char* ToString(QueryPurpose purpose) {
  switch (purpose) {
    case QueryPurpose::Listen:
      return "Listen";
    case QueryPurpose::ExistenceFilterMismatch:
      return "ExistenceFilterMismatch";
    case QueryPurpose::ExistenceFilterMismatchBloom:
      return "ExistenceFilterMismatchBloom";
    case QueryPurpose::LimboResolution:
      return "LimboResolution";
  }

  UNREACHABLE();
}

}  // namespace

std::ostream& operator<<(std::ostream& os, QueryPurpose purpose) {
  return os << ToString(purpose);
}

// MARK: - TargetData

template <typename TargetIdType>
TargetDataTemplate<TargetIdType>::TargetDataTemplate(
    TargetOrPipeline target,
    TargetIdType target_id,
    ListenSequenceNumber sequence_number,
    QueryPurpose purpose,
    SnapshotVersion snapshot_version,
    SnapshotVersion last_limbo_free_snapshot_version,
    ByteString resume_token,
    absl::optional<int32_t> expected_count)
    : target_(std::move(target)),
      target_id_(target_id),
      sequence_number_(sequence_number),
      purpose_(purpose),
      snapshot_version_(std::move(snapshot_version)),
      last_limbo_free_snapshot_version_(
          std::move(last_limbo_free_snapshot_version)),
      resume_token_(std::move(resume_token)),
      expected_count_(std::move(expected_count)) {
}

template <typename TargetIdType>
TargetDataTemplate<TargetIdType>::TargetDataTemplate(
    TargetOrPipeline target,
    TargetIdType target_id,
    ListenSequenceNumber sequence_number,
    QueryPurpose purpose)
    : TargetDataTemplate(std::move(target),
                         target_id,
                         sequence_number,
                         purpose,
                         SnapshotVersion::None(),
                         SnapshotVersion::None(),
                         ByteString(),
                         /*expected_count=*/absl::nullopt) {
}

template <typename TargetIdType>
TargetDataTemplate<TargetIdType> TargetDataTemplate<TargetIdType>::Invalid() {
  return TargetDataTemplate({}, /*target_id=*/-1, /*sequence_number=*/-1,
                            QueryPurpose::Listen,
                            SnapshotVersion(SnapshotVersion::None()),
                            SnapshotVersion(SnapshotVersion::None()), {},
                            /*expected_count=*/absl::nullopt);
}

template <typename TargetIdType>
TargetDataTemplate<TargetIdType>
TargetDataTemplate<TargetIdType>::WithSequenceNumber(
    ListenSequenceNumber sequence_number) const {
  return TargetDataTemplate(
      target_, target_id_, sequence_number, purpose_, snapshot_version_,
      last_limbo_free_snapshot_version_, resume_token_, expected_count_);
}

template <typename TargetIdType>
TargetDataTemplate<TargetIdType>
TargetDataTemplate<TargetIdType>::WithResumeToken(
    ByteString resume_token, SnapshotVersion snapshot_version) const {
  return TargetDataTemplate(target_, target_id_, sequence_number_, purpose_,
                            std::move(snapshot_version),
                            last_limbo_free_snapshot_version_,
                            std::move(resume_token),
                            /*expected_count=*/absl::nullopt);
}

template <typename TargetIdType>
TargetDataTemplate<TargetIdType>
TargetDataTemplate<TargetIdType>::WithExpectedCount(
    absl::optional<int32_t> expected_count) const {
  return TargetDataTemplate(target_, target_id_, sequence_number_, purpose_,
                            snapshot_version_,
                            last_limbo_free_snapshot_version_, resume_token_,
                            std::move(expected_count));
}

template <typename TargetIdType>
TargetDataTemplate<TargetIdType>
TargetDataTemplate<TargetIdType>::WithLastLimboFreeSnapshotVersion(
    SnapshotVersion last_limbo_free_snapshot_version) const {
  return TargetDataTemplate(target_, target_id_, sequence_number_, purpose_,
                            snapshot_version_,
                            std::move(last_limbo_free_snapshot_version),
                            resume_token_, expected_count_);
}

template <typename TargetIdType>
bool TargetDataTemplate<TargetIdType>::Equals(
    const TargetDataTemplate& rhs) const {
  return target_or_pipeline() == rhs.target_or_pipeline() &&
         target_id() == rhs.target_id() &&
         sequence_number() == rhs.sequence_number() &&
         purpose() == rhs.purpose() &&
         snapshot_version() == rhs.snapshot_version() &&
         resume_token() == rhs.resume_token() &&
         expected_count() == rhs.expected_count();
}

template <typename TargetIdType>
bool operator==(const TargetDataTemplate<TargetIdType>& lhs,
                const TargetDataTemplate<TargetIdType>& rhs) {
  return lhs.Equals(rhs);
}

template <typename TargetIdType>
size_t TargetDataTemplate<TargetIdType>::Hash() const {
  return util::Hash(target_, target_id_, sequence_number_, purpose_,
                    snapshot_version_, resume_token_, expected_count_);
}

template <typename TargetIdType>
std::string TargetDataTemplate<TargetIdType>::ToString() const {
  std::ostringstream ss;
  ss << *this;
  return ss.str();
}

template <typename TargetIdType>
std::ostream& operator<<(std::ostream& os,
                         const TargetDataTemplate<TargetIdType>& value) {
  return os << "TargetData(target=" << value.target_or_pipeline().ToString()
            << ", target_id=" << value.target_id()
            << ", purpose=" << value.purpose()
            << ", version=" << value.snapshot_version()
            << ", last_limbo_free_snapshot_version="
            << value.last_limbo_free_snapshot_version()
            << ", resume_token=" << value.resume_token() << ", expected_count="
            << (value.expected_count().has_value()
                    ? std::to_string(value.expected_count().value())
                    : "null")
            << ")";
}

template class TargetDataTemplate<TargetId>;

template bool operator==(const TargetDataTemplate<TargetId>& lhs,
                         const TargetDataTemplate<TargetId>& rhs);

template std::ostream& operator<<(std::ostream& os,
                                  const TargetDataTemplate<TargetId>& value);

}  // namespace local
}  // namespace firestore
}  // namespace firebase

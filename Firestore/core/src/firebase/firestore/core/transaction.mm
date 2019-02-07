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

#include "Firestore/core/src/firebase/firestore/core/transaction.h"

#include <algorithm>
#include <utility>

#import "Firestore/Source/Model/FSTDocument.h"
#import "Firestore/Source/Model/FSTMutation.h"

#include "Firestore/core/include/firebase/firestore/firestore_errors.h"
#include "Firestore/core/src/firebase/firestore/model/document_key_set.h"
#include "Firestore/core/src/firebase/firestore/util/hard_assert.h"

using firebase::firestore::FirestoreErrorCode;
using firebase::firestore::core::ParsedSetData;
using firebase::firestore::core::ParsedUpdateData;
using firebase::firestore::model::DocumentKey;
using firebase::firestore::model::DocumentKeySet;
using firebase::firestore::model::Precondition;
using firebase::firestore::model::SnapshotVersion;
using firebase::firestore::remote::Datastore;
using firebase::firestore::util::Status;
using firebase::firestore::util::StatusOr;

namespace firebase {
namespace firestore {
namespace core {

Transaction::Transaction(Datastore* datastore)
    : datastore_{NOT_NULL(datastore)} {
}

Status Transaction::RecordVersion(FSTMaybeDocument* doc) {
  SnapshotVersion doc_version;
  if ([doc isKindOfClass:[FSTDocument class]]) {
    doc_version = doc.version;
  } else if ([doc isKindOfClass:[FSTDeletedDocument class]]) {
    // For deleted docs, we must record an explicit no version to build the
    // right precondition when writing.
    doc_version = SnapshotVersion::None();
  } else {
    HARD_FAIL("Unexpected document type in transaction: %s",
              NSStringFromClass([doc class]));
  }

  if (read_versions_.find(doc.key) == read_versions_.end()) {
    read_versions_[doc.key] = doc_version;
    return Status::OK();
  } else {
    return Status{
        FirestoreErrorCode::FailedPrecondition,
        "A document cannot be read twice within a single transaction."};
  }
}

void Transaction::Lookup(const std::vector<DocumentKey>& keys,
                         LookupCallback&& callback) {
  EnsureCommitNotCalled();

  HARD_ASSERT(mutations_.empty(),
              "All reads in a transaction must be done before any writes.");

  datastore_->LookupDocuments(
      keys, [this, callback](const std::vector<FSTMaybeDocument*>& documents,
                             const Status& status) {
        if (!status.ok()) {
          callback({}, status);
          return;
        }

        for (FSTMaybeDocument* doc : documents) {
          Status record_error = RecordVersion(doc);
          if (!record_error.ok()) {
            callback({}, record_error);
          }
        }

        callback(documents, Status::OK());
      });
}

void Transaction::WriteMutations(std::vector<FSTMutation*>&& mutations) {
  EnsureCommitNotCalled();
  // `move` will become appropriate once `FSTMutation` is replaced by the C++
  // equivalent.
  std::move(mutations.begin(), mutations.end(), std::back_inserter(mutations_));
}

Precondition Transaction::CreatePrecondition(const DocumentKey& key) {
  const auto iter = read_versions_.find(key);
  if (iter == read_versions_.end()) {
    return Precondition::None();
  } else {
    return Precondition::UpdateTime(iter->second);
  }
}

StatusOr<Precondition> Transaction::CreateUpdatePrecondition(const DocumentKey& key) {
  const auto iter = read_versions_.find(key);
  if (iter == read_versions_.end()) {
    // Document was not read, so we just use the preconditions for an update.
    return Precondition::Exists(true);
  }

  const SnapshotVersion& version = iter->second;
  if (version == SnapshotVersion::None()) {
    return Status{FirestoreErrorCode::Aborted,
                  "Can't update a document that doesn't exist."};
  } else {
    // Document exists, just base precondition on document update time.
    return Precondition::UpdateTime(version);
  }
}

void Transaction::Set(const DocumentKey& key, ParsedSetData&& data) {
  WriteMutations(std::move(data).ToMutations(key, CreatePrecondition(key)));
}

void Transaction::Update(const DocumentKey& key, ParsedUpdateData&& data) {
  StatusOr<Precondition> maybe_precondition = CreateUpdatePrecondition(key);
  if (!maybe_precondition.ok()) {
    last_write_error_ = maybe_precondition.status();
  } else {
    WriteMutations(
        std::move(data).ToMutations(key, maybe_precondition.ValueOrDie()));
  }
}

void Transaction::Delete(const DocumentKey& key) {
  FSTMutation* mutation =
      [[FSTDeleteMutation alloc] initWithKey:key
                                precondition:CreatePrecondition(key)];
  WriteMutations({mutation});

  // Since the delete will be applied before all following writes, we need to
  // ensure that the precondition for the next write will be exists without
  // timestamp.
  read_versions_[key] = SnapshotVersion::None();
}

void Transaction::Commit(CommitCallback&& callback) {
  EnsureCommitNotCalled();
  // Once `Commit` is called once, mark this object so it can't be used again.
  commit_called_ = true;

  // If there was an error writing, raise that error now
  if (!last_write_error_.ok()) {
    callback(last_write_error_);
    return;
  }

  // Make a list of read documents that haven't been written.
  DocumentKeySet unwritten;
  for (const auto& kv : read_versions_) {
    unwritten = unwritten.insert(kv.first);
  };
  // For each mutation, note that the doc was written.
  for (FSTMutation* mutation : mutations_) {
    unwritten = unwritten.erase(mutation.key);
  }

  if (!unwritten.empty()) {
    // TODO(klimt): This is a temporary restriction, until "verify" is supported
    // on the backend.
    callback(Status{FirestoreErrorCode::FailedPrecondition,
             "Every document read in a transaction must also be written in "
             "that transaction."});
  } else {
    datastore_->CommitMutations(mutations_, std::move(callback));
  }
}

void Transaction::EnsureCommitNotCalled() {
  HARD_ASSERT(!commit_called_, "A transaction object cannot be used after its "
                               "update callback has been invoked.");
}

}  // namespace core
}  // namespace firestore
}  // namespace firebase

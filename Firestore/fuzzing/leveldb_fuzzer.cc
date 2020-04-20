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

#include <cstddef>
#include <cstdint>
#include <string>

#include "Firestore/core/src/local/leveldb_key.h"
#include "Firestore/core/src/local/leveldb_util.h"

using firebase::firestore::local::LevelDbDocumentMutationKey;
using firebase::firestore::local::LevelDbDocumentTargetKey;
using firebase::firestore::local::LevelDbMutationKey;
using firebase::firestore::local::LevelDbMutationQueueKey;
using firebase::firestore::local::LevelDbQueryTargetKey;
using firebase::firestore::local::LevelDbRemoteDocumentKey;
using firebase::firestore::local::LevelDbTargetDocumentKey;
using firebase::firestore::local::LevelDbTargetGlobalKey;
using firebase::firestore::local::LevelDbTargetKey;
using firebase::firestore::model::BatchId;
using firebase::firestore::model::ResourcePath;

extern "C" int LLVMFuzzerTestOneInput(const uint8_t* data, size_t size) {
  const char* str_ptr = reinterpret_cast<const char*>(data);
  std::string str{str_ptr, size};
  leveldb::Slice slice = firebase::firestore::local::MakeSlice(str);

  // Test DescribeKey(std::string) which calls MakeSlice(std::string).
  try {
    firebase::firestore::local::DescribeKey(str);
  } catch (...) {
    // Ignore caught errors and assertions.
  }

  // Test LevelDbMutationKey methods.
  try {
    LevelDbMutationKey::KeyPrefix(str);
  } catch (...) {
    // Ignore caught errors and assertions.
  }

  try {
    BatchId batch_id{static_cast<int>(size)};
    LevelDbMutationKey::Key(str, batch_id);
  } catch (...) {
    // Ignore caught errors and assertions.
  }

  try {
    LevelDbMutationKey key;
    (void)key.Decode(str);
  } catch (...) {
    // Ignore caught errors and assertions.
  }

  // Test LevelDbDocumentMutationKey methods.
  try {
    LevelDbDocumentMutationKey::KeyPrefix(str);
  } catch (...) {
    // Ignore caught errors and assertions.
  }

  try {
    LevelDbDocumentMutationKey key;
    (void)key.Decode(str);
  } catch (...) {
    // Ignore caught errors and assertions.
  }

  // Test LevelDbMutationQueueKey methods.
  try {
    LevelDbMutationQueueKey::Key(str);
  } catch (...) {
    // Ignore caught errors and assertions.
  }

  try {
    LevelDbMutationQueueKey key;
    (void)key.Decode(str);
  } catch (...) {
    // Ignore caught errors and assertions.
  }

  // Test LevelDbTargetGlobalKey methods.
  try {
    LevelDbTargetGlobalKey key;
    (void)key.Decode(slice);
  } catch (...) {
    // ignore caught errors and assertions.
  }

  // Test LevelDbTargetKey methods.
  try {
    LevelDbTargetKey key;
    (void)key.Decode(slice);
  } catch (...) {
    // ignore caught errors and assertions.
  }

  // Test LevelDbQueryTargetKey methods.
  try {
    LevelDbQueryTargetKey::KeyPrefix(str);
  } catch (...) {
    // Ignore caught errors and assertions.
  }

  try {
    LevelDbQueryTargetKey key;
    (void)key.Decode(str);
  } catch (...) {
    // Ignore caught errors and assertions.
  }

  // Test LevelDbTargetDocumentKey methods.
  try {
    LevelDbTargetDocumentKey key;
    (void)key.Decode(str);
  } catch (...) {
    // Ignore caught errors and assertions.
  }

  // Test LevelDbDocumentTargetKey methods.
  try {
    ResourcePath rp = ResourcePath::FromString(str);
    LevelDbDocumentTargetKey::KeyPrefix(rp);
  } catch (...) {
    // Ignore caught errors and assertions.
  }

  try {
    LevelDbDocumentTargetKey key;
    (void)key.Decode(str);
  } catch (...) {
    // Ignore caught errors and assertions.
  }

  // Test LevelDbRemoteDocumentKey methods.
  try {
    ResourcePath rp = ResourcePath::FromString(str);
    LevelDbRemoteDocumentKey::KeyPrefix(rp);
  } catch (...) {
    // Ignore caught errors and assertions.
  }

  try {
    LevelDbRemoteDocumentKey key;
    (void)key.Decode(str);
  } catch (...) {
    // Ignore caught errors and assertions.
  }

  return 0;
}

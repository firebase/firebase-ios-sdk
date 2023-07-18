/*
 * Copyright 2023 Google LLC
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

#ifndef FIRESTORE_CORE_SRC_UTIL_TESTING_HOOKS_H_
#define FIRESTORE_CORE_SRC_UTIL_TESTING_HOOKS_H_

#include <functional>
#include <memory>
#include <mutex>  // NOLINT(build/c++11)
#include <unordered_map>

#include "Firestore/core/src/api/listener_registration.h"
#include "Firestore/core/src/util/no_destructor.h"
#include "absl/types/optional.h"

namespace firebase {
namespace firestore {
namespace util {

/**
 * Manages "testing hooks", hooks into the internals of the SDK to verify
 * internal state and events during integration tests. Do not use this class
 * except for testing purposes.
 */
class TestingHooks final {
 public:
  /** Returns the singleton instance of this class. */
  static TestingHooks& GetInstance();

  /**
   * Information about the bloom filter provided by Watch in the ExistenceFilter
   * message's `unchangedNames` field.
   */
  struct BloomFilterInfo {
    /**
     * Whether a full requery was averted by using the bloom filter. If false,
     * then something happened, such as a false positive, to prevent using the
     * bloom filter to avoid a full requery.
     */
    bool applied = false;

    /** The number of hash functions used in the bloom filter. */
    int hash_count = -1;

    /** The number of bytes in the bloom filter's bitmask. */
    int bitmap_length = -1;

    /** The number of bits of padding in the last byte of the bloom filter. */
    int padding = -1;
  };

  /**
   * Information about an existence filter mismatch, as specified to callbacks
   * registered with `OnExistenceFilterMismatch()`.
   */
  struct ExistenceFilterMismatchInfo {
    /** The number of documents that matched the query in the local cache. */
    int local_cache_count = -1;

    /**
     * The number of documents that matched the query on the server, as
     * specified in the `ExistenceFilter` message's `count` field.
     */
    int existence_filter_count = -1;

    /**
     * Information about the bloom filter provided by Watch in the
     * ExistenceFilter message's `unchangedNames` field. If empty, then that
     * means that Watch did _not_ provide a bloom filter.
     */
    absl::optional<BloomFilterInfo> bloom_filter;
  };

  using ExistenceFilterMismatchCallback =
      std::function<void(const TestingHooks::ExistenceFilterMismatchInfo&)>;

  /**
   * Registers a callback to be invoked when an existence filter mismatch occurs
   * in the Watch listen stream.
   *
   * The relative order in which callbacks are notified is unspecified; do not
   * rely on any particular ordering. If a given callback is registered multiple
   * times then it will be notified multiple times, once per registration.
   *
   * The listener callbacks are performed synchronously in
   * `NotifyOnExistenceFilterMismatch()`; therefore, listeners should perform
   * their work as quickly as possible and return to avoid blocking any critical
   * work. In particular, the listener callbacks should *not* block or perform
   * long-running operations.
   *
   * The `ExistenceFilterMismatchInfo` reference specified to the callback is
   * only valid during the lifetime of the callback. Once the callback returns
   * then it must not use the given `ExistenceFilterMismatchInfo` reference
   * again.
   *
   * @param callback the callback to invoke upon existence filter mismatch.
   *
   * @return an object whose `Remove()` member function unregisters the given
   * callback; only the first invocation of `Remove()` does anything; all
   * subsequent invocations do nothing. Note that due to inherent race
   * conditions it is technically possible, although unlikely, that callbacks
   * could still occur _after_ unregistering.
   */
  std::shared_ptr<api::ListenerRegistration> OnExistenceFilterMismatch(
      ExistenceFilterMismatchCallback callback);

  /**
   * Invokes all currently-registered `OnExistenceFilterMismatch` callbacks
   * synchronously.
   * @param info Information about the existence filter mismatch.
   */
  void NotifyOnExistenceFilterMismatch(const ExistenceFilterMismatchInfo& info);

 private:
  TestingHooks() = default;

  // Delete the destructor so that the singleton instance of this class can
  // never be deleted.
  ~TestingHooks() = delete;

  TestingHooks(const TestingHooks&) = delete;
  TestingHooks(TestingHooks&&) = delete;
  TestingHooks& operator=(const TestingHooks&) = delete;
  TestingHooks& operator=(TestingHooks&&) = delete;

  friend class NoDestructor<TestingHooks>;

  mutable std::mutex mutex_;
  int next_id_ = 0;
  std::unordered_map<int, std::shared_ptr<ExistenceFilterMismatchCallback>>
      existence_filter_mismatch_callbacks_;
};

}  // namespace util
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_UTIL_TESTING_HOOKS_H_

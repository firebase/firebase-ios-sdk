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

#ifndef FIRESTORE_CORE_SRC_CORE_LISTEN_OPTIONS_H_
#define FIRESTORE_CORE_SRC_CORE_LISTEN_OPTIONS_H_

#include <utility>
#include "Firestore/core/src/api/listen_source.h"
namespace firebase {
namespace firestore {
namespace core {

using api::ListenSource;

class ListenOptions {
 public:
  /**
   * An enumeration of the possible behaviors for server-generated timestamps.
   * This is only useful for pipelines.
   */
  enum class ServerTimestampBehavior {
    /**
     * Do not estimate server timestamps. Just return null.
     */
    kNone,
    /**
     * Estimate server timestamps, integrated with the server's confirmed time.
     */
    kEstimate,
    /**
     * Use the previous value, until the server confirms the new value.
     */
    kPrevious,
  };

  ListenOptions() = default;

  /**
   * Creates a new ListenOptions.
   *
   * @param include_query_metadata_changes Raise events when only metadata of
   *     the query changes.
   * @param include_document_metadata_changes Raise events when only metadata of
   *     documents changes.
   * @param wait_for_sync_when_online Wait for a sync with the server when
   *     online, but still raise events while offline
   */
  ListenOptions(bool include_query_metadata_changes,
                bool include_document_metadata_changes,
                bool wait_for_sync_when_online)
      : include_query_metadata_changes_(include_query_metadata_changes),
        include_document_metadata_changes_(include_document_metadata_changes),
        wait_for_sync_when_online_(wait_for_sync_when_online) {
  }

  /**
   * Creates a new ListenOptions.
   *
   * @param include_query_metadata_changes Raise events when only metadata of
   *     the query changes.
   * @param include_document_metadata_changes Raise events when only metadata of
   *     documents changes.
   * @param wait_for_sync_when_online Wait for a sync with the server when
   *     online, but still raise events while offline.
   * @param source sets the source a snapshot listener listens to.
   */
  ListenOptions(bool include_query_metadata_changes,
                bool include_document_metadata_changes,
                bool wait_for_sync_when_online,
                ListenSource source)
      : include_query_metadata_changes_(include_query_metadata_changes),
        include_document_metadata_changes_(include_document_metadata_changes),
        wait_for_sync_when_online_(wait_for_sync_when_online),
        source_(std::move(source)) {
  }

  ListenOptions(bool include_query_metadata_changes,
                bool include_document_metadata_changes,
                bool wait_for_sync_when_online,
                ListenSource source,
                ServerTimestampBehavior behavior)
      : include_query_metadata_changes_(include_query_metadata_changes),
        include_document_metadata_changes_(include_document_metadata_changes),
        wait_for_sync_when_online_(wait_for_sync_when_online),
        source_(std::move(source)),
        server_timestamp_(behavior) {
  }

  /**
   * Creates a default ListenOptions, with metadata changes,
   * wait_for_sync_when_online disabled, and listen source set to default.
   */
  static ListenOptions DefaultOptions() {
    return ListenOptions(
        /*include_query_metadata_changes=*/false,
        /*include_document_metadata_changes=*/false,
        /*wait_for_sync_when_online=*/false,
        /*source=*/ListenSource::Default);
  }

  /**
   * Creates a ListenOptions which optionally includes both query and document
   * metadata changes.
   */
  static ListenOptions FromIncludeMetadataChanges(
      bool include_metadata_changes) {
    return ListenOptions(
        /*include_query_metadata_changes=*/include_metadata_changes,
        /*include_document_metadata_changes=*/include_metadata_changes,
        /*wait_for_sync_when_online=*/false,
        /*source=*/ListenSource::Default);
  }

  /**
   * Creates a ListenOptions which sets the source snapshot listener listens to.
   */
  static ListenOptions FromOptions(bool include_metadata_changes,
                                   ListenSource source) {
    return ListenOptions(
        /*include_query_metadata_changes=*/include_metadata_changes,
        /*include_document_metadata_changes=*/include_metadata_changes,
        /*wait_for_sync_when_online=*/false, std::move(source));
  }

  bool include_query_metadata_changes() const {
    return include_query_metadata_changes_;
  }

  bool include_document_metadata_changes() const {
    return include_document_metadata_changes_;
  }

  bool wait_for_sync_when_online() const {
    return wait_for_sync_when_online_;
  }

  ListenSource source() const {
    return source_;
  }

  ServerTimestampBehavior server_timestamp_behavior() const {
    return server_timestamp_;
  }

 private:
  bool include_query_metadata_changes_ = false;
  bool include_document_metadata_changes_ = false;
  bool wait_for_sync_when_online_ = false;
  ListenSource source_ = ListenSource::Default;
  ServerTimestampBehavior server_timestamp_ = ServerTimestampBehavior::kNone;
};

}  // namespace core
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_CORE_LISTEN_OPTIONS_H_

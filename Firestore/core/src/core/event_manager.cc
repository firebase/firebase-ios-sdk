/*
 * Copyright 2019 Google LLC
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

#include "Firestore/core/src/core/event_manager.h"

#include <utility>

#include "Firestore/core/src/core/query_listener.h"
#include "Firestore/core/src/core/sync_engine.h"
#include "Firestore/core/src/util/hard_assert.h"
#include "absl/algorithm/container.h"

namespace firebase {
namespace firestore {
namespace core {

using util::Empty;

EventManager::EventManager(QueryEventSource* query_event_source)
    : query_event_source_(query_event_source) {
  query_event_source->SetCallback(this);
}

model::TargetId EventManager::AddQueryListener(
    std::shared_ptr<core::QueryListener> listener) {
  const Query& query = listener->query();
  ListenerSetupAction listener_action =
      ListenerSetupAction::NoSetupActionRequired;

  auto inserted = queries_.emplace(query, QueryListenersInfo{});
  // If successfully inserted, it means we haven't listened to this query
  // before.
  bool first_listen = inserted.second;
  QueryListenersInfo& query_info = inserted.first->second;

  if (first_listen) {
    listener_action = listener->listens_to_remote_store()
                          ? ListenerSetupAction::
                                InitializeLocalListenAndRequireWatchConnection
                          : ListenerSetupAction::InitializeLocalListenOnly;
  } else if (!query_info.has_remote_listeners() &&
             listener->listens_to_remote_store()) {
    // Query has been listening to local cache, and tries to add a new listener
    // sourced from watch.
    listener_action = ListenerSetupAction::RequireWatchConnectionOnly;
  }

  query_info.listeners.push_back(listener);

  bool raised_event = listener->OnOnlineStateChanged(online_state_);
  HARD_ASSERT(!raised_event,
              "OnOnlineStateChanged() shouldn't raise an event "
              "for brand-new listeners.");

  if (query_info.view_snapshot().has_value()) {
    raised_event = listener->OnViewSnapshot(query_info.view_snapshot().value());
    if (raised_event) {
      RaiseSnapshotsInSyncEvent();
    }
  }

  switch (listener_action) {
    case ListenerSetupAction::InitializeLocalListenAndRequireWatchConnection:
      query_info.target_id = query_event_source_->Listen(
          query, /** should_listen_to_remote= */ true);
      break;
    case ListenerSetupAction::InitializeLocalListenOnly:
      query_info.target_id = query_event_source_->Listen(
          query, /** should_listen_to_remote= */ false);
      break;
    case ListenerSetupAction::RequireWatchConnectionOnly:
      query_event_source_->ListenToRemoteStore(query);
      break;
    default:
      break;
  }
  return query_info.target_id;
}

void EventManager::RemoveQueryListener(
    std::shared_ptr<core::QueryListener> listener) {
  const Query& query = listener->query();
  ListenerRemovalAction listener_action =
      ListenerRemovalAction::NoRemovalActionRequired;

  auto found_iter = queries_.find(query);
  if (found_iter != queries_.end()) {
    QueryListenersInfo& query_info = found_iter->second;
    query_info.Erase(listener);

    if (query_info.listeners.empty()) {
      listener_action =
          listener->listens_to_remote_store()
              ? ListenerRemovalAction::
                    TerminateLocalListenAndRequireWatchDisconnection
              : ListenerRemovalAction::TerminateLocalListenOnly;
    } else if (!query_info.has_remote_listeners() &&
               listener->listens_to_remote_store()) {
      // The removed listener is the last one that sourced from watch.
      listener_action = ListenerRemovalAction::RequireWatchDisconnectionOnly;
    }
  }

  switch (listener_action) {
    case ListenerRemovalAction::
        TerminateLocalListenAndRequireWatchDisconnection:
      queries_.erase(found_iter);
      return query_event_source_->StopListening(
          query, /** should_stop_remote_listening= */ true);
    case ListenerRemovalAction::TerminateLocalListenOnly:
      queries_.erase(found_iter);
      return query_event_source_->StopListening(
          query, /** should_stop_remote_listening= */ false);
    case ListenerRemovalAction::RequireWatchDisconnectionOnly:
      return query_event_source_->StopListeningToRemoteStoreOnly(query);
    default:
      return;
  }
}

void EventManager::AddSnapshotsInSyncListener(
    const std::shared_ptr<EventListener<Empty>>& listener) {
  snapshots_in_sync_listeners_.insert(listener);
  listener->OnEvent(Empty());
}

void EventManager::RemoveSnapshotsInSyncListener(
    const std::shared_ptr<EventListener<Empty>>& listener) {
  snapshots_in_sync_listeners_.erase(listener);
}

void EventManager::HandleOnlineStateChange(model::OnlineState online_state) {
  bool raised_event = false;
  online_state_ = online_state;

  for (auto&& kv : queries_) {
    QueryListenersInfo& info = kv.second;
    for (auto&& listener : info.listeners) {
      if (listener->OnOnlineStateChanged(online_state_)) {
        raised_event = true;
      }
    }
  }
  if (raised_event) {
    RaiseSnapshotsInSyncEvent();
  }
}

void EventManager::RaiseSnapshotsInSyncEvent() {
  Empty empty{};
  for (const auto& listener : snapshots_in_sync_listeners_) {
    listener->OnEvent(empty);
  }
}

void EventManager::OnViewSnapshots(
    std::vector<core::ViewSnapshot>&& snapshots) {
  bool raised_event = false;
  for (ViewSnapshot& snapshot : snapshots) {
    const Query& query = snapshot.query();
    auto found_iter = queries_.find(query);
    if (found_iter != queries_.end()) {
      QueryListenersInfo& query_info = found_iter->second;
      for (const auto& listener : query_info.listeners) {
        if (listener->OnViewSnapshot(snapshot)) {
          raised_event = true;
        }
      }
      query_info.set_view_snapshot(std::move(snapshot));
    }
  }
  if (raised_event) {
    RaiseSnapshotsInSyncEvent();
  }
}

void EventManager::OnError(const core::Query& query,
                           const util::Status& error) {
  auto found_iter = queries_.find(query);
  if (found_iter == queries_.end()) {
    return;
  }

  QueryListenersInfo& query_info = found_iter->second;
  for (const auto& listener : query_info.listeners) {
    listener->OnError(error);
  }

  // Remove all listeners. NOTE: We don't need to call
  // `SyncEngine::StopListening()` after an error.
  queries_.erase(found_iter);
}

bool EventManager::QueryListenersInfo::Erase(
    const std::shared_ptr<QueryListener>& listener) {
  auto found_iter = absl::c_find(listeners, listener);
  auto found = found_iter != listeners.end();
  if (found) {
    listeners.erase(found_iter);
  }
  return found;
}

}  // namespace core
}  // namespace firestore
}  // namespace firebase

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

#import "Firestore/Source/Core/FSTEventManager.h"

#include <unordered_map>
#include <utility>
#include <vector>

#import "Firestore/Source/Core/FSTQuery.h"
#import "Firestore/Source/Core/FSTSyncEngine.h"

#include "Firestore/core/src/firebase/firestore/model/document_set.h"
#include "Firestore/core/src/firebase/firestore/util/error_apple.h"
#include "Firestore/core/src/firebase/firestore/util/hard_assert.h"
#include "Firestore/core/src/firebase/firestore/util/objc_compatibility.h"
#include "Firestore/core/src/firebase/firestore/util/status.h"
#include "absl/algorithm/container.h"
#include "absl/types/optional.h"

NS_ASSUME_NONNULL_BEGIN

namespace objc = firebase::firestore::util::objc;
using firebase::firestore::core::DocumentViewChange;
using firebase::firestore::core::ViewSnapshot;
using firebase::firestore::model::OnlineState;
using firebase::firestore::model::TargetId;
using firebase::firestore::util::MakeStatus;
using firebase::firestore::util::Status;

#pragma mark - FSTQueryListenersInfo

namespace {

/**
 * Holds the listeners and the last received ViewSnapshot for a query being tracked by
 * EventManager.
 */
struct QueryListenersInfo {
  TargetId target_id;
  std::vector<std::shared_ptr<QueryListener>> listeners;

  void Erase(const std::shared_ptr<QueryListener> &listener) {
    auto found = absl::c_find(listeners, listener);
    if (found != listeners.end()) {
      listeners.erase(found);
    }
  }

  const absl::optional<ViewSnapshot> &view_snapshot() const {
    return snapshot_;
  }

  void set_view_snapshot(const absl::optional<ViewSnapshot> &snapshot) {
    snapshot_ = snapshot;
  }

 private:
  // Other members are public in this struct, ensure that any reads are
  // copies by requiring reads to go through a const getter.
  absl::optional<ViewSnapshot> snapshot_;
};

}  // namespace

#pragma mark - FSTEventManager

@interface FSTEventManager () <FSTSyncEngineDelegate>

- (instancetype)initWithSyncEngine:(FSTSyncEngine *)syncEngine NS_DESIGNATED_INITIALIZER;

@property(nonatomic, strong, readonly) FSTSyncEngine *syncEngine;
@property(nonatomic, assign) OnlineState onlineState;

@end

@implementation FSTEventManager {
  objc::unordered_map<FSTQuery *, QueryListenersInfo> _queries;
}

+ (instancetype)eventManagerWithSyncEngine:(FSTSyncEngine *)syncEngine {
  return [[FSTEventManager alloc] initWithSyncEngine:syncEngine];
}

- (instancetype)initWithSyncEngine:(FSTSyncEngine *)syncEngine {
  if (self = [super init]) {
    _syncEngine = syncEngine;
    _syncEngine.syncEngineDelegate = self;
  }
  return self;
}

- (TargetId)addListener:(std::shared_ptr<QueryListener>)listener {
  FSTQuery *query = listener->query();

  auto inserted = _queries.emplace(query, QueryListenersInfo{});
  bool first_listen = inserted.second;
  QueryListenersInfo &query_info = inserted.first->second;

  query_info.listeners.push_back(listener);

  listener->OnOnlineStateChanged(self.onlineState);

  if (query_info.view_snapshot().has_value()) {
    listener->OnViewSnapshot(query_info.view_snapshot().value());
  }

  if (first_listen) {
    query_info.target_id = [self.syncEngine listenToQuery:query];
  }
  return query_info.target_id;
}

- (void)removeListener:(const std::shared_ptr<QueryListener> &)listener {
  FSTQuery *query = listener->query();
  bool last_listen = false;

  auto found_iter = _queries.find(query);
  if (found_iter != _queries.end()) {
    QueryListenersInfo &query_info = found_iter->second;
    query_info.Erase(listener);
    last_listen = query_info.listeners.empty();
  }

  if (last_listen) {
    _queries.erase(found_iter);
    [self.syncEngine stopListeningToQuery:query];
  }
}

- (void)handleViewSnapshots:(std::vector<ViewSnapshot> &&)viewSnapshots {
  for (ViewSnapshot &viewSnapshot : viewSnapshots) {
    FSTQuery *query = viewSnapshot.query();
    auto found_iter = _queries.find(query);
    if (found_iter != _queries.end()) {
      QueryListenersInfo &query_info = found_iter->second;
      for (const auto &listener : query_info.listeners) {
        listener->OnViewSnapshot(viewSnapshot);
      }
      query_info.set_view_snapshot(std::move(viewSnapshot));
    }
  }
}

- (void)handleError:(NSError *)error forQuery:(FSTQuery *)query {
  auto found_iter = _queries.find(query);
  if (found_iter != _queries.end()) {
    QueryListenersInfo &query_info = found_iter->second;
    for (const auto &listener : query_info.listeners) {
      listener->OnError(MakeStatus(error));
    }

    // Remove all listeners. NOTE: We don't need to call [FSTSyncEngine stopListening] after an
    // error.
    _queries.erase(found_iter);
  }
}

- (void)applyChangedOnlineState:(OnlineState)onlineState {
  self.onlineState = onlineState;

  for (auto &&kv : _queries) {
    QueryListenersInfo &info = kv.second;
    for (auto &&listener : info.listeners) {
      listener->OnOnlineStateChanged(onlineState);
    }
  }
}

@end

NS_ASSUME_NONNULL_END

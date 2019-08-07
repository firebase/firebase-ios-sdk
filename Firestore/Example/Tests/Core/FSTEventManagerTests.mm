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

#import <OCMock/OCMock.h>
#import <XCTest/XCTest.h>

#include <memory>
#include <utility>
#include <vector>

#import "Firestore/Source/Core/FSTSyncEngine.h"

#import "Firestore/Example/Tests/Util/FSTHelpers.h"

#include "Firestore/core/src/firebase/firestore/core/view_snapshot.h"
#include "Firestore/core/src/firebase/firestore/model/document_key_set.h"
#include "Firestore/core/src/firebase/firestore/model/document_set.h"
#include "Firestore/core/src/firebase/firestore/model/types.h"
#include "Firestore/core/src/firebase/firestore/util/statusor.h"
#include "Firestore/core/test/firebase/firestore/testutil/testutil.h"
#include "Firestore/core/test/firebase/firestore/testutil/xcgmock.h"

using firebase::firestore::core::EventListener;
using firebase::firestore::core::ListenOptions;
using firebase::firestore::core::QueryListener;
using firebase::firestore::core::ViewSnapshot;
using firebase::firestore::model::DocumentKeySet;
using firebase::firestore::model::DocumentSet;
using firebase::firestore::model::OnlineState;
using firebase::firestore::util::StatusOr;
using firebase::firestore::util::StatusOrCallback;

using firebase::firestore::testutil::Query;
using testing::ElementsAre;

NS_ASSUME_NONNULL_BEGIN

namespace {

ViewSnapshot::Listener NoopViewSnapshotHandler() {
  return EventListener<ViewSnapshot>::Create([](const StatusOr<ViewSnapshot> &) {});
}

std::shared_ptr<QueryListener> NoopQueryListener(core::Query query) {
  return QueryListener::Create(std::move(query), ListenOptions::DefaultOptions(),
                               NoopViewSnapshotHandler());
}

}  // namespace

// FSTEventManager implements this delegate privately
@interface FSTEventManager () <FSTSyncEngineDelegate>
@end

@interface FSTEventManagerTests : XCTestCase
@end

@implementation FSTEventManagerTests

// TODO(wilhuff): re-enable once FSTSyncEngine has been ported to C++
- (void)DISABLED_testHandlesManyListenersPerQuery {
  core::Query query = Query("foo/bar");
  auto listener1 = NoopQueryListener(query);
  auto listener2 = NoopQueryListener(query);

  FSTSyncEngine *syncEngineMock = OCMStrictClassMock([FSTSyncEngine class]);
  OCMExpect([syncEngineMock setSyncEngineDelegate:[OCMArg any]]);
  FSTEventManager *eventManager = [FSTEventManager eventManagerWithSyncEngine:syncEngineMock];

  OCMExpect([syncEngineMock listenToQuery:query]);
  [eventManager addListener:listener1];
  OCMVerifyAll((id)syncEngineMock);

  [eventManager addListener:listener2];
  [eventManager removeListener:listener2];

  OCMExpect([syncEngineMock stopListeningToQuery:query]);
  [eventManager removeListener:listener1];
  OCMVerifyAll((id)syncEngineMock);
}

- (void)testHandlesUnlistenOnUnknownListenerGracefully {
  core::Query query = Query("foo/bar");
  auto listener = NoopQueryListener(query);

  FSTSyncEngine *syncEngineMock = OCMStrictClassMock([FSTSyncEngine class]);
  OCMExpect([syncEngineMock setSyncEngineDelegate:[OCMArg any]]);
  FSTEventManager *eventManager = [FSTEventManager eventManagerWithSyncEngine:syncEngineMock];

  [eventManager removeListener:listener];
  OCMVerifyAll((id)syncEngineMock);
}

- (ViewSnapshot)makeEmptyViewSnapshotWithQuery:(const core::Query &)query {
  DocumentSet emptyDocs{query.Comparator()};
  // sync_state_changed has to be `true` to prevent an assertion about a meaningless view snapshot.
  return ViewSnapshot{
      query, emptyDocs, emptyDocs, {}, DocumentKeySet{}, false, /*sync_state_changed=*/true, false};
}

// TODO(wilhuff): re-enable once FSTSyncEngine has been ported to C++
- (void)DISABLED_testNotifiesListenersInTheRightOrder {
  core::Query query1 = Query("foo/bar");
  core::Query query2 = Query("bar/baz");
  NSMutableArray *eventOrder = [NSMutableArray array];

  auto listener1 = QueryListener::Create(
      query1, [eventOrder](StatusOr<ViewSnapshot>) { [eventOrder addObject:@"listener1"]; });

  auto listener2 = QueryListener::Create(
      query2, [eventOrder](StatusOr<ViewSnapshot>) { [eventOrder addObject:@"listener2"]; });

  auto listener3 = QueryListener::Create(
      query1, [eventOrder](StatusOr<ViewSnapshot>) { [eventOrder addObject:@"listener3"]; });

  FSTSyncEngine *syncEngineMock = OCMClassMock([FSTSyncEngine class]);
  FSTEventManager *eventManager = [FSTEventManager eventManagerWithSyncEngine:syncEngineMock];

  [eventManager addListener:listener1];
  [eventManager addListener:listener2];
  [eventManager addListener:listener3];
  OCMVerify([syncEngineMock listenToQuery:query1]);
  OCMVerify([syncEngineMock listenToQuery:query2]);

  ViewSnapshot snapshot1 = [self makeEmptyViewSnapshotWithQuery:query1];
  ViewSnapshot snapshot2 = [self makeEmptyViewSnapshotWithQuery:query2];
  [eventManager handleViewSnapshots:{snapshot1, snapshot2}];

  NSArray *expected = @[ @"listener1", @"listener3", @"listener2" ];
  XCTAssertEqualObjects(eventOrder, expected);
}

- (void)testWillForwardOnlineStateChanges {
  core::Query query = Query("foo/bar");

  class FakeQueryListener : public QueryListener {
   public:
    explicit FakeQueryListener(core::Query query)
        : QueryListener(
              std::move(query), ListenOptions::DefaultOptions(), NoopViewSnapshotHandler()) {
    }

    void OnOnlineStateChanged(OnlineState online_state) override {
      events.push_back(online_state);
    }

    std::vector<OnlineState> events;
  };

  auto fake_listener = std::make_shared<FakeQueryListener>(query);

  FSTSyncEngine *syncEngineMock = OCMClassMock([FSTSyncEngine class]);
  OCMExpect([syncEngineMock setSyncEngineDelegate:[OCMArg any]]);
  FSTEventManager *eventManager = [FSTEventManager eventManagerWithSyncEngine:syncEngineMock];

  [eventManager addListener:fake_listener];
  XC_ASSERT_THAT(fake_listener->events, ElementsAre(OnlineState::Unknown));

  [eventManager applyChangedOnlineState:OnlineState::Online];
  XC_ASSERT_THAT(fake_listener->events, ElementsAre(OnlineState::Unknown, OnlineState::Online));
}

@end

NS_ASSUME_NONNULL_END

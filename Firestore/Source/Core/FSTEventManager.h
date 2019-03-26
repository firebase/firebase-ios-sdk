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

#import <Foundation/Foundation.h>

#include <memory>

#include "Firestore/core/src/firebase/firestore/core/query_listener.h"
#include "Firestore/core/src/firebase/firestore/core/view_snapshot.h"
#include "Firestore/core/src/firebase/firestore/model/types.h"
#include "Firestore/core/src/firebase/firestore/util/status.h"

@class FSTQuery;
@class FSTSyncEngine;

NS_ASSUME_NONNULL_BEGIN

using firebase::firestore::core::QueryListener;

#pragma mark - FSTEventManager

/**
 * EventManager is responsible for mapping queries to query event emitters. It handles "fan-out."
 * (Identical queries will re-use the same watch on the backend.)
 */
@interface FSTEventManager : NSObject

+ (instancetype)eventManagerWithSyncEngine:(FSTSyncEngine *)syncEngine;

- (instancetype)init __attribute__((unavailable("Use static constructor method.")));

- (firebase::firestore::model::TargetId)addListener:(std::shared_ptr<QueryListener>)listener;
- (void)removeListener:(const std::shared_ptr<QueryListener> &)listener;

- (void)applyChangedOnlineState:(firebase::firestore::model::OnlineState)onlineState;

@end

NS_ASSUME_NONNULL_END

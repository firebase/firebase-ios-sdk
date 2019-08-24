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

#include <vector>

#include "Firestore/core/src/firebase/firestore/core/view.h"
#include "Firestore/core/src/firebase/firestore/core/view_snapshot.h"
#include "Firestore/core/src/firebase/firestore/model/document_key.h"
#include "Firestore/core/src/firebase/firestore/model/document_key_set.h"
#include "Firestore/core/src/firebase/firestore/model/document_map.h"
#include "Firestore/core/src/firebase/firestore/model/types.h"
#include "absl/types/optional.h"

namespace firebase {
namespace firestore {
namespace remote {

class TargetChange;

}  // namespace remote
}  // namespace firestore
}  // namespace firebase

namespace core = firebase::firestore::core;
namespace model = firebase::firestore::model;
namespace remote = firebase::firestore::remote;

NS_ASSUME_NONNULL_BEGIN

#pragma mark - FSTViewChange

// A set of changes to a view.
@interface FSTViewChange : NSObject

- (id)init __attribute__((unavailable("Use a static constructor method.")));

- (absl::optional<core::ViewSnapshot> &)snapshot;
- (const std::vector<core::LimboDocumentChange> &)limboChanges;
@end

#pragma mark - FSTView

/**
 * View is responsible for computing the final merged truth of what docs are in a query. It gets
 * notified of local and remote changes to docs, and applies the query filters and limits to
 * determine the most correct possible results.
 */
@interface FSTView : NSObject

- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithQuery:(core::Query)query
              remoteDocuments:(model::DocumentKeySet)remoteDocuments NS_DESIGNATED_INITIALIZER;

/**
 * Iterates over a set of doc changes, applies the query limit, and computes what the new results
 * should be, what the changes were, and whether we may need to go back to the local cache for
 * more results. Does not make any changes to the view.
 *
 * @param docChanges The doc changes to apply to this view.
 * @return a new set of docs, changes, and refill flag.
 */
- (core::ViewDocumentChanges)computeChangesWithDocuments:
    (const model::MaybeDocumentMap &)docChanges;

/**
 * Iterates over a set of doc changes, applies the query limit, and computes what the new results
 * should be, what the changes were, and whether we may need to go back to the local cache for
 * more results. Does not make any changes to the view.
 *
 * @param docChanges The doc changes to apply to this view.
 * @param previousChanges If this is being called with a refill, then start with this set of docs
 *     and changes instead of the current view.
 * @return a new set of docs, changes, and refill flag.
 */
- (core::ViewDocumentChanges)
    computeChangesWithDocuments:(const model::MaybeDocumentMap &)docChanges
                previousChanges:(const absl::optional<core::ViewDocumentChanges> &)previousChanges;

/**
 * Updates the view with the given ViewDocumentChanges.
 *
 * @param docChanges The set of changes to make to the view's docs.
 * @return A new FSTViewChange with the given docs, changes, and sync state.
 */
- (FSTViewChange *)applyChangesToDocuments:(const core::ViewDocumentChanges &)docChanges;

/**
 * Updates the view with the given ViewDocumentChanges and updates limbo docs and sync state from
 * the given (optional) target change.
 *
 * @param docChanges The set of changes to make to the view's docs.
 * @param targetChange A target change to apply for computing limbo docs and sync state.
 * @return A new FSTViewChange with the given docs, changes, and sync state.
 */
- (FSTViewChange *)applyChangesToDocuments:(const core::ViewDocumentChanges &)docChanges
                              targetChange:
                                  (const absl::optional<remote::TargetChange> &)targetChange;

/**
 * Applies an OnlineState change to the view, potentially generating an FSTViewChange if the
 * view's syncState changes as a result.
 */
- (FSTViewChange *)applyChangedOnlineState:(model::OnlineState)onlineState;

/**
 * The set of remote documents that the server has told us belongs to the target associated with
 * this view.
 */
- (const model::DocumentKeySet &)syncedDocuments;

@end

NS_ASSUME_NONNULL_END

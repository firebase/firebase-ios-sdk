// Copyright 2022 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(SessionsSubscriber)
@protocol FIRSessionsSubscriber <NSObject>

- (void)onSessionIDChanged:(NSNotification *)notification;

@end

/// Connector for bridging communication between Firebase SDKs and
/// FirebaseSessions APIs.
///
/// Normally this protocol would be defined in FirebaseSessions.swift, but
/// we haven't yet released FirebaseSessions SDK, so it is an optional
/// dependency. To make SDKs that depend on FirebaseSessions build,
/// we're defining this header in Objective-C and including it in all places.
///
/// TODO(samedson) Remove Interop when FirebaseSessions releases and move to
/// FirebaseSessions.swift
NS_SWIFT_NAME(SessionsProvider)
@protocol FIRSessionsProvider

/// Subscribes the given `subscriber` to the Notification for receiving SessionID changes.
/// The `onSessionIDChanged` method will be called immediately with the existing Session ID
/// to handle cases where the Sessions SDK has started and rotated before this subscription was
/// made.
- (void)subscribeForSessionIDchanged:(id<FIRSessionsSubscriber>)subscriber;

@end

NS_ASSUME_NONNULL_END

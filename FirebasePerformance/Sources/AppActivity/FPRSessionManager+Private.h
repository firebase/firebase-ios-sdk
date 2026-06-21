// Copyright 2020 Google LLC
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

#import "FirebasePerformance/Sources/AppActivity/FPRSessionManager.h"
#import "FirebasePerformance/Sources/Gauges/FPRGaugeManager.h"

NS_ASSUME_NONNULL_BEGIN

/** This extension should only be used for testing. */
@interface FPRSessionManager ()

@property(nonatomic) FPRGaugeManager *gaugeManager;

/** The current active session managed by the session manager. Modifiable for unit tests */
@property(atomic, nullable, readwrite) FPRSessionDetails *sessionDetails;

/**
 * Creates an instance of FPRSessionManager with the notification center provided. All the
 * notifications from the session manager will sent using this notification center.
 *
 * @param gaugeManager Gauge manager used by the session manager to work with gauges.
 * @param notificationCenter Notification center with which the session manager with be initialized.
 * @return Returns an instance of the session manager.
 */
- (FPRSessionManager *)initWithGaugeManager:(FPRGaugeManager *)gaugeManager
                         notificationCenter:(NSNotificationCenter *)notificationCenter;

/**
 * Checks if the currently active session is beyond maximum allowed time for gauge-collection. If so
 * stop gauges, else no-op.
 */
- (void)stopGaugesIfRunningTooLong;

@end

NS_ASSUME_NONNULL_END

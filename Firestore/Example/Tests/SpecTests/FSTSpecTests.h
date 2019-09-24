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
#import <XCTest/XCTest.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString *const kEagerGC;
extern NSString *const kDurablePersistence;

/**
 * FSTSpecTests run a set of portable event specifications from JSON spec files against a
 * special isolated version of the Firestore client that allows precise control over when events
 * are delivered. This allows us to test client behavior in a very reliable, deterministic way,
 * including edge cases that would be difficult to reliably reproduce in a full integration test.
 *
 * Both events from user code (adding/removing listens, performing mutations) and events from the
 * Datastore are simulated, while installing as much of the system in between as possible.
 *
 * FSTSpecTests is an abstract base class that must be subclassed to test against a specific local
 * store implementation. To create a new variant of FSTSpecTests:
 *
 * + Subclass FSTSpecTests
 * + override -persistence to create and return an appropriate Persistence implementation.
 */
@interface FSTSpecTests : XCTestCase

/** Based on its tags, determine whether the test case should run. */
- (BOOL)shouldRunWithTags:(NSArray<NSString *> *)tags;

/** Do any necessary setup for a single spec test */
- (void)setUpForSpecWithConfig:(NSDictionary *)config;

@end

NS_ASSUME_NONNULL_END

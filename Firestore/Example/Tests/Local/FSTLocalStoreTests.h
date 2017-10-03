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

#import <XCTest/XCTest.h>

@class FSTLocalStore;

NS_ASSUME_NONNULL_BEGIN

/**
 * These are tests for any implementation of the FSTLocalStore protocol.
 *
 * To test a specific implementation of FSTLocalStore:
 *
 * + Subclass FSTLocalStoreTests
 * + override -persistence, creating a new instance of FSTPersistence.
 */
@interface FSTLocalStoreTests : XCTestCase

/** Creates and returns an appropriate id<FSTPersistence> implementation. */
- (id<FSTPersistence>)persistence;

@end

NS_ASSUME_NONNULL_END

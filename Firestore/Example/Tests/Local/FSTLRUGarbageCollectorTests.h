/*
 * Copyright 2018 Google
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

#import "Firestore/Source/Local/FSTLRUGarbageCollector.h"

namespace firebase {
namespace firestore {
namespace local {

class LruParams;

}  // namespace local
}  // namespace firestore
}  // namespace firebase

@protocol FSTPersistence;

NS_ASSUME_NONNULL_BEGIN

@interface FSTLRUGarbageCollectorTests : XCTestCase

- (id<FSTPersistence>)newPersistenceWithLruParams:(firebase::firestore::local::LruParams)lruParams;

@property(nonatomic, strong) id<FSTPersistence> persistence;

@end

NS_ASSUME_NONNULL_END

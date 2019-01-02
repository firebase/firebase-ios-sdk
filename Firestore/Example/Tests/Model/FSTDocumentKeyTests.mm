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

#import "Firestore/Source/Model/FSTDocumentKey.h"

#import <XCTest/XCTest.h>

#include "Firestore/core/src/firebase/firestore/model/document_key.h"
#include "Firestore/core/src/firebase/firestore/model/resource_path.h"
#include "Firestore/core/test/firebase/firestore/testutil/testutil.h"

using firebase::firestore::testutil::Key;
using firebase::firestore::model::DocumentKey;
using firebase::firestore::model::ResourcePath;

NS_ASSUME_NONNULL_BEGIN

@interface FSTDocumentKeyTests : XCTestCase
@end

@implementation FSTDocumentKeyTests

- (void)testComparison {
  FSTDocumentKey *key1 = [FSTDocumentKey keyWithDocumentKey:Key("a/b/c/d")];
  FSTDocumentKey *key2 = [FSTDocumentKey keyWithDocumentKey:Key("a/b/c/d")];
  FSTDocumentKey *key3 = [FSTDocumentKey keyWithDocumentKey:Key("x/y/z/w")];
  XCTAssertTrue([key1 isEqual:key2]);
  XCTAssertFalse([key1 isEqual:key3]);
}

@end

NS_ASSUME_NONNULL_END

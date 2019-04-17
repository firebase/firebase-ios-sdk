/*
 * Copyright 2019 Google
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

#include "Firestore/core/test/firebase/firestore/objc/objc_class_test_helper.h"

#import <Foundation/Foundation.h>

#import "Firestore/core/src/firebase/firestore/util/string_apple.h"

namespace objc = firebase::firestore::objc;

@interface FSTObjcClassTestHelper : NSObject

- (instancetype)initWithTester:(objc::ObjcClassTester*)tester
    NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

@property(nonatomic, assign, readwrite) objc::ObjcClassTester* tester;

@end

@implementation FSTObjcClassTestHelper

- (instancetype)initWithTester:(objc::ObjcClassTester*)tester {
  if (self = [super init]) {
    _tester = tester;
    if (_tester) {
      _tester->init_calls += 1;
    }
  }
  return self;
}

- (void)dealloc {
  if (_tester) {
    _tester->dealloc_calls += 1;
  }
}

- (NSString*)description {
  return @"hello world";
}

@end

namespace firebase {
namespace firestore {
namespace objc {

ObjcClassTester::ObjcClassTester()
    : handle([[FSTObjcClassTestHelper alloc] initWithTester:this]) {
}

ObjcClassTester::ObjcClassTester(std::nullptr_t) : handle(nil) {
}

FSTObjcClassTestHelper* ObjcClassTester::CreateHelper() {
  return [[FSTObjcClassTestHelper alloc] initWithTester:nullptr];
}

void ObjcClassTester::set_helper(FSTObjcClassTestHelper* helper) {
  helper.tester = this;
  handle.Assign(helper);
}

std::string ObjcClassTester::ToString() const {
  return util::MakeString([handle description]);
}

}  // namespace objc
}  // namespace firestore
}  // namespace firebase

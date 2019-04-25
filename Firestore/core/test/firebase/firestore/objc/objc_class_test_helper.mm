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

#include "Firestore/core/src/firebase/firestore/util/string_apple.h"

namespace objc = firebase::firestore::objc;

@interface FSTObjcClassTestValue : NSObject

- (instancetype)initWithTracker:(objc::AllocationTracker*)tracker
    NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

@end

@implementation FSTObjcClassTestValue {
  objc::AllocationTracker* _tracker;
}

- (instancetype)initWithTracker:(objc::AllocationTracker*)tracker {
  if (self = [super init]) {
    _tracker = tracker;
    if (_tracker) {
      _tracker->init_calls += 1;
    }
  }
  return self;
}

- (void)dealloc {
  if (_tracker) {
    _tracker->dealloc_calls += 1;
  }
}

- (NSString*)description {
  return NSStringFromClass([self class]);
}

@end

namespace firebase {
namespace firestore {
namespace objc {

void AllocationTracker::ScopedRun(const std::function<void()>& callback) {
  @autoreleasepool {
    callback();
  }
}

ObjcClassWrapper::ObjcClassWrapper(AllocationTracker* tracker) {
  if (tracker) {
    CreateValue(tracker);
  }
}

void ObjcClassWrapper::CreateValue(AllocationTracker* tracker) {
  handle.Assign([[FSTObjcClassTestValue alloc] initWithTracker:tracker]);
}

void ObjcClassWrapper::SetValue(Handle<FSTObjcClassTestValue> helper) {
  handle.Assign(helper);
}

std::string ObjcClassWrapper::ToString() const {
  return util::ToString(handle);
}

}  // namespace objc
}  // namespace firestore
}  // namespace firebase

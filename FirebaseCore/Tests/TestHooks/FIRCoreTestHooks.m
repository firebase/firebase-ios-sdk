/*
 * Copyright 2026 Google LLC
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

#import "FirebaseCore/Tests/TestHooks/include/FIRCoreTestHooks.h"

// Internal FirebaseCore class. Declared here so the hooks don't depend on FirebaseCore's private
// headers, which go away when FirebaseCore is implemented in Swift.
@interface FIRBundleUtil : NSObject
+ (void)setRelevantBundlesForTesting:(nullable NSArray<NSBundle *> *)bundles;
@end

@implementation FIRCoreTestHooks

+ (void)setRelevantBundles:(nullable NSArray<NSBundle *> *)bundles {
  [FIRBundleUtil setRelevantBundlesForTesting:bundles];
}

+ (nullable NSException *)exceptionRaisedBy:(NS_NOESCAPE void (^)(void))block {
  @try {
    block();
  } @catch (NSException *exception) {
    return exception;
  }
  return nil;
}

@end

/*
 * Copyright 2024 Google LLC
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

#import "FirebaseMessaging/Sources/Public/FirebaseMessaging/FIRMessaging+ExtensionHelper.h"

#import "FirebaseMessaging/Sources/Public/FirebaseMessaging/FIRMessaging.h"
#import "FirebaseMessaging/Sources/Public/FirebaseMessaging/FIRMessagingExtensionHelper.h"

@implementation FIRMessaging (ExtensionHelper)

+ (FIRMessagingExtensionHelper *)extensionHelper {
  static dispatch_once_t once;
  static FIRMessagingExtensionHelper *extensionHelper;
  dispatch_once(&once, ^{
    extensionHelper = [[FIRMessagingExtensionHelper alloc] init];
  });
  return extensionHelper;
}

#if SWIFT_PACKAGE || COCOAPODS || FIREBASE_BUILD_CARTHAGE || FIREBASE_BUILD_ZIP_FILE
/// Stub used to force the linker to include the categories in this file.
void FIRInclude_FIRMessaging_ExtensionHelper_Category(void) {
}
#endif  // SWIFT_PACKAGE || COCOAPODS || FIREBASE_BUILD_CARTHAGE || FIREBASE_BUILD_ZIP_FILE

@end

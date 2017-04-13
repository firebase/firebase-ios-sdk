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

#import "googlemac/iPhone/Identity/Firebear/Sample/ApplicationDelegate.h"
#import "googlemac/iPhone/Shared/ioReplayer/IORManager.h"

int main(int argc, char *argv[]) {
  IORManager *iorManager = [IORManager sharedInstance];

  // Don't find the bundle using URLForResource:withExtension: because this will only
  // work if the bundle already exists. This would prevent recording without first
  // having an existing bundle.
  NSURL *mainBundleURL = [[NSBundle mainBundle] bundleURL];
  NSURL *databaseBundleURL =
      [mainBundleURL URLByAppendingPathComponent:@"FirebearReplayBundle.bundle"];

  [iorManager setSessionSupportEnabled:YES];
  [iorManager setDatabaseBundleURL:databaseBundleURL];
  [iorManager setAllowMultipleResponsesByDefault:YES];
  [iorManager setUseCompressedLogFormat:YES];

  @autoreleasepool {
    return UIApplicationMain(argc, argv, nil, NSStringFromClass([ApplicationDelegate class]));
  }
}

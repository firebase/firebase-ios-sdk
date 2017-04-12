/** @file main.m
    @brief Firebase Auth SDK Sample App
    @copyright Copyright 2015 Google Inc.
    @remarks Use of this SDK is subject to the Google APIs Terms of Service:
        https://developers.google.com/terms/
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

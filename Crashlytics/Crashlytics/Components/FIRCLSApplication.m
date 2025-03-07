// Copyright 2019 Google
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import "Crashlytics/Crashlytics/Components/FIRCLSApplication.h"

#import "Crashlytics/Crashlytics/Components/FIRCLSHost.h"
#import "Crashlytics/Crashlytics/Helpers/FIRCLSUtility.h"

#import <GoogleUtilities/GULAppEnvironmentUtil.h>

#if CLS_TARGET_OS_OSX
#import <AppKit/AppKit.h>
#endif

#if CLS_TARGET_OS_HAS_UIKIT
#import <UIKit/UIKit.h>
#endif

NSString* FIRCLSApplicationGetBundleIdentifier(void) {
  return [[[NSBundle mainBundle] bundleIdentifier] stringByReplacingOccurrencesOfString:@"/"
                                                                             withString:@"_"];
}

NSString* FIRCLSApplicationGetSDKBundleID(void) {
  return
      [@"com.google.firebase.crashlytics." stringByAppendingString:FIRCLSApplicationGetPlatform()];
}

// Legacy function, we use FIRCLSApplicationGetFirebasePlatform now for platform specification.
// Can't clean the code since some endpoints setup depend on this function.
NSString* FIRCLSApplicationGetPlatform(void) {
#if defined(TARGET_OS_MACCATALYST) && TARGET_OS_MACCATALYST
  return @"mac";
#elif TARGET_OS_IOS
  return @"ios";
#elif TARGET_OS_OSX
  return @"mac";
#elif TARGET_OS_TV
  return @"tvos";
#elif TARGET_OS_WATCH
  return @"ios";
#elif defined(TARGET_OS_VISION) && TARGET_OS_VISION
  return @"ios";
#endif
}

NSString* FIRCLSApplicationGetFirebasePlatform(void) {
  NSString* firebasePlatform = [GULAppEnvironmentUtil applePlatform];
#if TARGET_OS_IOS
  // This check is necessary because iOS-only apps running on iPad
  // will report UIUserInterfaceIdiomPhone via UI_USER_INTERFACE_IDIOM().
  if ([firebasePlatform isEqualToString:@"ios"] &&
      ([[UIDevice currentDevice].model.lowercaseString containsString:@"ipad"] ||
       [[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)) {
    return @"ipados";
  }
#endif

  return firebasePlatform;
}

// these defaults match the FIRCLSInfoPlist helper in FIRCLSIDEFoundation
NSString* FIRCLSApplicationGetBundleVersion(void) {
  return [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];
}

NSString* FIRCLSApplicationGetShortBundleVersion(void) {
  return [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
}

NSString* FIRCLSApplicationGetName(void) {
  NSString* name;
  NSBundle* mainBundle;

  mainBundle = [NSBundle mainBundle];

  name = [mainBundle objectForInfoDictionaryKey:@"CFBundleDisplayName"];
  if (name) {
    return name;
  }

  name = [mainBundle objectForInfoDictionaryKey:@"CFBundleName"];
  if (name) {
    return name;
  }

  return FIRCLSApplicationGetBundleVersion();
}

BOOL FIRCLSApplicationHasAppStoreReceipt(void) {
  NSURL* url = NSBundle.mainBundle.appStoreReceiptURL;
  return [NSFileManager.defaultManager fileExistsAtPath:[url path]];
}

FIRCLSApplicationInstallationSourceType FIRCLSApplicationInstallationSource(void) {
  if (FIRCLSApplicationHasAppStoreReceipt()) {
    return FIRCLSApplicationInstallationSourceTypeAppStore;
  }

  return FIRCLSApplicationInstallationSourceTypeDeveloperInstall;
}

BOOL FIRCLSApplicationIsExtension(void) {
  return FIRCLSApplicationExtensionPointIdentifier() != nil;
}

NSString* FIRCLSApplicationExtensionPointIdentifier(void) {
  id extensionDict = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"NSExtension"];

  if (!extensionDict) {
    return nil;
  }

  if (![extensionDict isKindOfClass:[NSDictionary class]]) {
    FIRCLSSDKLog("Error: NSExtension Info.plist entry is mal-formed\n");
    return nil;
  }

  id typeValue = [(NSDictionary*)extensionDict objectForKey:@"NSExtensionPointIdentifier"];

  if (![typeValue isKindOfClass:[NSString class]]) {
    FIRCLSSDKLog("Error: NSExtensionPointIdentifier Info.plist entry is mal-formed\n");
    return nil;
  }

  return typeValue;
}

#if CLS_TARGET_OS_HAS_UIKIT
UIApplication* FIRCLSApplicationSharedInstance(void) {
  if (FIRCLSApplicationIsExtension()) {
    return nil;
  }

  return [[UIApplication class] performSelector:@selector(sharedApplication)];
}
#elif CLS_TARGET_OS_OSX
id FIRCLSApplicationSharedInstance(void) {
  return [NSClassFromString(@"NSApplication") sharedApplication];
}
#else
id FIRCLSApplicationSharedInstance(void) {
  return nil;  // FIXME: what do we actually return for watch?
}
#endif

id<NSObject> FIRCLSApplicationBeginActivity(NSActivityOptions options, NSString* reason) {
  if ([[NSProcessInfo processInfo] respondsToSelector:@selector(beginActivityWithOptions:
                                                                                  reason:)]) {
    return [[NSProcessInfo processInfo] beginActivityWithOptions:options reason:reason];
  }

#if CLS_TARGET_OS_OSX
  if (options & NSActivitySuddenTerminationDisabled) {
    [[NSProcessInfo processInfo] disableSuddenTermination];
  }

  if (options & NSActivityAutomaticTerminationDisabled) {
    [[NSProcessInfo processInfo] disableAutomaticTermination:reason];
  }
#endif

  // encode the options, so we can undo our work later
  return @{@"options" : @(options), @"reason" : reason};
}

void FIRCLSApplicationEndActivity(id<NSObject> activity) {
  if (!activity) {
    return;
  }

  if ([[NSProcessInfo processInfo] respondsToSelector:@selector(endActivity:)]) {
    [[NSProcessInfo processInfo] endActivity:activity];
    return;
  }

#if CLS_TARGET_OS_OSX
  NSInteger options = [[(NSDictionary*)activity objectForKey:@"options"] integerValue];

  if (options & NSActivitySuddenTerminationDisabled) {
    [[NSProcessInfo processInfo] enableSuddenTermination];
  }

  if (options & NSActivityAutomaticTerminationDisabled) {
    [[NSProcessInfo processInfo]
        enableAutomaticTermination:[(NSDictionary*)activity objectForKey:@"reason"]];
  }
#endif
}

void FIRCLSApplicationActivity(NSActivityOptions options, NSString* reason, void (^block)(void)) {
  id<NSObject> activity = FIRCLSApplicationBeginActivity(options, reason);

  block();

  FIRCLSApplicationEndActivity(activity);
}

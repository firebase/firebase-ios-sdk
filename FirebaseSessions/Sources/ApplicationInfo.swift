//
// Copyright 2022 Google LLC
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


import Foundation

@_implementationOnly import FirebaseCore
@_implementationOnly import GoogleUtilities

protocol ApplicationInfoProtocol {
  /// Google App ID / GMP App ID
  var appID: String { get }
  
  /// App's bundle ID / bundle short version
  var bundleID: String { get }
  
  /// Version of the Firebase SDK
  var sdkVersion: String { get }
  
  /// Crashlytics-specific device / OS filter values.
  var osName: String { get }
}

class ApplicationInfo: ApplicationInfoProtocol {
  
  let appID: String

  init(appID: String) {
    self.appID = appID
  }
  
  var bundleID: String {
    return Bundle.main.bundleIdentifier ?? ""
  }
  
  var sdkVersion: String {
    return FirebaseVersion()
  }
  
  var osName: String {
    
    // TODO: This must share code with Crashlytics
    // TODO: This must share code with Crashlytics
    // TODO: This must share code with Crashlytics
    // TODO: This must share code with Crashlytics
    // TODO: This must share code with Crashlytics
    // TODO: This must share code with Crashlytics
    // TODO: This must share code with Crashlytics
//    NSString* FIRCLSApplicationGetFirebasePlatform(void) {
//      NSString* firebasePlatform = [GULAppEnvironmentUtil applePlatform];
//    #if TARGET_OS_IOS
//      // This check is necessary because iOS-only apps running on iPad
//      // will report UIUserInterfaceIdiomPhone via UI_USER_INTERFACE_IDIOM().
//      if ([firebasePlatform isEqualToString:@"ios"] &&
//          ([[UIDevice currentDevice].model.lowercaseString containsString:@"ipad"] ||
//           [[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)) {
//        return @"ipados";
//      }
//    #endif
//
//      return firebasePlatform;
//    }
    
    // TODO: Update once https://github.com/google/GoogleUtilities/pull/89 is submitted
    return GULAppEnvironmentUtil.applePlatform()
  }

}

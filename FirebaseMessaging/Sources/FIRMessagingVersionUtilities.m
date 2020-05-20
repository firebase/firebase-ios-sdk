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

#import "FirebaseMessaging/Sources/FIRMessagingVersionUtilities.h"

#import "FirebaseMessaging/Sources/FIRMessagingDefines.h"

// Convert the macro to a string
#define STR_EXPAND(x) #x
#define STR(x) STR_EXPAND(x)

static NSString *const kSemanticVersioningSeparator = @".";
static NSString *const kBetaVersionPrefix = @"-beta";

static NSString *libraryVersion;
static int majorVersion;
static int minorVersion;
static int patchVersion;
static int betaVersion;

void FIRMessagingParseCurrentLibraryVersion(void) {
  static NSArray *allVersions;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    NSMutableString *daylightVersion =
        [NSMutableString stringWithUTF8String:STR(FIRMessaging_LIB_VERSION)];
    // Parse versions
    // major, minor, patch[-beta#]
    allVersions = [daylightVersion componentsSeparatedByString:kSemanticVersioningSeparator];
    if (allVersions.count == 3) {
      majorVersion = [allVersions[0] intValue];
      minorVersion = [allVersions[1] intValue];

      // Parse patch and beta versions
      NSArray *patchAndBetaVersion =
          [allVersions[2] componentsSeparatedByString:kBetaVersionPrefix];
      if (patchAndBetaVersion.count == 2) {
        patchVersion = [patchAndBetaVersion[0] intValue];
        betaVersion = [patchAndBetaVersion[1] intValue];
      } else if (patchAndBetaVersion.count == 1) {
        patchVersion = [patchAndBetaVersion[0] intValue];
      }
    }

    // Copy library version
    libraryVersion = [daylightVersion copy];
  });
}

NSString *FIRMessagingCurrentLibraryVersion(void) {
  FIRMessagingParseCurrentLibraryVersion();
  return libraryVersion;
}

int FIRMessagingCurrentLibraryVersionMajor(void) {
  FIRMessagingParseCurrentLibraryVersion();
  return majorVersion;
}

int FIRMessagingCurrentLibraryVersionMinor(void) {
  FIRMessagingParseCurrentLibraryVersion();
  return minorVersion;
}

int FIRMessagingCurrentLibraryVersionPatch(void) {
  FIRMessagingParseCurrentLibraryVersion();
  return patchVersion;
}

BOOL FIRMessagingCurrentLibraryVersionIsBeta(void) {
  FIRMessagingParseCurrentLibraryVersion();
  return betaVersion > 0;
}

// Copyright 2017 Google
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

#import "Private/FIRURLSchemeUtil.h"
#import "Private/FIRLogger.h"

/**
 * Regular expression to match the URL scheme for Google sign-in.
 */
static NSString *const kFIRGoogleSignInURLSchemePattern =
    @"^com\\.googleusercontent\\.apps\\.\\d+-\\w+$";

BOOL fir_areURLSchemesValidForGoogleSignIn(NSArray *urlSchemes) {
  BOOL hasReversedClientID = NO;
  for (NSString *urlScheme in urlSchemes) {
    if (!hasReversedClientID) {
      NSRange range = [urlScheme rangeOfString:kFIRGoogleSignInURLSchemePattern
                                       options:NSRegularExpressionSearch];
      if (range.location != NSNotFound) {
        hasReversedClientID = YES;
      }
    }
  }
  if (hasReversedClientID) {
    return YES;
  }
  if (!hasReversedClientID) {
    FIRLogInfo(kFIRLoggerCore, @"I-COR000021",
               @"A reversed client ID should be added as a URL "
               @"scheme to enable Google sign-in.");
  }
  return NO;
}

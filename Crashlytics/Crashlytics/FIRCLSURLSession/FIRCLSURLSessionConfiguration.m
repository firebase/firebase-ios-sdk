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

#import "Crashlytics/Crashlytics/FIRCLSURLSession/FIRCLSURLSessionAvailability.h"

#import "Crashlytics/Crashlytics/FIRCLSURLSession/FIRCLSURLSession.h"

#if FIRCLSURLSESSION_REQUIRED
#import "Crashlytics/Crashlytics/FIRCLSURLSession/FIRCLSURLSessionConfiguration.h"

@implementation FIRCLSURLSessionConfiguration

@synthesize URLCache = _URLCache;
@synthesize HTTPAdditionalHeaders = _additionalHeaders;
@synthesize HTTPCookieAcceptPolicy = _cookiePolicy;

+ (NSURLSessionConfiguration *)defaultSessionConfiguration {
  return [NSURLSessionConfiguration defaultSessionConfiguration];
}

+ (NSURLSessionConfiguration *)ephemeralSessionConfiguration {
  return [NSURLSessionConfiguration ephemeralSessionConfiguration];
}

+ (NSURLSessionConfiguration *)backgroundSessionConfiguration:(NSString *)identifier {
  return [self backgroundSessionConfigurationWithIdentifier:identifier];
}

+ (NSURLSessionConfiguration *)backgroundSessionConfigurationWithIdentifier:(NSString *)identifier {
  return [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:identifier];
}

- (id)copyWithZone:(NSZone *)zone {
  FIRCLSURLSessionConfiguration *configuration;

  configuration = [FIRCLSURLSessionConfiguration new];
  [configuration setHTTPAdditionalHeaders:[self HTTPAdditionalHeaders]];

  return configuration;
}

// This functionality is not supported by the wrapper, so we just stub it out
- (BOOL)sessionSendsLaunchEvents {
  return NO;
}

- (void)setSessionSendsLaunchEvents:(BOOL)sessionSendsLaunchEvents {
}

@end

#else

INJECT_STRIP_SYMBOL(clsurlsessionconfiguration)

#endif

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

#import "FirebaseAppCheck/Sources/DebugProvider/FIRAppCheckDebugTokenConfigStore.h"

#import <TargetConditionals.h>

#import "FirebaseAppCheck/Sources/Core/FIRAppCheckLogger.h"

#import "FirebaseCore/Extension/FirebaseCoreInternal.h"

NS_ASSUME_NONNULL_BEGIN

/// Environment variable set by the Simulator to the host user's home directory.
static NSString *const kSimulatorHostHomeEnvKey = @"SIMULATOR_HOST_HOME";

/// Top-level key of the config store file mapping Google App IDs to debug tokens.
static NSString *const kTokensKey = @"tokens";

@implementation FIRAppCheckDebugTokenConfigStore

+ (NSString *)relativePath {
  return @".config/configstore/firebase-appcheck.json";
}

+ (nullable NSString *)debugTokenForGoogleAppID:(NSString *)googleAppID {
  return [self debugTokenForGoogleAppID:googleAppID
                            environment:[NSProcessInfo processInfo].environment];
}

+ (nullable NSString *)debugTokenForGoogleAppID:(NSString *)googleAppID
                                    environment:
                                        (NSDictionary<NSString *, NSString *> *)environment {
#if TARGET_OS_SIMULATOR
  NSString *hostHome = environment[kSimulatorHostHomeEnvKey];
  if (hostHome.length == 0 || googleAppID.length == 0) {
    return nil;
  }

  NSURL *fileURL = [[NSURL fileURLWithPath:hostHome
                               isDirectory:YES] URLByAppendingPathComponent:self.relativePath
                                                                isDirectory:NO];
  NSError *readError;
  NSData *data = [NSData dataWithContentsOfURL:fileURL options:0 error:&readError];
  if (!data) {
    // A missing file simply means the Firebase CLI flow is not in use.
    BOOL isMissingFile = [readError.domain isEqualToString:NSCocoaErrorDomain] &&
                         readError.code == NSFileReadNoSuchFileError;
    if (!isMissingFile) {
      FIRLogWarning(kFIRLoggerAppCheck,
                    kFIRLoggerAppCheckMessageCodeDebugTokenConfigStoreUnreadable,
                    @"Failed to read App Check debug tokens from ~/%@: %@", self.relativePath,
                    readError.localizedDescription);
    }
    return nil;
  }

  NSError *parseError;
  id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&parseError];
  NSDictionary *tokens = [json isKindOfClass:[NSDictionary class]] ? json[kTokensKey] : nil;
  if (![tokens isKindOfClass:[NSDictionary class]]) {
    FIRLogWarning(kFIRLoggerAppCheck, kFIRLoggerAppCheckMessageCodeDebugTokenConfigStoreUnreadable,
                  @"Failed to parse App Check debug tokens from ~/%@: %@", self.relativePath,
                  parseError.localizedDescription ?: @"missing `tokens` object");
    return nil;
  }

  NSString *token = tokens[googleAppID];
  if (![token isKindOfClass:[NSString class]] || token.length == 0) {
    return nil;
  }
  return token;
#else
  return nil;
#endif  // TARGET_OS_SIMULATOR
}

@end

NS_ASSUME_NONNULL_END

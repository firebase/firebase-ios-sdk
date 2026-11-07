/*
 * Copyright 2020 Google LLC
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

#import "FirebaseAppCheck/Sources/Public/FirebaseAppCheck/FIRAppCheckDebugProvider.h"

#if __has_include(<AppCheckCore/AppCheckCore-Swift.h>)
#import <AppCheckCore/AppCheckCore-Swift.h>
#elif __has_include("AppCheckCore-Swift.h")
#import "AppCheckCore-Swift.h"
#else
@import AppCheckCore;
#endif

#import "FirebaseAppCheck/Sources/Core/FIRApp+AppCheck.h"
#import "FirebaseAppCheck/Sources/Core/FIRAppCheckLogger.h"
#import "FirebaseAppCheck/Sources/Core/FIRAppCheckToken+Internal.h"
#import "FirebaseAppCheck/Sources/Core/FIRAppCheckValidator.h"
#import "FirebaseAppCheck/Sources/Core/FIRHeartbeatLogger+AppCheck.h"
#import "FirebaseAppCheck/Sources/DebugProvider/FIRAppCheckDebugTokenConfigStore.h"

#import "FirebaseCore/Extension/FirebaseCoreInternal.h"

NS_ASSUME_NONNULL_BEGIN

@interface FIRAppCheckDebugProvider ()

@property(nonatomic, readonly) GACAppCheckDebugProvider *debugProvider;
@property(nonatomic, readonly, copy, nullable) NSString *projectID;
@property(nonatomic, readonly, copy) NSString *googleAppID;
/// Where `debugProvider` got the debug token it exchanges.
///
/// The only token `-initWithApp:` passes to `debugProvider` is one read from the Firebase CLI
/// config store on the host machine, so `GACAppCheckDebugTokenSourceProvided` means that token is
/// in use.
@property(nonatomic, readonly) GACAppCheckDebugTokenSource debugTokenSource;

@end

@implementation FIRAppCheckDebugProvider

- (instancetype)initWithDebugProvider:(GACAppCheckDebugProvider *)debugProvider
                            projectID:(nullable NSString *)projectID
                          googleAppID:(NSString *)googleAppID {
  self = [super init];
  if (self) {
    _debugProvider = debugProvider;
    _projectID = [projectID copy];
    _googleAppID = [googleAppID copy];
    _debugTokenSource = debugProvider.debugTokenSource;

    switch (_debugTokenSource) {  // No `default:` so `-Wswitch` flags new AppCheckCore sources.
      case GACAppCheckDebugTokenSourceLocal:
        [self logDebugTokenMessageWithMessageCode:kFIRLoggerAppCheckMessageCodeDebugToken
                                           prefix:@""];
        break;
      case GACAppCheckDebugTokenSourceProvided:
        FIRLogNotice(kFIRLoggerAppCheck, kFIRLoggerAppCheckMessageCodeDebugTokenFromConfigStore,
                     @"Debug token loaded from ~/%@.",
                     FIRAppCheckDebugTokenConfigStore.relativePath);
        break;
      case GACAppCheckDebugTokenSourceEnvironmentVariable:
        // App Check Core logs that the environment variable is used; the local token is unused.
        break;
    }
  }
  return self;
}

- (nullable instancetype)initWithApp:(FIRApp *)app {
  NSArray<NSString *> *missingOptionsFields =
      [FIRAppCheckValidator tokenExchangeMissingFieldsInOptions:app.options];
  if (missingOptionsFields.count > 0) {
    FIRLogError(kFIRLoggerAppCheck, kFIRLoggerAppCheckMessageDebugProviderIncompleteFIROptions,
                @"Cannot instantiate `FIRAppCheckDebugProvider` for app: %@. The following "
                @"`FirebaseOptions` fields are missing: %@",
                app.name, [missingOptionsFields componentsJoinedByString:@", "]);
    return nil;
  }

  // In a Simulator, use the debug token provisioned by the Firebase CLI on the host machine (if
  // any) instead of generating a new one that would need to be registered manually.
  NSString *configStoreDebugToken =
      [FIRAppCheckDebugTokenConfigStore debugTokenForGoogleAppID:app.options.googleAppID];

  GACAppCheckDebugProvider *debugProvider =
      [[GACAppCheckDebugProvider alloc] initWithServiceName:app.name
                                               resourceName:app.resourceName
                                                    baseURL:nil
                                                     APIKey:app.options.APIKey
                                               requestHooks:@[ [app.heartbeatLogger requestHook] ]
                                                 debugToken:configStoreDebugToken];

  return [self initWithDebugProvider:debugProvider
                           projectID:app.options.projectID
                         googleAppID:app.options.googleAppID];
}

- (NSString *)currentDebugToken {
  return [self.debugProvider currentDebugToken];
}

- (NSString *)localDebugToken {
  return [self.debugProvider localDebugToken];
}

#pragma mark - Private Helpers

- (void)logDebugTokenMessageWithMessageCode:(NSString *)messageCode prefix:(NSString *)prefix {
  if (self.projectID.length > 0 && self.googleAppID.length > 0) {
    NSString *debugToken = self.localDebugToken;
    if (!debugToken) {
      return;
    }

    FIRLogWarning(
        kFIRLoggerAppCheck, messageCode,
        @"%@"
         "To use this token for app debugging, register it with your project.\n\n"
         "Firebase App Check debug token: %@\n\n"
         "You can do so in the Firebase Console: \n"
         "https://console.firebase.google.com/project/%@/appcheck/apps?selectedAppId=%@ \n\n"
         "Or using the Firebase CLI: \n"
         "firebase appcheck:debugtokens:create %@ --project %@ --app %@\n\n"
         "Note: To keep your project secure, please revoke and delete this token using the \n"
         "Firebase Console or the CLI (`firebase appcheck:debugtokens:delete`) when you finish "
         "debugging.\n\n"
         "Warning: This debug token is a secret and should not be shared or uploaded to source "
         "code.\n\n"
         "Debug Token Guide: https://firebase.google.com/docs/app-check/ios/debug-provider\n"
         "Firebase CLI install instructions: https://firebase.google.com/docs/cli\n",
        prefix, debugToken, self.projectID, self.googleAppID, debugToken, self.projectID,
        self.googleAppID);
  }
}

- (void)logDebugTokenExchangeError:(NSError *)error {
  if (self.debugTokenSource == GACAppCheckDebugTokenSourceLocal) {
    [self logDebugTokenMessageWithMessageCode:kFIRLoggerAppCheckMessageCodeDebugTokenExchangeFailed
                                       prefix:@"Failed to exchange debug token. "];
    return;
  }

  NSString *message = [self debugTokenExchangeFailureMessageForError:error];
  if (!message) {
    return;
  }
  NSString *messageCode = self.debugTokenSource == GACAppCheckDebugTokenSourceProvided
                              ? kFIRLoggerAppCheckMessageCodeConfigStoreDebugTokenExchangeFailed
                              : kFIRLoggerAppCheckMessageCodeDebugTokenExchangeFailed;
  FIRLogWarning(kFIRLoggerAppCheck, messageCode, @"%@", message);
}

/// Returns the message to log when exchanging an environment variable or config store debug token
/// fails, or `nil` when there is nothing actionable to report (e.g., the server was unreachable).
///
/// Unlike the local token's registration instructions, these messages never include the token.
- (nullable NSString *)debugTokenExchangeFailureMessageForError:(NSError *)error {
  if ([error.domain isEqualToString:GACAppCheckErrors.errorDomain] &&
      error.code == GACAppCheckErrorCodeServerUnreachable) {
    return nil;
  }

  NSString *projectArgument = self.projectID.length > 0
                                  ? [NSString stringWithFormat:@" --project %@", self.projectID]
                                  : @"";
  // App Check Core errors describe the failure in `NSLocalizedFailureReasonErrorKey`; using it
  // directly avoids Foundation's generic "The operation couldn’t be completed." prefix.
  NSString *errorDescription = error.localizedFailureReason ?: error.localizedDescription;
  if (self.debugTokenSource == GACAppCheckDebugTokenSourceProvided) {
    // The config store is only read at launch, so a new token requires relaunching the app.
    return [NSString stringWithFormat:@"Failed to exchange the debug token loaded from ~/%@: %@\n\n"
                                      @"If the token was rejected by the server, run "
                                      @"`firebase appcheck:debugtokens:create --force%@ --app %@` "
                                      @"to provision a new token, then relaunch the app.",
                                      FIRAppCheckDebugTokenConfigStore.relativePath,
                                      errorDescription, projectArgument, self.googleAppID];
  }
  if (self.debugTokenSource == GACAppCheckDebugTokenSourceEnvironmentVariable) {
    return [NSString
        stringWithFormat:@"Failed to exchange the debug token from the `AppCheckDebugToken` or "
                         @"`FIRAAppCheckDebugToken` environment variable: %@\n\n"
                         @"Make sure the token is registered for app %@, for example with "
                         @"`firebase appcheck:debugtokens:create <token>%@ --app %@`.",
                         errorDescription, self.googleAppID, projectArgument, self.googleAppID];
  }
  return nil;
}

#pragma mark - FIRAppCheckProvider

- (void)getTokenWithCompletion:(void (^)(FIRAppCheckToken *_Nullable token,
                                         NSError *_Nullable error))handler {
  [self.debugProvider getTokenWithCompletion:^(GACAppCheckToken *_Nullable internalToken,
                                               NSError *_Nullable error) {
    if (error) {
      [self logDebugTokenExchangeError:error];
      handler(nil, error);
      return;
    }

    handler([[FIRAppCheckToken alloc] initWithInternalToken:internalToken], nil);
  }];
}

- (void)getLimitedUseTokenWithCompletion:(void (^)(FIRAppCheckToken *_Nullable,
                                                   NSError *_Nullable))handler {
  [self.debugProvider getLimitedUseTokenWithCompletion:^(GACAppCheckToken *_Nullable internalToken,
                                                         NSError *_Nullable error) {
    if (error) {
      [self logDebugTokenExchangeError:error];
      handler(nil, error);
      return;
    }

    handler([[FIRAppCheckToken alloc] initWithInternalToken:internalToken], nil);
  }];
}

@end

NS_ASSUME_NONNULL_END

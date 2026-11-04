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

#import <TargetConditionals.h>
#if TARGET_OS_OSX
#import <pwd.h>
#import <unistd.h>
#endif

#if __has_include(<AppCheckCore/AppCheckCore-Swift.h>)
#import <AppCheckCore/AppCheckCore-Swift.h>
#elif __has_include("AppCheckCore-Swift.h")
#import "AppCheckCore-Swift.h"
#else
@import AppCheckCore;
#endif
#import <GoogleUtilities/GULUserDefaults.h>

#import "FirebaseAppCheck/Sources/Core/FIRApp+AppCheck.h"
#import "FirebaseAppCheck/Sources/Core/FIRAppCheckLogger.h"
#import "FirebaseAppCheck/Sources/Core/FIRAppCheckToken+Internal.h"
#import "FirebaseAppCheck/Sources/Core/FIRAppCheckValidator.h"
#import "FirebaseAppCheck/Sources/Core/FIRHeartbeatLogger+AppCheck.h"

#import "FirebaseCore/Extension/FirebaseCoreInternal.h"

NS_ASSUME_NONNULL_BEGIN

static NSString *const kFirebaseDebugTokenEnvKey = @"FIREBASE_APPCHECK_DEBUG_TOKEN";
static NSString *const kAppCheckDebugTokenEnvKey = @"AppCheckDebugToken";
static NSString *const kLegacyFirebaseDebugTokenEnvKey = @"FIRAAppCheckDebugToken";
static NSString *const kSimulatorHostHomeEnvKey = @"SIMULATOR_HOST_HOME";
static NSString *const kXDGConfigHomeEnvKey = @"XDG_CONFIG_HOME";
static NSString *const kLocalConfigRelativePath = @"configstore/firebase-appcheck.json";
static NSString *const kDebugTokenUserDefaultsKey = @"GACAppCheckDebugToken";
static NSString *const kInjectedDebugTokenClassName = @"FIRAppCheckInjectedDebugToken";

@protocol FIRAppCheckInjectedDebugTokenProtocol <NSObject>
@optional
+ (nullable NSDictionary<NSString *, NSString *> *)tokens;
+ (nullable NSString *)token;
@end

@interface FIRAppCheckDebugProvider ()

@property(nonatomic, readonly) GACAppCheckDebugProvider *debugProvider;
@property(nonatomic, readonly, copy, nullable) NSString *projectID;
@property(nonatomic, readonly, copy) NSString *googleAppID;
@property(nonatomic, readonly, copy, nullable) NSString *resolvedDebugToken;
@property(nonatomic, readonly, copy, nullable) NSString *resolvedTokenSource;

@end

@implementation FIRAppCheckDebugProvider

- (instancetype)initWithDebugProvider:(GACAppCheckDebugProvider *)debugProvider
                            projectID:(nullable NSString *)projectID
                          googleAppID:(NSString *)googleAppID {
  return [self initWithDebugProvider:debugProvider
                           projectID:projectID
                         googleAppID:googleAppID
                  resolvedDebugToken:nil
                 resolvedTokenSource:nil];
}

- (instancetype)initWithDebugProvider:(GACAppCheckDebugProvider *)debugProvider
                            projectID:(nullable NSString *)projectID
                          googleAppID:(NSString *)googleAppID
                   resolvedDebugToken:(nullable NSString *)resolvedDebugToken
                  resolvedTokenSource:(nullable NSString *)resolvedTokenSource {
  self = [super init];
  if (self) {
    _debugProvider = debugProvider;
    _projectID = [projectID copy];
    _googleAppID = [googleAppID copy];
    _resolvedDebugToken = [resolvedDebugToken copy];
    _resolvedTokenSource = [resolvedTokenSource copy];

    if (_resolvedTokenSource.length > 0) {
      FIRAppCheckLogDebugTokenSource(_resolvedTokenSource);
    }

    if (_resolvedDebugToken.length == 0) {
      [self logDebugTokenMessageWithMessageCode:kFIRLoggerAppCheckMessageCodeDebugToken prefix:@""];
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

  NSString *resolvedSource = nil;
  NSString *resolvedToken = nil;
  GACAppCheckDebugProvider *debugProvider = nil;
  // Both steps read the process environment, which `debugProviderForApp:debugToken:` may
  // temporarily modify, so they must not interleave with another provider's initialization.
  @synchronized([FIRAppCheckDebugProvider class]) {
    resolvedToken = [[self class] resolveDebugTokenForAppID:app.options.googleAppID
                                                     source:&resolvedSource];
    if (resolvedToken.length == 0) {
      // Check before creating the AppCheckCore provider, which generates and stores a token when
      // none is stored.
      NSString *storedToken =
          [[GULUserDefaults standardUserDefaults] stringForKey:kDebugTokenUserDefaultsKey];
      resolvedSource = storedToken.length > 0 ? @"NSUserDefaults" : @"auto-generated UUID";
    }
    debugProvider = [[self class] debugProviderForApp:app debugToken:resolvedToken];
  }

  return [self initWithDebugProvider:debugProvider
                           projectID:app.options.projectID
                         googleAppID:app.options.googleAppID
                  resolvedDebugToken:resolvedToken
                 resolvedTokenSource:resolvedSource];
}

- (NSString *)currentDebugToken {
  if (self.resolvedDebugToken.length > 0) {
    return self.resolvedDebugToken;
  }
  return [self.debugProvider currentDebugToken];
}

- (NSString *)localDebugToken {
  return [self.debugProvider localDebugToken];
}

#pragma mark - AppCheckCore Debug Provider

/// Creates the AppCheckCore debug provider that performs the token exchange. Callers must hold the
/// `FIRAppCheckDebugProvider` class lock.
///
/// AppCheckCore reads the debug token only from the `AppCheckDebugToken` and
/// `FIRAAppCheckDebugToken` environment variables, and only during initialization. A token resolved
/// from any other source is handed off by setting `AppCheckDebugToken` while the provider is
/// created, and the previous value is restored immediately afterwards.
///
/// TODO: Pass the token to an AppCheckCore initializer that accepts it directly once one is
/// available; mutating the process environment is not thread-safe.
+ (GACAppCheckDebugProvider *)debugProviderForApp:(FIRApp *)app
                                       debugToken:(nullable NSString *)debugToken {
  NSString *appCheckCoreToken =
      [self appCheckCoreDebugTokenInEnvironment:NSProcessInfo.processInfo.environment];
  if (debugToken.length == 0 || [debugToken isEqualToString:appCheckCoreToken]) {
    // AppCheckCore resolves the same token on its own, so no handoff is needed.
    return [self appCheckCoreDebugProviderForApp:app];
  }

  const char *existingValue = getenv(kAppCheckDebugTokenEnvKey.UTF8String);
  NSString *previousValue = existingValue ? @(existingValue) : nil;
  setenv(kAppCheckDebugTokenEnvKey.UTF8String, debugToken.UTF8String, 1);
  GACAppCheckDebugProvider *debugProvider = [self appCheckCoreDebugProviderForApp:app];
  if (previousValue != nil) {
    setenv(kAppCheckDebugTokenEnvKey.UTF8String, previousValue.UTF8String, 1);
  } else {
    unsetenv(kAppCheckDebugTokenEnvKey.UTF8String);
  }
  return debugProvider;
}

+ (GACAppCheckDebugProvider *)appCheckCoreDebugProviderForApp:(FIRApp *)app {
  return
      [[GACAppCheckDebugProvider alloc] initWithServiceName:app.name
                                               resourceName:app.resourceName
                                                    baseURL:nil
                                                     APIKey:app.options.APIKey
                                               requestHooks:@[ [app.heartbeatLogger requestHook] ]];
}

/// Returns the debug token that AppCheckCore reads from `environment`, if any. Matches
/// AppCheckCore's precedence: `AppCheckDebugToken` wins over `FIRAAppCheckDebugToken`.
+ (nullable NSString *)appCheckCoreDebugTokenInEnvironment:
    (NSDictionary<NSString *, NSString *> *)environment {
  NSString *token = environment[kAppCheckDebugTokenEnvKey];
  if (token.length > 0) {
    return token;
  }
  token = environment[kLegacyFirebaseDebugTokenEnvKey];
  return token.length > 0 ? token : nil;
}

#pragma mark - Token Resolution

+ (nullable NSString *)resolveDebugTokenForAppID:(NSString *)googleAppID
                                          source:(NSString *_Nullable *_Nullable)outSource {
  NSDictionary<NSString *, NSString *> *environment = NSProcessInfo.processInfo.environment;

  // 1. FIREBASE_APPCHECK_DEBUG_TOKEN environment variable.
  NSString *firebaseEnvToken = environment[kFirebaseDebugTokenEnvKey];
  if ([firebaseEnvToken isKindOfClass:[NSString class]] && firebaseEnvToken.length > 0) {
    if (outSource) {
      *outSource = @"environment variable (FIREBASE_APPCHECK_DEBUG_TOKEN)";
    }
    return firebaseEnvToken;
  }

  // 2. AppCheckDebugToken (and legacy FIRAAppCheckDebugToken) environment variable.
  NSString *appCheckEnvToken = environment[kAppCheckDebugTokenEnvKey];
  if ([appCheckEnvToken isKindOfClass:[NSString class]] && appCheckEnvToken.length > 0) {
    if (outSource) {
      *outSource = @"environment variable (AppCheckDebugToken)";
    }
    return appCheckEnvToken;
  }

  NSString *legacyEnvToken = environment[kLegacyFirebaseDebugTokenEnvKey];
  if ([legacyEnvToken isKindOfClass:[NSString class]] && legacyEnvToken.length > 0) {
    if (outSource) {
      *outSource = @"environment variable (FIRAAppCheckDebugToken)";
    }
    return legacyEnvToken;
  }

  // 3. Simulator / macOS host configuration file (~/.config/configstore/firebase-appcheck.json).
#if TARGET_OS_SIMULATOR || TARGET_OS_OSX
  NSString *localConfigToken = [self tokenFromLocalConfigForAppID:googleAppID
                                                      environment:environment];
  if (localConfigToken.length > 0) {
    if (outSource) {
      *outSource = @"~/.config/configstore/firebase-appcheck.json";
    }
    return localConfigToken;
  }
#endif

  // 4. Build-time injected class (FIRAppCheckInjectedDebugToken). The generated class is wrapped in
  // `#if DEBUG`, so it is only compiled into Debug builds of the app.
  NSString *injectedToken =
      [self tokenFromInjectedClass:NSClassFromString(kInjectedDebugTokenClassName)
                          forAppID:googleAppID
                            source:outSource];
  if (injectedToken.length > 0) {
    return injectedToken;
  }

  return nil;
}

+ (nullable NSString *)tokenFromLocalConfigForAppID:(NSString *)googleAppID
                                        environment:
                                            (NSDictionary<NSString *, NSString *> *)environment {
  if (googleAppID.length == 0) {
    return nil;
  }

  // Match the Firebase CLI's configstore location: `$XDG_CONFIG_HOME/configstore` when
  // `XDG_CONFIG_HOME` is set, otherwise `~/.config/configstore`.
  NSMutableArray<NSString *> *candidatePaths = [NSMutableArray array];
  NSString *xdgConfigHome = environment[kXDGConfigHomeEnvKey];
  if ([xdgConfigHome isKindOfClass:[NSString class]] && xdgConfigHome.length > 0) {
    [candidatePaths
        addObject:[xdgConfigHome stringByAppendingPathComponent:kLocalConfigRelativePath]];
  }
  NSString *hostHomeDirectory = [self hostHomeDirectoryWithEnvironment:environment];
  if (hostHomeDirectory.length > 0) {
    NSString *homeConfigPath = [[hostHomeDirectory stringByAppendingPathComponent:@".config"]
        stringByAppendingPathComponent:kLocalConfigRelativePath];
    if (![candidatePaths containsObject:homeConfigPath]) {
      [candidatePaths addObject:homeConfigPath];
    }
  }

  for (NSString *configPath in candidatePaths) {
    NSData *data = [NSData dataWithContentsOfFile:configPath];
    if (data.length == 0) {
      continue;
    }
    id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    if (![json isKindOfClass:[NSDictionary class]]) {
      continue;
    }
    id tokens = ((NSDictionary *)json)[@"tokens"];
    if (![tokens isKindOfClass:[NSDictionary class]]) {
      continue;
    }
    id token = ((NSDictionary *)tokens)[googleAppID];
    if ([token isKindOfClass:[NSString class]] && ((NSString *)token).length > 0) {
      return (NSString *)token;
    }
  }

  return nil;
}

/// Returns the developer machine's home directory: `SIMULATOR_HOST_HOME` on simulators, and the
/// user's actual home directory on macOS. `NSHomeDirectory()` is not used on macOS because it
/// returns the app's container directory in sandboxed apps.
+ (nullable NSString *)hostHomeDirectoryWithEnvironment:
    (NSDictionary<NSString *, NSString *> *)environment {
  NSString *simulatorHostHome = environment[kSimulatorHostHomeEnvKey];
  if ([simulatorHostHome isKindOfClass:[NSString class]] && simulatorHostHome.length > 0) {
    return simulatorHostHome;
  }
#if TARGET_OS_OSX
  struct passwd passwordEntry;
  struct passwd *result = NULL;
  char buffer[4096];
  if (getpwuid_r(getuid(), &passwordEntry, buffer, sizeof(buffer), &result) == 0 && result &&
      result->pw_dir) {
    return
        [[NSFileManager defaultManager] stringWithFileSystemRepresentation:result->pw_dir
                                                                    length:strlen(result->pw_dir)];
  }
  return NSHomeDirectory();
#else
  return nil;
#endif
}

+ (nullable NSString *)tokenFromInjectedClass:(nullable Class)injectedClass
                                     forAppID:(NSString *)googleAppID
                                       source:(NSString *_Nullable *_Nullable)outSource {
  if (!injectedClass) {
    return nil;
  }

  NSString *injectedToken = nil;
  if ([injectedClass respondsToSelector:@selector(tokens)]) {
    id tokensObj = [(Class<FIRAppCheckInjectedDebugTokenProtocol>)injectedClass tokens];
    if ([tokensObj isKindOfClass:[NSDictionary class]] && googleAppID.length > 0) {
      id candidate = ((NSDictionary *)tokensObj)[googleAppID];
      if ([candidate isKindOfClass:[NSString class]] && ((NSString *)candidate).length > 0) {
        injectedToken = (NSString *)candidate;
      }
    }
  }

  if (injectedToken.length == 0 && [injectedClass respondsToSelector:@selector(token)]) {
    id candidate = [(Class<FIRAppCheckInjectedDebugTokenProtocol>)injectedClass token];
    if ([candidate isKindOfClass:[NSString class]] && ((NSString *)candidate).length > 0) {
      injectedToken = (NSString *)candidate;
    }
  }

  if (injectedToken.length == 0) {
    return nil;
  }

  if (outSource) {
    *outSource = @"build-time injection (FIRAppCheckInjectedDebugToken)";
  }
  return injectedToken;
}

/// Returns `YES` if `error`, or one of its underlying errors, is an App Check HTTP 403 response.
/// Only the HTTP status code is checked: error descriptions contain the request URL (including the
/// project and app IDs) and the response body, so matching on their text is unreliable.
+ (BOOL)isHTTP403Error:(nullable NSError *)error {
  NSError *currentError = error;
  // Bound the walk in case the underlying error chain is cyclic.
  for (NSUInteger depth = 0; depth < 8 && [currentError isKindOfClass:[NSError class]]; depth++) {
    if ([currentError isKindOfClass:[GACAppCheckHTTPError class]]) {
      return ((GACAppCheckHTTPError *)currentError).httpResponse.statusCode == 403;
    }
    currentError = currentError.userInfo[NSUnderlyingErrorKey];
  }
  return NO;
}

#pragma mark - Private Helpers

- (nullable NSString *)debugTokenMessageWithPrefix:(NSString *)prefix {
  if (self.projectID.length == 0 || self.googleAppID.length == 0) {
    return nil;
  }

  if (self.resolvedDebugToken.length > 0) {
    // Never log a token that was provided externally: environment variables, in particular, often
    // hold CI secrets.
    return [NSString
        stringWithFormat:@"%@"
                          "Using the App Check debug token from %@. The token value is not "
                          "logged.\n\n"
                          "If this token is not registered with your project, register it in the "
                          "Firebase Console: \n"
                          "https://console.firebase.google.com/project/%@/appcheck/"
                          "apps?selectedAppId=%@ \n\n"
                          "Debug Token Guide: "
                          "https://firebase.google.com/docs/app-check/ios/debug-provider\n",
                         prefix, self.resolvedTokenSource ?: @"an external source", self.projectID,
                         self.googleAppID];
  }

  NSString *debugToken = self.localDebugToken;
  if (!debugToken) {
    return nil;
  }

  return [NSString
      stringWithFormat:
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
          self.googleAppID];
}

- (void)logDebugTokenMessageWithMessageCode:(NSString *)messageCode prefix:(NSString *)prefix {
  NSString *message = [self debugTokenMessageWithPrefix:prefix];
  if (message) {
    FIRLogWarning(kFIRLoggerAppCheck, messageCode, @"%@", message);
  }
}

- (void)logDebugTokenExchangeError:(NSError *)error {
  if ([[self class] isHTTP403Error:error]) {
    FIRAppCheckLogDebugTokenRejected(self.projectID, self.googleAppID);
  }
  [self logDebugTokenMessageWithMessageCode:kFIRLoggerAppCheckMessageCodeDebugTokenExchangeFailed
                                     prefix:@"Failed to exchange debug token. "];
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

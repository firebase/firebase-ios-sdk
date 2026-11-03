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
  NSString *resolvedToken = [[self class] resolveDebugTokenForAppID:app.options.googleAppID
                                                             source:&resolvedSource];

  GACAppCheckDebugProvider *debugProvider = nil;
  if (resolvedToken.length > 0) {
    @synchronized([FIRAppCheckDebugProvider class]) {
      const char *existingEnv = getenv(kAppCheckDebugTokenEnvKey.UTF8String);
      NSString *previousEnv = existingEnv ? @(existingEnv) : nil;
      setenv(kAppCheckDebugTokenEnvKey.UTF8String, resolvedToken.UTF8String, 1);
      debugProvider = [[GACAppCheckDebugProvider alloc]
          initWithServiceName:app.name
                 resourceName:app.resourceName
                      baseURL:nil
                       APIKey:app.options.APIKey
                 requestHooks:@[ [app.heartbeatLogger requestHook] ]];
      if (previousEnv != nil) {
        setenv(kAppCheckDebugTokenEnvKey.UTF8String, previousEnv.UTF8String, 1);
      } else {
        unsetenv(kAppCheckDebugTokenEnvKey.UTF8String);
      }
    }
  } else {
    NSString *storedToken =
        [[GULUserDefaults standardUserDefaults] stringForKey:kDebugTokenUserDefaultsKey];
    resolvedSource = storedToken.length > 0 ? @"NSUserDefaults" : @"auto-generated UUID";
    debugProvider = [[GACAppCheckDebugProvider alloc]
        initWithServiceName:app.name
               resourceName:app.resourceName
                    baseURL:nil
                     APIKey:app.options.APIKey
               requestHooks:@[ [app.heartbeatLogger requestHook] ]];
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

  // 4. Build-time injected class (FIRAppCheckInjectedDebugToken).
  Class injectedClass = [self injectedDebugTokenClass];
#if DEBUG
  BOOL isReleaseBuild = NO;
#else
  BOOL isReleaseBuild = YES;
#endif
  NSString *injectedToken = [self tokenFromInjectedClass:injectedClass
                                                forAppID:googleAppID
                                          isReleaseBuild:isReleaseBuild
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

  NSMutableArray<NSString *> *candidatePaths = [NSMutableArray array];
  NSString *simulatorHostHome = environment[kSimulatorHostHomeEnvKey];
  if ([simulatorHostHome isKindOfClass:[NSString class]] && simulatorHostHome.length > 0) {
    NSString *simConfigPath =
        [[simulatorHostHome stringByAppendingPathComponent:@".config/configstore"]
            stringByAppendingPathComponent:@"firebase-appcheck.json"];
    [candidatePaths addObject:simConfigPath];
  } else {
#if TARGET_OS_OSX && !TARGET_OS_SIMULATOR
    NSString *homeDir = NSHomeDirectory();
    if (homeDir.length > 0) {
      NSString *macConfigPath = [[homeDir stringByAppendingPathComponent:@".config/configstore"]
          stringByAppendingPathComponent:@"firebase-appcheck.json"];
      [candidatePaths addObject:macConfigPath];
    }
#endif
  }

  NSString *xdgConfigHome = environment[kXDGConfigHomeEnvKey];
  if ([xdgConfigHome isKindOfClass:[NSString class]] && xdgConfigHome.length > 0) {
    NSString *xdgConfigPath = [[xdgConfigHome stringByAppendingPathComponent:@"configstore"]
        stringByAppendingPathComponent:@"firebase-appcheck.json"];
    if (![candidatePaths containsObject:xdgConfigPath]) {
      [candidatePaths addObject:xdgConfigPath];
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

+ (nullable Class)injectedDebugTokenClass {
  Class injectedClass = NSClassFromString(kInjectedDebugTokenClassName);
  if (injectedClass) {
    return injectedClass;
  }

  NSString *moduleName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleExecutable"];
  if ([moduleName isKindOfClass:[NSString class]] && moduleName.length > 0) {
    NSString *sanitizedModule = [moduleName stringByReplacingOccurrencesOfString:@"-"
                                                                      withString:@"_"];
    sanitizedModule = [sanitizedModule stringByReplacingOccurrencesOfString:@" " withString:@"_"];
    NSString *qualifiedName =
        [NSString stringWithFormat:@"%@.%@", sanitizedModule, kInjectedDebugTokenClassName];
    injectedClass = NSClassFromString(qualifiedName);
  }
  return injectedClass;
}

+ (nullable NSString *)tokenFromInjectedClass:(nullable Class)injectedClass
                                     forAppID:(NSString *)googleAppID
                               isReleaseBuild:(BOOL)isReleaseBuild
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

  if (isReleaseBuild) {
    FIRLogError(kFIRLoggerAppCheck, kFIRLoggerAppCheckMessageCodeDebugTokenReleaseWarning,
                @"SECURITY WARNING: App Check debug token found in a Release build! Ignoring "
                @"token.");
    return nil;
  }

  if (outSource) {
    *outSource = @"build-time injection (FIRAppCheckInjectedDebugToken)";
  }
  return injectedToken;
}

+ (BOOL)isHTTP403Error:(nullable NSError *)error {
  if (!error) {
    return NO;
  }

  if ([error isKindOfClass:[GACAppCheckHTTPError class]]) {
    GACAppCheckHTTPError *httpError = (GACAppCheckHTTPError *)error;
    if (httpError.httpResponse.statusCode == 403) {
      return YES;
    }
  }

  if (error.code == 403) {
    return YES;
  }

  NSString *failureReason =
      error.localizedFailureReason ?: error.userInfo[NSLocalizedFailureReasonErrorKey];
  if ([failureReason isKindOfClass:[NSString class]] &&
      ([failureReason containsString:@"status code: 403"] ||
       [failureReason containsString:@"403"])) {
    return YES;
  }

  NSString *description = error.localizedDescription;
  if ([description isKindOfClass:[NSString class]] &&
      ([description containsString:@"status code: 403"] || [description containsString:@"403"])) {
    return YES;
  }

  NSError *underlyingError = error.userInfo[NSUnderlyingErrorKey];
  if ([underlyingError isKindOfClass:[NSError class]]) {
    return [self isHTTP403Error:underlyingError];
  }

  return NO;
}

#pragma mark - Private Helpers

- (void)logDebugTokenMessageWithMessageCode:(NSString *)messageCode prefix:(NSString *)prefix {
  if (self.projectID.length > 0 && self.googleAppID.length > 0) {
    NSString *debugToken = self.resolvedDebugToken ?: self.localDebugToken;
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
  if ([[self class] isHTTP403Error:error]) {
    FIRAppCheckLogDebugTokenRejected();
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

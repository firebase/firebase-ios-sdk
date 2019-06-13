/*
 * Copyright 2019 Google
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

#import "FIRInstallations.h"

#if __has_include(<FBLPromises/FBLPromises.h>)
#import <FBLPromises/FBLPromises.h>
#else
#import "FBLPromises.h"
#endif

#import <FirebaseCore/FIRAppInternal.h>
#import <FirebaseCore/FIRComponent.h>
#import <FirebaseCore/FIRComponentContainer.h>
#import <FirebaseCore/FIRLibrary.h>
#import <FirebaseCore/FIRLogger.h>
#import <FirebaseCore/FirebaseCore.h>

#import "FIRInstallationsAuthTokenResultInternal.h"

#import "FIRInstallationsIDController.h"
#import "FIRInstallationsItem.h"
#import "FIRInstallationsVersion.h"

@protocol FIRInstallationsInstanceProvider
@end

@interface FIRInstallations () <FIRLibrary>
@property(nonatomic, readonly) FIROptions *appOptions;
@property(nonatomic, readonly) NSString *appName;

@property(nonatomic, readonly) FIRInstallationsIDController *installationsIDController;

@end

@implementation FIRInstallations

#pragma mark - Firebase component

+ (void)load {
  [FIRApp registerInternalLibrary:(Class<FIRLibrary>)self
                         withName:@"fire-install"
                      withVersion:[NSString stringWithUTF8String:FIRInstallationsVersionStr]];
}

+ (nonnull NSArray<FIRComponent *> *)componentsToRegister {
  FIRComponentCreationBlock creationBlock =
      ^id _Nullable(FIRComponentContainer *container, BOOL *isCacheable) {
    *isCacheable = YES;
    FIRInstallations *installations = [[FIRInstallations alloc] initWithApp:container.app];
    return installations;
  };

  FIRComponent *installationsProvider =
      [FIRComponent componentWithProtocol:@protocol(FIRInstallationsInstanceProvider)
                      instantiationTiming:FIRInstantiationTimingAlwaysEager
                             dependencies:@[]
                            creationBlock:creationBlock];
  return @[ installationsProvider ];
}

- (void)appWillBeDeleted:(nonnull FIRApp *)app {
  // TODO: Handle
}

- (instancetype)initWithApp:(FIRApp *)app {
  return [self initWitAppOptions:app.options appName:app.name];
}

- (instancetype)initWitAppOptions:(FIROptions *)appOptions appName:(NSString *)appName {
  FIRInstallationsIDController *IDController =
      [[FIRInstallationsIDController alloc] initWithGoogleAppID:appOptions.googleAppID
                                                        appName:appName
                                                         APIKey:appOptions.APIKey
                                                      projectID:appOptions.projectID];
  return [self initWithAppOptions:appOptions
                          appName:appName
        installationsIDController:IDController];
}

/// The initializer is supposed to be used by tests to inject `installationsStore`.
- (instancetype)initWithAppOptions:(FIROptions *)appOptions
                           appName:(NSString *)appName
         installationsIDController:(FIRInstallationsIDController *)installationsIDController {
  self = [super init];
  if (self) {
    _appOptions = [appOptions copy];
    _appName = [appName copy];
    _installationsIDController = installationsIDController;
  }
  return self;
}

#pragma mark - Public

+ (FIRInstallations *)installationsWithApp:(FIRApp *)app {
  id<FIRInstallationsInstanceProvider> installations =
      FIR_COMPONENT(FIRInstallationsInstanceProvider, app.container);
  return (FIRInstallations *)installations;
}

- (void)installationIDWithCompletion:(FIRInstallationsIDHandler)completion {
  [self.installationsIDController getInstallationItem]
      .then(^id(FIRInstallationsItem *installation) {
        completion(installation.firebaseInstallationID, nil);
        return nil;
      })
      .catch(^(NSError *error) {
        // TODO: Make sure the error is in the public domain and wrap if needed.
        completion(nil, error);
      });
}

- (void)authTokenWithCompletion:(FIRInstallationsTokenHandler)completion {
  // TODO: Implement
  FIRInstallationsAuthTokenResult *result =
      [[FIRInstallationsAuthTokenResult alloc] initWithToken:@"token" expirationDate:[NSDate date]];
  completion(result, nil);
}

- (void)authTokenForcingRefresh:(BOOL)forceRefresh
                     completion:(FIRInstallationsTokenHandler)completion {
  // TODO: Implement
  FIRInstallationsAuthTokenResult *result =
      [[FIRInstallationsAuthTokenResult alloc] initWithToken:@"token" expirationDate:[NSDate date]];
  completion(result, nil);
}

- (void)deleteWithCompletion:(void (^)(NSError *__nullable))completion {
  // TODO: Implement
  completion(nil);
}

@end

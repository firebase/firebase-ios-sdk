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
#import <FirebaseCore/FIRAppInternal.h>
#import <FirebaseCore/FIRComponent.h>
#import <FirebaseCore/FIRComponentContainer.h>
#import <FirebaseCore/FIRLibrary.h>
#import <FirebaseCore/FIRLogger.h>
#import <FirebaseCore/FirebaseCore.h>

#import "FIRInstallationsVersion.h"

@protocol FIRInstallationsInstanceProvider
@end

@interface FIRInstallations () <FIRLibrary>
@property(nonatomic, readwrite, strong) NSString *appID;
@property(nonatomic, readwrite, strong) NSString *appName;
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
  return [self initWithGoogleAppID:app.options.googleAppID appName:app.name];
}

- (instancetype)initWithGoogleAppID:(NSString *)appID appName:(NSString *)appName {
  self = [super init];
  if (self) {
    _appID = appID;
    _appName = appName;
  }
  return self;
}

#pragma mark - Public

+ (FIRInstallations *)installationsWithApp:(FIRApp *)app {
  id<FIRInstallationsInstanceProvider> auth =
      FIR_COMPONENT(FIRInstallationsInstanceProvider, app.container);
  return (FIRInstallations *)auth;
}

- (void)installationIDWithCompletion:(FIRInstallationsIDHandler)completion {
  completion(@"123", nil);
}

- (void)authTokenWithCompletion:(FIRInstallationsTokenHandler)completion {
  FIRInstallationsAuthTokenResult *result =
      [[FIRInstallationsAuthTokenResult alloc] initWithToken:@"token" expirationTime:[NSDate date]];
  completion(result, nil);
}

- (void)authTokenForcingRefresh:(BOOL)forceRefresh
                     completion:(FIRInstallationsTokenHandler)completion {
  FIRInstallationsAuthTokenResult *result =
      [[FIRInstallationsAuthTokenResult alloc] initWithToken:@"token" expirationTime:[NSDate date]];
  completion(result, nil);
}

- (void)deleteWithCompletion:(void (^)(NSError *__nullable))completion {
  completion(nil);
}

#pragma mark -

@end

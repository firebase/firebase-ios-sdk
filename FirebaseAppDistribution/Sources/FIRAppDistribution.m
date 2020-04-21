// Copyright 2020 Google LLC
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

#import "FIRAppDistribution+Private.h"
#import "FIRAppDistributionAuthPersistence+Private.h"
#import "FIRAppDistributionMachO+Private.h"
#import "FIRAppDistributionRelease+Private.h"

#import "FIRAppDistributionAuthPersistence+Private.h"
#import "FIRAppDistributionMachO+Private.h"
#import "FIRAppDistributionRelease+Private.h"

#import <FirebaseCore/FIRAppInternal.h>
#import <FirebaseCore/FIRComponent.h>
#import <FirebaseCore/FIRComponentContainer.h>
#import <FirebaseCore/FIROptions.h>

#import <GoogleUtilities/GULAppDelegateSwizzler.h>
#import "FIRAppDistributionAppDelegateInterceptor.h"

/// Empty protocol to register with FirebaseCore's component system.
@protocol FIRAppDistributionInstanceProvider <NSObject>
@end

@interface FIRAppDistribution () <FIRLibrary, FIRAppDistributionInstanceProvider>
@property(nonatomic) BOOL isTesterSignedIn;
@end

@implementation FIRAppDistribution

// The OAuth scope needed to authorize the App Distribution Tester API
NSString *const kOIDScopeTesterAPI = @"https://www.googleapis.com/auth/cloud-platform";

// The App Distribution Tester API endpoint used to retrieve releases
NSString *const kReleasesEndpointURL =
    @"https://firebaseapptesters.googleapis.com/v1alpha/devices/-/testerApps/%@/releases";
NSString *const kTesterAPIClientID =
    @"319754533822-osu3v3hcci24umq6diathdm0dipds1fb.apps.googleusercontent.com";
NSString *const kIssuerURL = @"https://accounts.google.com";
NSString *const kAppDistroLibraryName = @"fire-fad";

#pragma mark - Singleton Support

- (instancetype)initWithApp:(FIRApp *)app appInfo:(NSDictionary *)appInfo {
  self = [super init];

  if (self) {
    self.safariHostingViewController = [[UIViewController alloc] init];

    [GULAppDelegateSwizzler proxyOriginalDelegate];

    FIRAppDistributionAppDelegatorInterceptor *interceptor =
        [FIRAppDistributionAppDelegatorInterceptor sharedInstance];
    [GULAppDelegateSwizzler registerAppDelegateInterceptor:interceptor];
  }

  NSError *authRetrievalError;
  self.authState = [FIRAppDistributionAuthPersistence retrieveAuthState:&authRetrievalError];
  // TODO (schnecle): replace NSLog statement with FIRLogger log statement
  if (authRetrievalError) {
    NSLog(@"Error retrieving token from keychain: %@", [authRetrievalError localizedDescription]);
  }

  self.isTesterSignedIn = self.authState ? YES : NO;

  NSLog(@"Tester %@ already logged in", self.isTesterSignedIn ? @"is" : @"is not");
  return self;
}

+ (void)load {
  NSString *version =
      [NSString stringWithUTF8String:(const char *const)STR_EXPAND(FIRAppDistribution_VERSION)];
  [FIRApp registerInternalLibrary:(Class<FIRLibrary>)self
                         withName:kAppDistroLibraryName
                      withVersion:version];
}

+ (NSArray<FIRComponent *> *)componentsToRegister {
  FIRComponentCreationBlock creationBlock =
      ^id _Nullable(FIRComponentContainer *container, BOOL *isCacheable) {
    if (!container.app.isDefaultApp) {
      // TODO: Implement error handling
      @throw([NSException exceptionWithName:@"NotImplementedException"
                                     reason:@"This code path is not implemented yet"
                                   userInfo:nil]);
      return nil;
    }

    *isCacheable = YES;

    return [[FIRAppDistribution alloc] initWithApp:container.app
                                           appInfo:NSBundle.mainBundle.infoDictionary];
  };

  FIRComponent *component =
      [FIRComponent componentWithProtocol:@protocol(FIRAppDistributionInstanceProvider)
                      instantiationTiming:FIRInstantiationTimingEagerInDefaultApp
                             dependencies:@[]
                            creationBlock:creationBlock];
  return @[ component ];
}

+ (instancetype)appDistribution {
  // The container will return the same instance since isCacheable is set

  FIRApp *defaultApp = [FIRApp defaultApp];  // Missing configure will be logged here.

  // Get the instance from the `FIRApp`'s container. This will create a new instance the
  // first time it is called, and since `isCacheable` is set in the component creation
  // block, it will return the existing instance on subsequent calls.
  id<FIRAppDistributionInstanceProvider> instance =
      FIR_COMPONENT(FIRAppDistributionInstanceProvider, defaultApp.container);

  // In the component creation block, we return an instance of `FIRAppDistribution`. Cast it and
  // return it.
  return (FIRAppDistribution *)instance;
}

- (void)signInTesterWithCompletion:(void (^)(NSError *_Nullable error))completion {
  NSURL *issuer = [NSURL URLWithString:kIssuerURL];

  [OIDAuthorizationService
      discoverServiceConfigurationForIssuer:issuer
                                 completion:^(OIDServiceConfiguration *_Nullable configuration,
                                              NSError *_Nullable error) {
                                   [self handleOauthDiscoveryCompletion:configuration
                                                                  error:error
                                        appDistributionSignInCompletion:completion];
                                 }];
}

- (void)signOutTester {
  NSError *error;
  BOOL didClearAuthState = [FIRAppDistributionAuthPersistence clearAuthState:&error];
  // TODO (schnecle): Add in FIRLogger to report when we have failed to clear auth state
  if (!didClearAuthState) {
    NSLog(@"Error clearing token from keychain: %@", [error localizedDescription]);
  }

  self.authState = nil;
  self.isTesterSignedIn = false;
}

- (void)fetchReleases:(FIRAppDistributionUpdateCheckCompletion)completion {
  [self.authState performActionWithFreshTokens:^(NSString *_Nonnull accessToken,
                                                 NSString *_Nonnull idToken,
                                                 NSError *_Nullable error) {
    if (error) {
      // TODO (schnecle): Add in FIRLogger log statement
      NSLog(@"Error fetching fresh tokens: %@", [error localizedDescription]);
      [self signOutTester];
      return;
    }

    // perform your API request using the tokens
    NSURLSession *URLSession = [NSURLSession sharedSession];
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    NSString *URLString =
        [NSString stringWithFormat:kReleasesEndpointURL, [[FIRApp defaultApp] options].googleAppID];
    [request setURL:[NSURL URLWithString:URLString]];
    [request setHTTPMethod:@"GET"];
    [request setValue:[NSString stringWithFormat:@"Bearer %@", accessToken]
        forHTTPHeaderField:@"Authorization"];

    NSURLSessionDataTask *listReleasesDataTask = [URLSession
        dataTaskWithRequest:request
          completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            if (error) {
              // TODO: Reformat error into error code
              completion(nil, error);
              return;
            }

            NSHTTPURLResponse *HTTPResponse = (NSHTTPURLResponse *)response;

            if (HTTPResponse.statusCode == 200) {
              [self handleReleasesAPIResponseWithData:data completion:completion];
            } else {
              // TODO: Handle non-200 http response
              NSLog(@"ERROR - Non 200 service response - %@", HTTPResponse);
              @throw([NSException exceptionWithName:@"NotImplementedException"
                                             reason:@"This code path is not implemented yet"
                                           userInfo:nil]);
            }
          }];

    [listReleasesDataTask resume];
  }];
}

- (void)handleOauthDiscoveryCompletion:(OIDServiceConfiguration *_Nullable)configuration
                                 error:(NSError *_Nullable)error
       appDistributionSignInCompletion:(void (^)(NSError *_Nullable error))completion {
  if (!configuration) {
    // TODO: Handle when we cannot get configuration
    NSLog(@"ERROR - Cannot discover oauth config");
    @throw([NSException exceptionWithName:@"NotImplementedException"
                                   reason:@"This code path is not implemented yet"
                                 userInfo:nil]);
    return;
  }

  NSString *redirectURL = [@"dev.firebase.appdistribution."
      stringByAppendingString:[[[NSBundle mainBundle] bundleIdentifier]
                                  stringByAppendingString:@":/launch"]];

  OIDAuthorizationRequest *request = [[OIDAuthorizationRequest alloc]
      initWithConfiguration:configuration
                   clientId:kTesterAPIClientID
                     scopes:@[ OIDScopeOpenID, OIDScopeProfile, kOIDScopeTesterAPI ]
                redirectURL:[NSURL URLWithString:redirectURL]
               responseType:OIDResponseTypeCode
       additionalParameters:nil];

  [self createUIWindowForLogin];
  // performs authentication request
  [FIRAppDistributionAppDelegatorInterceptor sharedInstance].currentAuthorizationFlow =
      [OIDAuthState
          authStateByPresentingAuthorizationRequest:request
                           presentingViewController:self.safariHostingViewController
                                           callback:^(OIDAuthState *_Nullable authState,
                                                      NSError *_Nullable error) {
                                             self.authState = authState;

                                             // Capture errors in persistence but do not bubble them
                                             // up
                                             NSError *authPersistenceError;
                                             if (authState) {
                                               [FIRAppDistributionAuthPersistence
                                                   persistAuthState:authState
                                                              error:&authPersistenceError];
                                             }

                                             // TODO (schnecle): Log errors in persistence using
                                             // FIRLogger
                                             if (authPersistenceError) {
                                               NSLog(@"Error persisting token to keychain: %@",
                                                     [error localizedDescription]);
                                             }
                                             self.isTesterSignedIn = self.authState ? YES : NO;
                                             completion(error);
                                           }];

- (UIWindow *)createUIWindowForLogin {
  // Create an empty window + viewController to host the Safari UI.
  UIWindow *window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
  window.rootViewController = self.safariHostingViewController;

  // Place it at the highest level within the stack.
  window.windowLevel = +CGFLOAT_MAX;

  // Run it.
  [window makeKeyAndVisible];

  return window;
}

- (void)handleReleasesAPIResponseWithData:data
                               completion:(FIRAppDistributionUpdateCheckCompletion)completion {
  NSError *error = nil;
  NSDictionary *object = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];

  NSArray *releaseList = [object objectForKey:@"releases"];
  for (NSDictionary *releaseDict in releaseList) {
    if (![[releaseDict objectForKey:@"latest"] boolValue]) continue;

    NSString *codeHash = [releaseDict objectForKey:@"codeHash"];
    FIRAppDistributionMachO *machO =
        [[FIRAppDistributionMachO alloc] initWithPath:[[NSBundle mainBundle] executablePath]];

    if (![codeHash isEqualToString:machO.codeHash]) {
      FIRAppDistributionRelease *release =
          [[FIRAppDistributionRelease alloc] initWithDictionary:releaseDict];
      dispatch_async(dispatch_get_main_queue(), ^{
        completion(release, nil);
      });
    }
  }
}
- (void)checkForUpdateWithCompletion:(FIRAppDistributionUpdateCheckCompletion)completion {
  if (self.isTesterSignedIn) {
    [self fetchReleases:completion];
  } else {
    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:@"Enable in-app alerts"
                         message:@"Sign in with your Firebase App Distribution Google account to "
                                 @"turn on in-app alerts for new test releases."
                  preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction *yesButton =
        [UIAlertAction actionWithTitle:@"Turn on"
                                 style:UIAlertActionStyleDefault
                               handler:^(UIAlertAction *action) {
                                 [self signInTesterWithCompletion:^(NSError *_Nullable error) {
                                   self.window.hidden = YES;
                                   self.window = nil;

                                   if (error) {
                                     completion(nil, error);
                                     return;
                                   }

                                   [self fetchReleases:completion];
                                 }];
                               }];

    UIAlertAction *noButton = [UIAlertAction actionWithTitle:@"Not now"
                                                       style:UIAlertActionStyleDefault
                                                     handler:^(UIAlertAction *action) {
                                                       // precaution to ensure window gets destroyed
                                                       self.window.hidden = YES;
                                                       self.window = nil;
                                                       completion(nil, nil);
                                                     }];

    [alert addAction:noButton];
    [alert addAction:yesButton];

    // Create an empty window + viewController to host the Safari UI.
    self.window = [self createUIWindowForLogin];
    [self.window.rootViewController presentViewController:alert animated:YES completion:nil];
  }
}
@end

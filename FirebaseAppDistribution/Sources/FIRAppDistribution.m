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

#import "FIRAppDistribution.h"
#import "FIRAppDistribution+Private.h"
#import "FIRAppDistributionAppDelegateInterceptor.h"

#import <FirebaseCore/FIRAppInternal.h>
#import <FirebaseCore/FIRComponent.h>
#import <FirebaseCore/FIRComponentContainer.h>
#import <FirebaseCore/FIROptions.h>

#import <AppAuth/AppAuth.h>
#import <GoogleUtilities/GULAppDelegateSwizzler.h>
#import <UIKit/UIKit.h>
#import "FIRAppDistributionAppDelegateInterceptor.h"

/// Empty protocol to register with FirebaseCore's component system.
@protocol FIRAppDistributionInstanceProvider <NSObject>
@end

@interface FIRAppDistributionAuthImp: NSObject<FIRAppDistributionAuthProtocol>
@end

@implementation FIRAppDistributionAuthImp

- (void)discoverService:(NSURL *)issuerURL completion:(OIDDiscoveryCallback)completion {
    [OIDAuthorizationService discoverServiceConfigurationForIssuer:issuerURL completion:completion];
}

@end


@interface FIRAppDistribution () <FIRLibrary, FIRAppDistributionInstanceProvider>
  @property (nonatomic, strong) id<FIRAppDistributionAuthProtocol> appDistributionAuth;
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

// explicit @synthesize is needed since the property is readonly
@synthesize isTesterSignedIn = _isTesterSignedIn;

#pragma mark - Singleton Support

- (instancetype)initWithApp:(FIRApp *)app appInfo:(NSDictionary *)appInfo {
  return [self initWithApp:app appInfo:appInfo authHandler:[[FIRAppDistributionAuthImp alloc] init]];
}

- (instancetype)initWithApp:(FIRApp *)app appInfo:(NSDictionary *)appInfo authHandler:(id<FIRAppDistributionAuthProtocol>) auth {
  self = [super init];

  if (self) {
    _appDistributionAuth = auth;
    _safariHostingViewController = [[UIViewController alloc] init];

    [GULAppDelegateSwizzler proxyOriginalDelegate];

    FIRAppDistributionAppDelegatorInterceptor *interceptor =
        [FIRAppDistributionAppDelegatorInterceptor sharedInstance];
    [GULAppDelegateSwizzler registerAppDelegateInterceptor:interceptor];
  }

  // TODO: Lookup keychain to load auth state on init
  _isTesterSignedIn = _authState ? YES : NO;
  return self;
}

+ (void)load {
  NSString *version =
      [NSString stringWithUTF8String:(const char *const)STR_EXPAND(FIRAppDistribution_VERSION)];
  [FIRApp registerInternalLibrary:(Class<FIRLibrary>)self
                         withName:@"firebase-appdistribution"
                      withVersion:version];
}

+ (NSArray<FIRComponent *> *)componentsToRegister {
  FIRComponentCreationBlock creationBlock =
      ^id _Nullable(FIRComponentContainer *container, BOOL *isCacheable) {
    if (!container.app.isDefaultApp) {
      NSLog(@"App Distribution must be used with the default Firebase app.");
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

- (void)signInTesterWithCompletion:(FIRAppDistributionSignInTesterCompletion)completion {
  NSURL *issuer = [NSURL URLWithString:kIssuerURL];

  [self.appDistributionAuth discoverService:issuer
                                 completion:^(OIDServiceConfiguration *_Nullable configuration,
                                              NSError *_Nullable error) {
                                   [self handleOauthDiscoveryCompletion:configuration
                                                                  error:error
                                        appDistributionSignInCompletion:completion];
                                 }];
}

- (void)signOutTester {
  self.authState = nil;
  _isTesterSignedIn = false;
}

- (void)fetchReleases:(FIRAppDistributionUpdateCheckCompletion)completion {
  NSURLSession *URLSession = [NSURLSession sharedSession];
  NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
  NSString *URLString =
      [NSString stringWithFormat:kReleasesEndpointURL, [[FIRApp defaultApp] options].googleAppID];
  [request setURL:[NSURL URLWithString:URLString]];
  [request setHTTPMethod:@"GET"];
  [request setValue:[NSString
                        stringWithFormat:@"Bearer %@", self.authState.lastTokenResponse.accessToken]
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
            @throw([NSException exceptionWithName:@"NotImplementedException"
                                           reason:@"This code path is not implemented yet"
                                         userInfo:nil]);
          }
        }];

  [listReleasesDataTask resume];
}

// OIDServiceConfiguration *_Nullable configuration,
// NSError *_Nullable error
- (void)handleOauthDiscoveryCompletion:(OIDServiceConfiguration *_Nullable)configuration
                                 error:(NSError *_Nullable)error
       appDistributionSignInCompletion:(FIRAppDistributionSignInTesterCompletion)completion {
  if (!configuration) {
    NSLog(@"Error retrieving discovery document: %@", [error localizedDescription]);
    return;
  }

  NSString *redirectUrl = [@"dev.firebase.appdistribution."
      stringByAppendingString:[[[NSBundle mainBundle] bundleIdentifier]
                                  stringByAppendingPathComponent:@":xlaunch"]];

  OIDAuthorizationRequest *request = [[OIDAuthorizationRequest alloc]
      initWithConfiguration:configuration
                   clientId:kTesterAPIClientID
                     scopes:@[ OIDScopeOpenID, OIDScopeProfile, kOIDScopeTesterAPI ]
                redirectURL:[NSURL URLWithString:redirectUrl]
               responseType:OIDResponseTypeCode
       additionalParameters:nil];

  [self createUIWindowForLogin];
  // performs authentication request
  [FIRAppDistributionAppDelegatorInterceptor sharedInstance].currentAuthorizationFlow =
      [OIDAuthState authStateByPresentingAuthorizationRequest:request
                                     presentingViewController:self.safariHostingViewController
                                                     callback:^(OIDAuthState *_Nullable authState,
                                                                NSError *_Nullable error) {
                                                       self.authState = authState;
                                                       self->_isTesterSignedIn =
                                                           self.authState ? YES : NO;
                                                       completion(error);
                                                     }];
}

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
  // TODO Implement parsing of releases API response
  @throw([NSException exceptionWithName:@"NotImplementedException"
                                 reason:@"This code path is not implemented yet"
                               userInfo:nil]);
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

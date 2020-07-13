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

#import <FirebaseCore/FIRAppInternal.h>
#import <FirebaseCore/FIRComponent.h>
#import <FirebaseCore/FIRComponentContainer.h>
#import <FirebaseCore/FIROptions.h>
#import <FirebaseInstallations/FirebaseInstallations.h>
#import <GoogleUtilities/GULAppDelegateSwizzler.h>

#import "FIRAppDistribution+Private.h"
#import "FIRAppDistributionMachO+Private.h"
#import "FIRAppDistributionRelease+Private.h"
#import "FIRFADLogger.h"
#import "FIRAppDistributionAppDelegateInterceptor.h"

/// Empty protocol to register with FirebaseCore's component system.
@protocol FIRAppDistributionInstanceProvider <NSObject>
@end

@interface FIRAppDistribution () <FIRLibrary,
                                  FIRAppDistributionInstanceProvider>
@property(nonatomic) BOOL isTesterSignedIn;
@end

NSString *const FIRAppDistributionErrorDomain = @"com.firebase.appdistribution";
NSString *const FIRAppDistributionErrorDetailsKey = @"details";

@implementation FIRAppDistribution

// The OAuth scope needed to authorize the App Distribution Tester API
NSString *const kOIDScopeTesterAPI = @"https://www.googleapis.com/auth/cloud-platform";

// The App Distribution Tester API endpoint used to retrieve releases
NSString *const kReleasesEndpointURL = @"https://firebaseapptesters.googleapis.com/v1alpha/devices/"
                                       @"-/testerApps/%@/installations/%@/releases";
NSString *const kTesterAPIClientID =
    @"319754533822-osu3v3hcci24umq6diathdm0dipds1fb.apps.googleusercontent.com";
NSString *const kIssuerURL = @"https://accounts.google.com";
NSString *const kAppDistroLibraryName = @"fire-fad";

NSString *const kReleasesKey = @"releases";
NSString *const kLatestReleaseKey = @"latest";
NSString *const kCodeHashKey = @"codeHash";

NSString *const kAuthErrorMessage = @"Unable to authenticate the tester";
NSString *const kAuthCancelledErrorMessage = @"Tester cancelled sign-in";

@synthesize isTesterSignedIn = _isTesterSignedIn;

- (BOOL)isTesterSignedIn {
  //  FIRFADInfoLog(@"Checking if tester is signed in");
  //  return [self tryInitializeAuthState];
  return NO;
}

#pragma mark - Singleton Support

- (instancetype)initWithApp:(FIRApp *)app appInfo:(NSDictionary *)appInfo {
  // FIRFADInfoLog(@"Initializing Firebase App Distribution");
  self = [super init];

  if (self) {
    [GULAppDelegateSwizzler proxyOriginalDelegate];

    FIRAppDistributionAppDelegatorInterceptor *interceptor =
        [FIRAppDistributionAppDelegatorInterceptor sharedInstance];
    [GULAppDelegateSwizzler registerAppDelegateInterceptor:interceptor];
  }

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
      // TODO: Remove this and log error
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
  NSLog(@"Instance returned! %@", instance);
  return (FIRAppDistribution *)instance;
}

- (void)signInTesterWithCompletion:(void (^)(NSError *_Nullable error))completion {
  NSLog(@"Testing: App Distribution sign in");

  // TODO: Check if tester is already signed in

  [self setupUIWindowForLogin];
  FIRInstallations *installations = [FIRInstallations installations];

  // Get a Firebase Installation ID (FID).
  [installations installationIDWithCompletion:^(NSString *__nullable identifier,
                                                NSError *__nullable error) {
    if (error) {
      completion(error);
      return;
    }

    NSString *requestURL = [NSString
        stringWithFormat:@"https://partnerdash.google.com/apps/appdistribution/pub/apps/%@/"
                         @"installations/%@/buildalerts?appName=%@",
                         [[FIRApp defaultApp] options].googleAppID, identifier, [self getAppName]];

    NSLog(@"Registration URL: %@", requestURL);

    SFSafariViewController *safariVC = [[SFSafariViewController alloc] initWithURL:[NSURL URLWithString:requestURL]];

    safariVC.delegate = self;
    _safariVC = safariVC;
    [self->_safariHostingViewController presentViewController:safariVC
                                                     animated:YES
                                                   completion:nil];
    
//    if (@available(iOS 12.0, *)) {
//      ASWebAuthenticationSession *authenticationVC = [[ASWebAuthenticationSession alloc]
//                initWithURL:[[NSURL alloc] initWithString:requestURL]
//          callbackURLScheme:@"com.firebase.appdistribution"
//          completionHandler:^(NSURL *_Nullable callbackURL, NSError *_Nullable error) {
//            [self cleanupUIWindow];
//            NSLog(@"Testing: Sign in Complete!");
//            if (callbackURL) {
//              self.isTesterSignedIn = true;
//              completion(nil);
//            } else {
//              self.isTesterSignedIn = false;
//              completion(error);
//            }
//          }];
//
//      if (@available(iOS 13.0, *)) {
//        authenticationVC.presentationContextProvider = self;
//      }
//
//      _webAuthenticationVC = authenticationVC;
//
//      [authenticationVC start];
//    } else if (@available(iOS 11.0, *)) {
//      _safariAuthenticationVC = [[SFAuthenticationSession alloc]
//                initWithURL:[[NSURL alloc] initWithString:requestURL]
//          callbackURLScheme:@"com.firebase.appdistribution"
//          completionHandler:^(NSURL *_Nullable callbackURL, NSError *_Nullable error) {
//            [self cleanupUIWindow];
//            NSLog(@"Testing: Sign in Complete!");
//            if (callbackURL) {
//              self.isTesterSignedIn = true;
//              completion(nil);
//            } else {
//              self.isTesterSignedIn = false;
//              completion(error);
//            }
//          }];
//
//      [_safariAuthenticationVC start];
//    } else {
//      SFSafariViewController *safariVC = [[SFSafariViewController alloc] initWithURL:[NSURL URLWithString:requestURL]]];
//
//      safariVC.delegate = self;
//      _safariVC = safariVC;
//      [self->_safariHostingViewController presentViewController:safariVC
//                                                       animated:YES
//                                                     completion:nil];
//    }
  }];
}

- (NSString *)getAppName {
  NSBundle *mainBundle = [NSBundle mainBundle];

  NSString *name = [mainBundle objectForInfoDictionaryKey:@"CFBundleName"];

  if (name)
    return [name stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLHostAllowedCharacterSet]];

  name = [mainBundle objectForInfoDictionaryKey:@"CFBundleDisplayName"];

  return [name stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLHostAllowedCharacterSet]];
}

- (void)signOutTester {
  // FIRFADInfoLog(@"Tester sign out");
  //  NSError *error;
  //  BOOL didClearAuthState = [self.authPersistence clearAuthState:&error];
  //  if (!didClearAuthState) {
  //    FIRFADErrorLog(@"Error clearing token from keychain: %@", [error localizedDescription]);
  //    [self logUnderlyingKeychainError:error];
  //
  //  } else {
  //    FIRFADInfoLog(@"Successfully cleared auth state from keychain");
  //  }

  self.isTesterSignedIn = false;
}

- (NSError *)NSErrorForErrorCodeAndMessage:(FIRAppDistributionError)errorCode
                                   message:(NSString *)message {
  NSDictionary *userInfo = @{FIRAppDistributionErrorDetailsKey : message};
  return [NSError errorWithDomain:FIRAppDistributionErrorDomain code:errorCode userInfo:userInfo];
}

- (void)fetchReleases:(FIRAppDistributionUpdateCheckCompletion)completion {
  // OR for default FIRApp:
  FIRInstallations *installations = [FIRInstallations installations];

  // Get a FIS Authentication Token.

  [installations authTokenWithCompletion:^(
                     FIRInstallationsAuthTokenResult *_Nullable authTokenResult,
                     NSError *_Nullable error) {
    if (error) {
      //      FIRFADErrorLog(@"Error getting fresh auth tokens. Will sign out tester. Error: %@",
      //                     [error localizedDescription]);
      // TODO: Do we need a less aggresive strategy here? maybe a retry?
      [self signOutTester];
      NSError *HTTPError =
          [self NSErrorForErrorCodeAndMessage:FIRAppDistributionErrorAuthenticationFailure
                                      message:kAuthErrorMessage];

      dispatch_async(dispatch_get_main_queue(), ^{
        completion(nil, HTTPError);
      });

      return;
    }

    [installations installationIDWithCompletion:^(NSString *__nullable identifier,
                                                  NSError *__nullable error) {
      // perform your API request using the tokens
      NSURLSession *URLSession = [NSURLSession sharedSession];
      NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
      NSString *URLString =
          [NSString stringWithFormat:kReleasesEndpointURL,
                                     [[FIRApp defaultApp] options].googleAppID, identifier];

      // FIRFADInfoLog(@"Requesting releases for app id - %@",
      //                  [[FIRApp defaultApp] options].googleAppID);
      [request setURL:[NSURL URLWithString:URLString]];
      [request setHTTPMethod:@"GET"];
      [request setValue:authTokenResult.authToken
          forHTTPHeaderField:@"X-Goog-Firebase-Installations-Auth"];

      [request setValue:[[FIRApp defaultApp] options].APIKey forHTTPHeaderField:@"X-Goog-Api-Key"];

      NSLog(@"Url : %@, Auth token: %@ API KEY: %@", URLString, authTokenResult.authToken,
            [[FIRApp defaultApp] options].APIKey);
      NSURLSessionDataTask *listReleasesDataTask = [URLSession
          dataTaskWithRequest:request
            completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
              NSHTTPURLResponse *HTTPResponse = (NSHTTPURLResponse *)response;
              NSLog(@"HTTPResonse status code %ld response %@", (long)HTTPResponse.statusCode,
                    HTTPResponse);
              if (error || HTTPResponse.statusCode != 200) {
                NSError *HTTPError = nil;
                if (HTTPResponse == nil && error) {
                  // Handles network timeouts or no internet connectivity
                  NSString *message = error.userInfo[NSLocalizedDescriptionKey]
                                          ? error.userInfo[NSLocalizedDescriptionKey]
                                          : @"";

                  HTTPError =
                      [self NSErrorForErrorCodeAndMessage:FIRAppDistributionErrorNetworkFailure
                                                  message:message];
                } else if (HTTPResponse.statusCode == 401) {
                  // TODO: Maybe sign out tester?
                  HTTPError = [self
                      NSErrorForErrorCodeAndMessage:FIRAppDistributionErrorAuthenticationFailure
                                            message:kAuthErrorMessage];
                } else {
                  HTTPError = [self NSErrorForErrorCodeAndMessage:FIRAppDistributionErrorUnknown
                                                          message:@""];
                }

                //              FIRFADErrorLog(@"App Tester API service error - %@",
                //                             [HTTPError localizedDescription]);
                dispatch_async(dispatch_get_main_queue(), ^{
                  completion(nil, HTTPError);
                });

              } else {
                [self handleReleasesAPIResponseWithData:data completion:completion];
              }
            }];

      [listReleasesDataTask resume];
    }];
  }];
}

- (ASPresentationAnchor)presentationAnchorForWebAuthenticationSession:
    (ASWebAuthenticationSession *)session API_AVAILABLE(ios(13.0)) {
  return self.safariHostingViewController.view.window;
}

- (void)setupUIWindowForLogin {
  if (self.window) {
    return;
  }
  // Create an empty window + viewController to host the Safari UI.
  self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
  self.window.rootViewController = self.safariHostingViewController;

  // Place it at the highest level within the stack.
  self.window.windowLevel = +CGFLOAT_MAX;

  // Run it.
  [self.window makeKeyAndVisible];
}

- (void)cleanupUIWindow {
  if (self.window) {
    self.window.hidden = YES;
    self.window = nil;
  }

  _safariAuthenticationVC = nil;
  _safariVC = nil;
  _webAuthenticationVC = nil;
}

//- (void)logUnderlyingKeychainError:(NSError *)error {
//  NSError *underlyingError = [error.userInfo objectForKey:NSUnderlyingErrorKey];
//  if (underlyingError) {
//    FIRFADErrorLog(@"Keychain error - %@", [underlyingError localizedDescription]);
//  }
//}

- (void)handleReleasesAPIResponseWithData:data
                               completion:(FIRAppDistributionUpdateCheckCompletion)completion {
  NSError *error = nil;

  NSDictionary *serializedResponse = [NSJSONSerialization JSONObjectWithData:data
                                                                     options:0
                                                                       error:&error];

  if (error) {
    //    FIRFADErrorLog(@"Tester API - Error serializing json response");
    NSString *message =
        error.userInfo[NSLocalizedDescriptionKey] ? error.userInfo[NSLocalizedDescriptionKey] : @"";
    NSError *error = [self NSErrorForErrorCodeAndMessage:FIRAppDistributionErrorUnknown
                                                 message:message];
    dispatch_async(dispatch_get_main_queue(), ^{
      completion(nil, error);
    });

    return;
  }

  NSArray *releaseList = [serializedResponse objectForKey:kReleasesKey];
  for (NSDictionary *releaseDict in releaseList) {
    if ([[releaseDict objectForKey:kLatestReleaseKey] boolValue]) {
      //      FIRFADInfoLog(@"Tester API - found latest release in response. Checking if code hash
      //      match");
      NSString *codeHash = [releaseDict objectForKey:kCodeHashKey];
      NSString *executablePath = [[NSBundle mainBundle] executablePath];
      FIRAppDistributionMachO *machO =
          [[FIRAppDistributionMachO alloc] initWithPath:executablePath];

      //      FIRFADInfoLog(@"Code hash for the app on device - %@", machO.codeHash);
      //      FIRFADInfoLog(@"Code hash for the release from the service response - %@", codeHash);
      if (codeHash && ![codeHash isEqualToString:machO.codeHash]) {
        FIRAppDistributionRelease *release =
            [[FIRAppDistributionRelease alloc] initWithDictionary:releaseDict];
        dispatch_async(dispatch_get_main_queue(), ^{
          // FIRFADInfoLog(@"Found new release");
          completion(release, nil);
        });

        return;
      }

      break;
    }
  }

  // FIRFADInfoLog(@"Tester API - No new release found");
  dispatch_async(dispatch_get_main_queue(), ^{
    completion(nil, nil);
  });
}

- (void)checkForUpdateWithCompletion:(FIRAppDistributionUpdateCheckCompletion)completion {
  NSLog(@"CheckForUpdateWithCompletion");
  if (false) {
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
                                                       [self cleanupUIWindow];
                                                       completion(nil, nil);
                                                     }];

    [alert addAction:noButton];
    [alert addAction:yesButton];

    // Create an empty window + viewController to host the Safari UI.
    [self setupUIWindowForLogin];
    [self.window.rootViewController presentViewController:alert animated:YES completion:nil];
  }
}

- (void)safariViewControllerDidFinish:(SFSafariViewController *)controller NS_AVAILABLE_IOS(9.0) {
  [self cleanupUIWindow];
}
@end

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
#import <Foundation/Foundation.h>

#import "FirebaseCore/Sources/Private/FirebaseCoreInternal.h"
#import "FirebaseInstallations/Source/Library/Private/FirebaseInstallationsInternal.h"
#import "GoogleUtilities/AppDelegateSwizzler/Private/GULAppDelegateSwizzler.h"
#import "GoogleUtilities/UserDefaults/Private/GULUserDefaults.h"

#import "FirebaseAppDistribution/Sources/FIRAppDistributionUIService.h"
#import "FirebaseAppDistribution/Sources/FIRAppDistributionMachO.h"
#import "FirebaseAppDistribution/Sources/FIRFADApiService.h"
#import "FirebaseAppDistribution/Sources/FIRFADLogger.h"
#import "FirebaseAppDistribution/Sources/Private/FIRAppDistribution.h"
#import "FirebaseAppDistribution/Sources/Private/FIRAppDistributionRelease.h"

/// Empty protocol to register with FirebaseCore's component system.
@protocol FIRAppDistributionInstanceProvider <NSObject>
@end

@interface FIRAppDistribution () <FIRLibrary, FIRAppDistributionInstanceProvider>
@property(nonatomic) BOOL isTesterSignedIn;

@property(nullable, nonatomic) FIRAppDistributionUIService *UIService;

@end

NSString *const FIRAppDistributionErrorDomain = @"com.firebase.appdistribution";
NSString *const FIRAppDistributionErrorDetailsKey = @"details";

@implementation FIRAppDistribution

// The App Distribution Tester API endpoint used to retrieve releases
NSString *const kReleasesEndpointURL = @"https://firebaseapptesters.googleapis.com/v1alpha/devices/"
                                       @"-/testerApps/%@/installations/%@/releases";

NSString *const kAppDistroLibraryName = @"fire-fad";

NSString *const kReleasesKey = @"releases";
NSString *const kLatestReleaseKey = @"latest";
NSString *const kCodeHashKey = @"codeHash";

NSString *const kAuthErrorMessage = @"Unable to authenticate the tester";
NSString *const kAuthCancelledErrorMessage = @"Tester cancelled sign-in";
NSString *const kFIRFADSignInStateKey = @"FIRFADSignInState";

@synthesize isTesterSignedIn = _isTesterSignedIn;

- (BOOL)isTesterSignedIn {
  BOOL signInState = [[GULUserDefaults standardUserDefaults] boolForKey:kFIRFADSignInStateKey];
  FIRFADInfoLog(@"Tester is %@signed in.", signInState ? @"" : @"not ");
  return signInState;
}

#pragma mark - Singleton Support

- (instancetype)initWithApp:(FIRApp *)app appInfo:(NSDictionary *)appInfo {
  // FIRFADInfoLog(@"Initializing Firebase App Distribution");
  self = [super init];

  if (self) {
    [GULAppDelegateSwizzler proxyOriginalDelegate];
    self.UIService = [FIRAppDistributionUIService sharedInstance];
    [GULAppDelegateSwizzler registerAppDelegateInterceptor:self.UIService];
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
  FIRFADDebugLog(@"Instance returned: %@", instance);
  return (FIRAppDistribution *)instance;
}

- (void)signInTesterWithCompletion:(void (^)(NSError *_Nullable error))completion {
  FIRFADDebugLog(@"Prompting tester for sign in");

  if ([self isTesterSignedIn]) {
    completion(nil);
    return;
  }

  [self.UIService initializeUIState];
  FIRInstallations *installations = [FIRInstallations installations];

  // Get a Firebase Installation ID (FID).
  [installations installationIDWithCompletion:^(NSString *__nullable identifier,
                                                NSError *__nullable error) {
    if (error) {
      NSString *description = error.userInfo[NSLocalizedDescriptionKey]
                                  ? error.userInfo[NSLocalizedDescriptionKey]
                                  : @"Failed to retrieve Installation ID.";
      completion([self NSErrorForErrorCodeAndMessage:FIRAppDistributionErrorUnknown
                                             message:description]);

      [self.UIService resetUIState];
      return;
    }

    NSString *requestURL = [NSString
        stringWithFormat:@"https://partnerdash.google.com/apps/appdistribution/pub/apps/%@/"
                         @"installations/%@/buildalerts?appName=%@",
                         [[FIRApp defaultApp] options].googleAppID, identifier, [self getAppName]];

    FIRFADDebugLog(@"Registration URL: %@", requestURL);

    [self.UIService
        appDistributionRegistrationFlow:[[NSURL alloc] initWithString:requestURL]
                         withCompletion:^(NSError *_Nullable error) {
                           FIRFADInfoLog(@"Tester sign in complete.");
                           if (error) {
                             completion(error);
                             return;
                           }
                           [self persistTesterSignInStateAndHandleCompletion:completion];
                         }];
  }];
}

- (void)persistTesterSignInStateAndHandleCompletion:(void (^)(NSError *_Nullable error))completion {
  [FIRFADApiService
      fetchReleasesWithCompletion:^(NSArray *_Nullable releases, NSError *_Nullable error) {
        if (error) {
          FIRFADErrorLog(@"Tester Sign in persistence. Could not fetch releases with code %ld - %@",
                         [error code], [error localizedDescription]);
          completion([self mapFetchReleasesError:error]);
          return;
        }

        [[GULUserDefaults standardUserDefaults] setBool:YES forKey:kFIRFADSignInStateKey];
        completion(nil);
      }];
}

- (NSString *)getAppName {
  NSBundle *mainBundle = [NSBundle mainBundle];

  NSString *name = [mainBundle objectForInfoDictionaryKey:@"CFBundleName"];

  if (name)
    return
        [name stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet
                                                                     URLHostAllowedCharacterSet]];

  name = [mainBundle objectForInfoDictionaryKey:@"CFBundleDisplayName"];

  return [name stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet
                                                                      URLHostAllowedCharacterSet]];
}

- (void)signOutTester {
  FIRFADDebugLog(@"Tester is signed out.");
  [[GULUserDefaults standardUserDefaults] setBool:NO forKey:kFIRFADSignInStateKey];
}

- (NSError *)NSErrorForErrorCodeAndMessage:(FIRAppDistributionError)errorCode
                                   message:(NSString *)message {
  NSDictionary *userInfo = @{FIRAppDistributionErrorDetailsKey : message};
  return [NSError errorWithDomain:FIRAppDistributionErrorDomain code:errorCode userInfo:userInfo];
}

- (NSError *_Nullable)mapFetchReleasesError:(NSError *)error {
  if ([error domain] == kFIRFADApiErrorDomain) {
    FIRFADErrorLog(@"Failed to retrieve releases: %ld", (long)[error code]);
    switch ([error code]) {
      case FIRFADApiErrorTimeout:
        return [self NSErrorForErrorCodeAndMessage:FIRAppDistributionErrorNetworkFailure
                                           message:@"Failed to fetch releases due to timeout."];
      case FIRFADApiErrorUnauthenticated:
      case FIRFADApiErrorUnauthorized:
      case FIRFADApiTokenGenerationFailure:
      case FIRFADApiInstallationIdentifierError:
      case FIRFADApiErrorNotFound:
        return [self NSErrorForErrorCodeAndMessage:FIRAppDistributionErrorAuthenticationFailure
                                           message:@"Could not authenticate tester"];
      default:
        return [self NSErrorForErrorCodeAndMessage:FIRAppDistributionErrorUnknown
                                           message:@"Failed to fetch releases for unknown reason."];
    }
  }

  FIRFADErrorLog(@"Failed to retrieve releases with unexpected domain %@: %ld", [error domain],
                 (long)[error code]);
  return [self NSErrorForErrorCodeAndMessage:FIRAppDistributionErrorUnknown
                                     message:@"Failed to fetch releases for unknown reason."];
}

- (void)fetchNewLatestRelease:(FIRAppDistributionUpdateCheckCompletion)completion {
  [FIRFADApiService
      fetchReleasesWithCompletion:^(NSArray *_Nullable releases, NSError *_Nullable error) {
        if (error) {
          completion(nil, [self mapFetchReleasesError:error]);
          return;
        }

        for (NSDictionary *releaseDict in releases) {
          if ([[releaseDict objectForKey:kLatestReleaseKey] boolValue]) {
            FIRFADInfoLog(
                @"Tester API - found latest release in response. Checking if code hash match");
            NSString *codeHash = [releaseDict objectForKey:kCodeHashKey];
            NSString *executablePath = [[NSBundle mainBundle] executablePath];
            FIRAppDistributionMachO *machO =
                [[FIRAppDistributionMachO alloc] initWithPath:executablePath];
            FIRFADInfoLog(@"Code hash for the app on device - %@", machO.codeHash);
            FIRFADInfoLog(@"Code hash for the release from the service response - %@", codeHash);
            if (codeHash && ![codeHash isEqualToString:machO.codeHash]) {
              FIRAppDistributionRelease *release =
                  [[FIRAppDistributionRelease alloc] initWithDictionary:releaseDict];
              dispatch_async(dispatch_get_main_queue(), ^{
                FIRFADInfoLog(@"Found new release with version: %@", [release displayVersion]);
                completion(release, nil);
              });

              return;
            }
          }
        }
      }];
}

- (void)checkForUpdateWithCompletion:(FIRAppDistributionUpdateCheckCompletion)completion {
  FIRFADInfoLog(@"CheckForUpdateWithCompletion");
  if ([self isTesterSignedIn]) {
    [self fetchNewLatestRelease:completion];
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

                                   [self fetchNewLatestRelease:completion];
                                 }];
                               }];

    UIAlertAction *noButton = [UIAlertAction actionWithTitle:@"Not now"
                                                       style:UIAlertActionStyleDefault
                                                     handler:^(UIAlertAction *action) {
                                                       // precaution to ensure window gets destroyed
                                                       [self.UIService resetUIState];
                                                       completion(nil, nil);
                                                     }];

    [alert addAction:noButton];
    [alert addAction:yesButton];

    // Create an empty window + viewController to host the Safari UI.
    [self.UIService showUIAlert:alert];
  }
}
@end

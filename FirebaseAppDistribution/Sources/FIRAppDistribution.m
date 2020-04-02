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

#import "FIRAppDistribution.h"
#import "FIRAppDistribution+Private.h"
#import "FIRAppDistributionMachO.h"

#import <FirebaseCore/FIRAppInternal.h>
#import <FirebaseCore/FIRComponent.h>
#import <FirebaseCore/FIRComponentContainer.h>
#import <FirebaseCore/FIROptions.h>

#import <UIKit/UIKit.h>
#import <AppAuth/AppAuth.h>
#import <FIRAppDistributionAppDelegateInterceptor.h>
#import <GoogleUtilities/GULAppDelegateSwizzler.h>

/// Empty protocol to register with FirebaseCore's component system.
@protocol FIRAppDistributionInstanceProvider <NSObject>
@end

@interface FIRAppDistribution () <FIRLibrary, FIRAppDistributionInstanceProvider>
@end

@implementation FIRAppDistribution

// The OAuth scope needed to authorize the App Distribution Tester API
NSString *const OIDScopeTesterAPI = @"https://www.googleapis.com/auth/cloud-platform";

// The App Distribution Tester API endpoint used to retrieve releases
NSString *const ReleasesEndpointURL = @"https://firebaseapptesters.googleapis.com/v1alpha/devices/-/testerApps/%@/releases";
NSString *const TesterAPIClientID = @"319754533822-osu3v3hcci24umq6diathdm0dipds1fb.apps.googleusercontent.com";

@synthesize isTesterSignedIn = _isTesterSignedIn;

#pragma mark - Singleton Support

- (instancetype)initWithApp:(FIRApp *)app
                    appInfo:(NSDictionary *)appInfo {
    self = [super init];
    
    if (self) {
        self.safariHostingViewController = [[UIViewController alloc] init];
        
        // Save any properties here
        NSLog(@"APP DISTRIBUTION STARTED UP!");
        
        [GULAppDelegateSwizzler proxyOriginalDelegate];
        
        FIRAppDistributionAppDelegatorInterceptor *interceptor = [FIRAppDistributionAppDelegatorInterceptor sharedInstance];
        [GULAppDelegateSwizzler registerAppDelegateInterceptor:interceptor];
    }
    
    NSString* path = [[NSBundle mainBundle] executablePath];
    FIRAppDistributionMachO* machO = [[FIRAppDistributionMachO alloc] initWithPath:path];
    NSLog(@"Slices: %@", machO.slices);
    
    // TODO: Lookup keychain to load auth state on init
    _isTesterSignedIn = self.authState ? YES: NO;
    return self;
}

+ (void)load {
    [FIRApp registerInternalLibrary:(Class<FIRLibrary>)self
                           withName:@"firebase-appdistribution"
                        withVersion:@"0.0.0"]; //TODO: Get version from podspec
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
    NSURL *issuer = [NSURL URLWithString:@"https://accounts.google.com"];
    
    [OIDAuthorizationService discoverServiceConfigurationForIssuer:issuer
                                                        completion:^(OIDServiceConfiguration *_Nullable configuration,
                                                                     NSError *_Nullable error) {
        
        if (!configuration) {
            NSLog(@"Error retrieving discovery document: %@",
                  [error localizedDescription]);
            return;
        }
        
        NSString *redirectUrl = [@"dev.firebase.appdistribution." stringByAppendingString:[[[NSBundle mainBundle] bundleIdentifier] stringByAppendingString:@":/launch"]];
        
        OIDAuthorizationRequest *request =
        [[OIDAuthorizationRequest alloc] initWithConfiguration:configuration
                                                      clientId:TesterAPIClientID
                                                        scopes:@[OIDScopeOpenID,
                                                                 OIDScopeProfile,
                                                                 OIDScopeTesterAPI]
                                                   redirectURL:[NSURL URLWithString:redirectUrl]
                                                  responseType:OIDResponseTypeCode
                                          additionalParameters:nil];
        
        // Create an empty window + viewController to host the Safari UI.
        UIWindow *window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        window.rootViewController = self.safariHostingViewController;
        
        // Place it at the highest level within the stack.
        window.windowLevel = +CGFLOAT_MAX;
        
        // Run it.
        [window makeKeyAndVisible];
                
        // performs authentication request
        [FIRAppDistributionAppDelegatorInterceptor sharedInstance].currentAuthorizationFlow =
        [OIDAuthState authStateByPresentingAuthorizationRequest:request
                                       presentingViewController:self.safariHostingViewController
                                                       callback:^(OIDAuthState *_Nullable authState,
                                                                  NSError *_Nullable error) {
            self.authState = authState;
            self->_isTesterSignedIn = self.authState ? YES : NO;
            
            completion(error);
        }];
    }];
    
}

- (void)signOutTester {
    self.authState = nil;
    _isTesterSignedIn = false;
}

- (void)fetchReleases:(FIRAppDistributionUpdateCheckCompletion)completion {
    NSLog(@"Token: %@", self.authState.lastTokenResponse.accessToken);
    NSURLSession *URLSession = [NSURLSession sharedSession];
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    NSString *urlString = [NSString stringWithFormat:ReleasesEndpointURL, [[FIRApp defaultApp] options].googleAppID];
    [request setURL:[NSURL URLWithString:urlString]];
    [request setHTTPMethod:@"GET"];
    [request setValue:[NSString stringWithFormat:@"Bearer %@", self.authState.lastTokenResponse.accessToken] forHTTPHeaderField:@"Authorization"];
    
    NSURLSessionDataTask *listReleasesDataTask =
        [URLSession dataTaskWithRequest:request
                    completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            if (error) {
                
                // TODO: Reformat error into error code
                completion(nil, error);
                return;
            }
            
            NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;

            if (httpResponse.statusCode == 200) {
                NSLog(@"Response Code: %ld", httpResponse.statusCode);
                [self handleReleasesAPIResponseWithData:data completion:completion];
            } else {
                NSLog(@"Error Response Code: %ld", httpResponse.statusCode);
                
                // TODO: Handle non-200 http response
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(nil, nil);
                });
            }
        }];
    
    [listReleasesDataTask resume];
}

- (void)handleReleasesAPIResponseWithData:(NSData*)data
                               completion:(FIRAppDistributionUpdateCheckCompletion)completion {
    // TODO: Parse response from tester API, check instance identifier and maybe return a release
      
    //NSLog(@"%@", [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
    
    NSError *error = nil;
    NSDictionary *object = [NSJSONSerialization
                      JSONObjectWithData:data
                      options:0
                      error:&error];
    if(error) {
        NSLog(@"Error parsing the object - %@ error (%@)", object, error);
    }
    
    NSLog(@"Response releases %@", [object objectForKey:@"releases"]);
    
    
    NSArray *releaseList = [object objectForKey:@"releases"];
    for (NSDictionary *releaseDict in releaseList) {
        if([[releaseDict objectForKey:@"latest"] boolValue]) {
            NSString *codeHash = [releaseDict objectForKey:@"codeHash"];
            NSString *executablePath = [[NSBundle mainBundle] executablePath];
            FIRAppDistributionMachO *machO = [[FIRAppDistributionMachO alloc] initWithPath:executablePath];
            
            if(![codeHash isEqualToString:machO.codeHash]) {
                NSLog(@"Hash from service %@", codeHash);
                NSLog(@"Hash extracted from app %@", machO.codeHash);
                //Update available!
                // Ensure we dispatch on the main thread to allow any UI to update
                FIRAppDistributionRelease *release = [[FIRAppDistributionRelease alloc] initWithDictionary:releaseDict];
                
                NSLog(@"FIRAppDistributionRelease display version %@", release.displayVersion);
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(release, nil);
                });
            }
            
            break;
        }
    }
    
    // Ensure we dispatch on the main thread to allow any UI to update
    dispatch_async(dispatch_get_main_queue(), ^{
        completion(nil, nil);
    });
}

- (void)checkForUpdateWithCompletion:(FIRAppDistributionUpdateCheckCompletion)completion {
    if(self.isTesterSignedIn) {
        [self fetchReleases:completion];
    } else {
        UIAlertController *alert = [UIAlertController
                                    alertControllerWithTitle:@"Enable in-app alerts"
                                    message:@"Sign in with your Firebase App Distribution Google account to turn on in-app alerts for new test releases."
                                    preferredStyle:UIAlertControllerStyleAlert];
        
        UIAlertAction *yesButton = [UIAlertAction
                                    actionWithTitle:@"Turn on"
                                    style:UIAlertActionStyleDefault
                                    handler:^(UIAlertAction *action) {

            [self signInTesterWithCompletion:^(NSError * _Nullable error) {
                self.window.hidden = YES;
                self.window = nil;
                
                if(error) {
                    completion(nil, error);
                    return;
                }
                
                [self fetchReleases:completion];
            }];
        }];
        
        UIAlertAction *noButton = [UIAlertAction
                                   actionWithTitle:@"Not now"
                                   style:UIAlertActionStyleDefault
                                   handler:^(UIAlertAction * action) {
            
            // precaution to ensure window gets destroyed
            self.window.hidden = YES;
            self.window = nil;
            completion(nil, nil);
        }];
        
        [alert addAction:noButton];
        [alert addAction:yesButton];
        
        
        // Create an empty window + viewController to host the Safari UI.
        self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        self.window.rootViewController = [[UIViewController alloc] init];
        
        // Place it at the highest level within the stack.
        self.window.windowLevel = +CGFLOAT_MAX;
        
        // Run it.
        [self.window makeKeyAndVisible];
        [self.window.rootViewController presentViewController:alert animated:YES completion:nil];
    }
}
@end

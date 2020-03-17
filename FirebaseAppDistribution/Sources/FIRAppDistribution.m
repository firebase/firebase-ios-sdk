// Copyright 2019 Google
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

#import <FirebaseCore/FIRAppInternal.h>
#import <FirebaseCore/FIRComponent.h>
#import <FirebaseCore/FIRComponentContainer.h>

#import <UIKit/UIKit.h>
#import <AppAuth/AppAuth.h>
#import <FIRAppDistributionAppDelegateInterceptor.h>
#import <GoogleUtilities/GULAppDelegateSwizzler.h>

/// Empty protocol to register with FirebaseCore's component system.
@protocol FIRAppDistributionInstanceProvider <NSObject>
@end

@interface FIRAppDistribution () <FIRLibrary, FIRAppDistributionInstanceProvider>
@end

@implementation FIRAppDistributionRelease
- (instancetype)init {
    self = [super init];
    
    return self;
}
@end

@implementation FIRAppDistribution

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



- (void) signInTesterWithCompletion:(FIRAppDistributionSignInTesterCompletion)completion {
    
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
        NSLog(@"%@", redirectUrl);
        
        // builds authentication request
        OIDAuthorizationRequest *request =
        [[OIDAuthorizationRequest alloc] initWithConfiguration:configuration
                                                    clientId:@"319754533822-osu3v3hcci24umq6diathdm0dipds1fb.apps.googleusercontent.com"
                                                        scopes:@[OIDScopeOpenID,
                                                                 OIDScopeProfile,    @"https://www.googleapis.com/auth/cloud-platform"]
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
        
        NSLog(@"Presenting view controller: %@", self.safariHostingViewController);
        
        // performs authentication request
        [FIRAppDistributionAppDelegatorInterceptor sharedInstance].currentAuthorizationFlow =
        [OIDAuthState authStateByPresentingAuthorizationRequest:request
                                       presentingViewController:self.safariHostingViewController
                                                       callback:^(OIDAuthState *_Nullable authState,
                                                                  NSError *_Nullable error) {
            
            NSLog(@"Completed the sign in process: %@", authState);
            
            self.authState = authState;
            self->_isTesterSignedIn = self.authState ? YES : NO;
            
            completion(error);
        }];
    }];
    
}

-(void) signOutTester {
    self.authState = nil;
    _isTesterSignedIn = false;
}

- (void)checkForUpdateWithCompletion:(FIRAppDistributionUpdateCheckCompletion)completion {
    
    if(self.isTesterSignedIn) {
        NSLog(@"Got authorization tokens. Access token: %@",
              self.authState.lastTokenResponse.accessToken);
        // TODO: Extract this in a method and call the Tester API releases endpoint
        FIRAppDistributionRelease *release = [[FIRAppDistributionRelease alloc]init];
        release.displayVersion = @"1.0";
        release.buildVersion = @"123";
        release.downloadURL = [NSURL URLWithString:@""];
        completion(release, nil);
    } else {
        
        UIAlertController * alert = [UIAlertController
                                     alertControllerWithTitle:@"Enable in-app alerts"
                                     message:@"Sign in with your Firebase App Distribution Google account to turn on in-app alerts for new test releases."
                                     preferredStyle:UIAlertControllerStyleAlert];
        
        //Add Buttons
        
        UIAlertAction* yesButton = [UIAlertAction
                                    actionWithTitle:@"Turn on"
                                    style:UIAlertActionStyleDefault
                                    handler:^(UIAlertAction * action) {
            //Handle your yes please button action here
            [self signInTesterWithCompletion:^(NSError * _Nullable error) {
                self.window.hidden = YES;
                self.window = nil;
                if(error) {
                    completion(nil, error);
                    return;
                }
                NSLog(@"Got authorization tokens. Access token: %@",
                      self.authState.lastTokenResponse.accessToken);
                
                // TODO: Extract this in a method and call the Tester API releases endpoint
                FIRAppDistributionRelease *release = [[FIRAppDistributionRelease alloc]init];
                release.displayVersion = @"1.0";
                release.buildVersion = @"123";
                release.downloadURL = [NSURL URLWithString:@""];
                completion(release, nil);
            }];
        }];
        
        UIAlertAction* noButton = [UIAlertAction
                                   actionWithTitle:@"Not now"
                                   style:UIAlertActionStyleDefault
                                   handler:^(UIAlertAction * action) {
            
            //Handle no, thanks button
            // precaution to ensure window gets destroyed
            self.window.hidden = YES;
            self.window = nil;
            completion(nil, nil);
        }];
        
        //Add your buttons to alert controller
        
        [alert addAction:noButton];
        [alert addAction:yesButton];
        
        
        // Create an empty window + viewController to host the Safari UI.
        self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        self.window.rootViewController = [[UIViewController alloc] init];

//        // Place it at the highest level within the stack.
        self.window.windowLevel = +CGFLOAT_MAX;
        
        // Run it.
        [self.window makeKeyAndVisible];
        [self.window.rootViewController presentViewController:alert animated:YES completion:nil];

    }
}
@end

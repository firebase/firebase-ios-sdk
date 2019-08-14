#import "googlemac/iPhone/Config/RemoteConfig/Source/FIRRemoteConfigComponent.h"

#import "googlemac/iPhone/Config/RemoteConfig/Source/RCNConfigContent.h"
#import "googlemac/iPhone/Config/RemoteConfig/Source/RCNConfigDBManager.h"
#import "googlemac/iPhone/Config/RemoteConfig/Source/FIRRemoteConfig_Internal.h"
#import "third_party/firebase/ios/Releases/FirebaseCore/Library/Private/FIRAppInternal.h"
#import "third_party/firebase/ios/Releases/FirebaseCore/Library/Private/FIRComponent.h"
#import "third_party/firebase/ios/Releases/FirebaseCore/Library/Private/FIRComponentContainer.h"
#import "third_party/firebase/ios/Releases/FirebaseCore/Library/Private/FIRDependency.h"
#import "third_party/firebase/ios/Releases/FirebaseCore/Library/Private/FIRLogger.h"
#import "third_party/firebase/ios/Releases/FirebaseCore/Library/Private/FIROptionsInternal.h"
#import "third_party/firebase/ios/Releases/FirebaseInterop/Analytics/Public/FIRAnalyticsInterop.h"

#ifndef FIRRemoteConfig_VERSION
#error "FIRRemoteConfig_VERSION is not defined: \
add -DFIRRemoteConfig_VERSION=... to the build invocation"
#endif

#define STR(x) STR_EXPAND(x)
#define STR_EXPAND(x) #x

@implementation FIRRemoteConfigComponent

/// Default method for retrieving a Remote Config instance, or creating one if it doesn't exist.
- (FIRRemoteConfig *)remoteConfigForNamespace:(NSString *)remoteConfigNamespace {
  if (!remoteConfigNamespace) {
    // TODO: Throw an error? Return nil? What do we want to do?
    return nil;
  }

  // Validate the required information is available.
  FIROptions *options = self.app.options;
  NSString *errorPropertyName;
  if (options.googleAppID.length == 0) {
    errorPropertyName = @"googleAppID";
  } else if (options.GCMSenderID.length == 0) {
    errorPropertyName = @"GCMSenderID";
  }

  if (errorPropertyName) {
    [NSException raise:kFirebaseConfigErrorDomain
                format:@"%@", [NSString stringWithFormat:
                        @"Firebase Remote Config is missing the required %@ property from the "
                        @"configured FirebaseApp and will not be able to function properly. Please "
                        @"fix this issue to ensure that Firebase is correctly configured.",
                        errorPropertyName]];
  }

  FIRRemoteConfig *instance = self.instances[remoteConfigNamespace];
  if (!instance) {
    FIRApp *app = self.app;
    id<FIRAnalyticsInterop> analytics = app.isDefaultApp ?
        FIR_COMPONENT(FIRAnalyticsInterop, app.container) : nil;
    instance = [[FIRRemoteConfig alloc] initWithAppName:app.name
                                             FIROptions:app.options
                                              namespace:remoteConfigNamespace
                                              DBManager:[RCNConfigDBManager sharedInstance]
                                          configContent:[RCNConfigContent sharedInstance]
                                              analytics:analytics];
    self.instances[remoteConfigNamespace] = instance;
  }

  return instance;
}

/// Default initializer.
- (instancetype)initWithApp:(FIRApp *)app {
  self = [super init];
  if (self) {
    _app = app;
    _instances = [[NSMutableDictionary alloc] initWithCapacity:1];
  }
  return self;
}

#pragma mark - Lifecycle

+ (void)load {
  // Register as an internal library to be part of the initialization process. The name comes from
  // go/firebase-sdk-platform-info.
  [FIRApp registerInternalLibrary:self
                         withName:@"fire-rc"
                      withVersion:[NSString stringWithUTF8String:STR(FIRRemoteConfig_VERSION)]];
}

#pragma mark - Interoperability

+ (NSArray<FIRComponent *> *)componentsToRegister {
  FIRDependency *analyticsDep = [FIRDependency dependencyWithProtocol:@protocol(FIRAnalyticsInterop)
                                                           isRequired:NO];
  FIRComponent *rcProvider =
      [FIRComponent componentWithProtocol:@protocol(FIRRemoteConfigProvider)
                      instantiationTiming:FIRInstantiationTimingAlwaysEager
                             dependencies:@[ analyticsDep ]
                            creationBlock:^id _Nullable(FIRComponentContainer *container,
                                                        BOOL *isCacheable) {
                              // Cache the component so instances of Remote Config are cached.
                              *isCacheable = YES;
                              return [[FIRRemoteConfigComponent alloc] initWithApp:container.app];
                            }];
  return @[ rcProvider ];
}

@end

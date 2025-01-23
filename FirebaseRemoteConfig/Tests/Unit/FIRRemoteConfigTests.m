#import <XCTest/XCTest.h>

#import "FirebaseRemoteConfig/Sources/Public/FirebaseRemoteConfig/FIRRemoteConfig.h"
#import "FirebaseCore/Sources/Public/FirebaseCore/FIRApp.h"
@import FirebaseABTesting;

@interface FIRRemoteConfigTests : XCTestCase
@property (nonatomic, strong) FIRApp *mockApp;
@property (nonatomic, strong) FIRRemoteConfig *remoteConfig;
@end

@implementation FIRRemoteConfigTests

- (void)setUp {
    self.mockApp = OCMClassMock([FIRApp class]);
    OCMStub([self.mockApp isDefaultAppConfigured]).andReturn(YES);
    self.remoteConfig = [FIRRemoteConfig remoteConfigWithApp:self.mockApp];
}
- (FIROptions *)firstAppOptions {
    FIROptions *options = [[FIROptions alloc] initWithGoogleAppID:@"1:123:ios:123abc"
                                                    GCMSenderID:@"123"];
    options.APIKey = @"AIzaSy-ApiKeyWithValidFormat_0123456789";
    options.projectID = @"project-id";
    return options;
}

- (void)testPublicAPI {
    [FIRRemoteConfig remoteConfig];
    [FIRRemoteConfig remoteConfigWithApp:self.mockApp];
    [FIRRemoteConfig remoteConfigWithFIRNamespace:@"namespace"];
    [FIRRemoteConfig remoteConfigWithFIRNamespace:@"namespace" app:self.mockApp];
    
    [self testAllMethods];
}

- (void)testAllMethods{
    FIRRemoteConfig *config = [FIRRemoteConfig remoteConfig];
    FIRRemoteConfigSettings *settings = [[FIRRemoteConfigSettings alloc] init];
    config.configSettings = settings;
    
    [config fetchWithCompletionHandler:^(FIRRemoteConfigFetchStatus status, NSError * _Nullable error) {}];
    [config fetchWithExpirationDuration:43200 completionHandler:nil];
    [config fetchAndActivateWithCompletionHandler:^(FIRRemoteConfigFetchAndActivateStatus status, NSError * _Nullable error) {}];
    [config activateWithCompletion:^(BOOL changed, NSError *_Nullable error){
      }];
    
    FIRRemoteConfigValue *value = config[@"key"];
    __unused NSString *strValue = value.stringValue;
    __unused NSNumber *numValue = value.numberValue;
    __unused NSData *dataValue = value.dataValue;
    __unused BOOL boolValue = value.boolValue;
    __unused id jsonValue = value.JSONValue;

    FIRRemoteConfigValue *sourceValue = [config configValueForKey:@"key" source:FIRRemoteConfigSourceRemote];
    FIRRemoteConfigValue *sourceValueDefault = [config configValueForKey:@"key" source:FIRRemoteConfigSourceDefault];
    FIRRemoteConfigValue *sourceValueStatic = [config configValueForKey:@"key" source:FIRRemoteConfigSourceStatic];

    [_configInstances[0] objectForKeyedSubscript:@"key"];
    [_configInstances[0] configValueForKey:@"key"];
    [_configInstances[0] configValueForKey:@"key" source:FIRRemoteConfigSourceRemote];
    [_configInstances[0] allKeysFromSource:FIRRemoteConfigSourceRemote];
    [_configInstances[0] keysWithPrefix:@"prefix"];
    [_configInstances[0] defaultValueForKey:@"key"];
    [_configInstances[0] setDefaults:@{}];
    [_configInstances[0] setDefaultsFromPlistFileName:@"Defaults-testInfo"];
    
    [_configInstances[0] configSettings];
    
    [_configInstances[0] setCustomSignals:@{} withCompletion:nil];
    [_configInstances[0] addOnConfigUpdateListener:nil];

    [_configInstances[0] addRemoteConfigInteropSubscriber:nil];

    // Enums
    FIRRemoteConfigFetchStatus status = FIRRemoteConfigFetchStatusFailure;
    FIRRemoteConfigFetchAndActivateStatus statusActivate = FIRRemoteConfigFetchAndActivateStatusError;
    FIRRemoteConfigSource source = FIRRemoteConfigSourceDefault;
    FIRRemoteConfigError errorCode = FIRRemoteConfigErrorUnknown;
    FIRRemoteConfigError errorCodeUpdate = FIRRemoteConfigUpdateErrorNotFetched;
    FIRRemoteConfigError errorCodeCustomSignals = FIRRemoteConfigCustomSignalsErrorUnknown;

    // Enums
    FIRRemoteConfigFetchStatus fetchStatus = FIRRemoteConfigFetchStatusFailure;
    FIRRemoteConfigFetchAndActivateStatus fetchAndActivateStatus =
        FIRRemoteConfigFetchAndActivateStatusError;
    FIRRemoteConfigSource remoteSource = FIRRemoteConfigSourceRemote;

    //Custom Signals
    FIRRemoteConfigCustomSignalsError signalCode = FIRRemoteConfigCustomSignalsErrorInvalidValueType;
    signalCode = FIRRemoteConfigCustomSignalsErrorLimitExceeded;
    FIRRemoteConfigCustomSignalsError signalCodeUnknown = FIRRemoteConfigCustomSignalsErrorUnknown;
    NSString *s = FIRRemoteConfigCustomSignalsErrorDomain;

    [_configInstances[0] setCustomSignals:@{@"signal" : @1}];
    [_configInstances[0] setCustomSignals:@{@"signal" : @1}];
    NSDictionary<NSString *, NSObject *> *customSignals = @{
        @"signal1":@"stringValue",
        @"signal2":@1,
        @"signal3":@"stringValue2",
    };

    [_configInstances[0] setCustomSignals:customSignals withCompletion:nil];

    NSString *string = FIRRemoteConfigThrottledEndTimeInSecondsKey;
    string = FIRRemoteConfigErrorDomain;
    string = FIRRemoteConfigCustomSignalsErrorDomain;
    string = FIRRemoteConfigUpdateErrorDomain;
    NSString *const string2 = @"error_throttled_end_time_seconds";
    NSString *const string3 = @"error_throttled_end_time_seconds_key";
}

- (void)testTypes{
    //typedefs
    FIRRemoteConfigFetchCompletion completion;
    FIRRemoteConfigActivateCompletion completion2;
    FIRRemoteConfigInitializationCompletion completion3;
    FIRRemoteConfigFetchAndActivateCompletion completion4;

    // Enums
    FIRRemoteConfigFetchStatus fetchStatus;
    FIRRemoteConfigFetchAndActivateStatus fetchAndActivateStatus;
    FIRRemoteConfigSource source = FIRRemoteConfigSourceDefault;
    source = FIRRemoteConfigSourceRemote;
    source = FIRRemoteConfigSourceStatic;
    FIRRemoteConfigError error;

    FIRRemoteConfigError errorCode = FIRRemoteConfigErrorUnknown;
    errorCode = FIRRemoteConfigErrorThrottled;
    errorCode = FIRRemoteConfigErrorInternalError;

    FIRRemoteConfigUpdateError errorCodeUpdate = FIRRemoteConfigUpdateErrorNotFetched;
    errorCodeUpdate = FIRRemoteConfigUpdateErrorStreamError;
    errorCodeUpdate = FIRRemoteConfigUpdateErrorMessageInvalid;
    errorCodeUpdate = FIRRemoteConfigUpdateErrorUnavailable;

    FIRRemoteConfigCustomSignalsError signalCode = FIRRemoteConfigCustomSignalsErrorInvalidValueType;
    signalCode = FIRRemoteConfigCustomSignalsErrorLimitExceeded;
    signalCode = FIRRemoteConfigCustomSignalsErrorUnknown;

    // FIRRemoteConfigFetchStatus
    FIRRemoteConfigFetchStatus status;
    status = FIRRemoteConfigFetchStatusFailure;
    status = FIRRemoteConfigFetchStatusNoFetchYet;
    status = FIRRemoteConfigFetchStatusSuccess;
    status = FIRRemoteConfigFetchStatusThrottled;

    // FIRRemoteConfigFetchAndActivateStatus
    FIRRemoteConfigFetchAndActivateStatus fetchAndActivateStatus =
        FIRRemoteConfigFetchAndActivateStatusError;
    fetchAndActivateStatus = FIRRemoteConfigFetchAndActivateStatusSuccessFetchedFromRemote;
    fetchAndActivateStatus = FIRRemoteConfigFetchAndActivateStatusSuccessUsingPreFetchedData;
    fetchAndActivateStatus = FIRRemoteConfigFetchAndActivateStatusError;
    
    //FIRRemoteConfigSource
    FIRRemoteConfigSource remoteSource;
    remoteSource = FIRRemoteConfigSourceDefault;
    remoteSource = FIRRemoteConfigSourceRemote;
    remoteSource = FIRRemoteConfigSourceStatic;

    //FIRRemoteConfigError
    FIRRemoteConfigError errorCode2 = FIRRemoteConfigErrorUnknown;
    errorCode2 = FIRRemoteConfigErrorThrottled;
    errorCode2 = FIRRemoteConfigErrorInternalError;

    // FIRRemoteConfigFetchCompletion
    FIRRemoteConfigFetchCompletion fetchCompletion;

    // FIRRemoteConfigActivateCompletion
    FIRRemoteConfigActivateCompletion activateCompletion;

    // FIRRemoteConfigInitializationCompletion
    FIRRemoteConfigInitializationCompletion initializationCompletion;
    
    //FIRRemoteConfigFetchAndActivateCompletion
    FIRRemoteConfigFetchAndActivateCompletion fetchAndActivateCompletion;

    //FIRRemoteConfigValue
    FIRRemoteConfigValue *value;
    NSString *string = value.stringValue;
    NSNumber *number = value.numberValue;
    NSData *data = value.dataValue;
    BOOL boolValue = value.boolValue;
    id json = value.JSONValue;
    FIRRemoteConfigSource source = value.source;

    //FIRRemoteConfigUpdate
    FIRRemoteConfigUpdate *update;

    // FIRRemoteConfigSettings
    FIRRemoteConfigSettings *setings = [[FIRRemoteConfigSettings alloc] init];

    //NSNotificationName
    NSNotificationName notificationName;
    notificationName = FIRRemoteConfigActivateNotification;
    
    // NSNotificationName
    NSNotificationName name;
    name = FIRRolloutsStateDidChangeNotificationName;
    
    // FIRRemoteConfigThrottledEndTimeInSecondsKey
    NSString *const string2 = @"error_throttled_end_time_seconds";

    //FIRRemoteConfigUpdateError
    NSString *const string3 = @"error_throttled_end_time_seconds_key";

    //NS_SWIFT_NAME
    NSString *name2 = FIRNamespaceGoogleMobilePlatform;
    NSString *name3 = FIRRemoteConfigThrottledEndTimeInSecondsKey;
    NSString *name4 = FIRRemoteConfigErrorDomain;
    NSString *name5 = FIRRemoteConfigUpdateErrorDomain;
    NSString *name6 = FIRRemoteConfigCustomSignalsErrorDomain;
    NSString *name7 = FIRRemoteConfigUpdateErrorDomain;

    //FIRRemoteConfigFetchStatus
    FIRRemoteConfigFetchStatus fetchStatus4;
}

@end

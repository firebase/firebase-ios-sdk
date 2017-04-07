// Copyright 2017 Google
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

#import "Private/FIRBundleUtil.h"
#import "Private/FIRErrors.h"
#import "Private/FIRLogger.h"
#import "Private/FIROptionsInternal.h"

// Keys for the strings in the plist file.
NSString *const kFIRAPIKey = @"API_KEY";
NSString *const kFIRTrackingID = @"TRACKING_ID";
NSString *const kFIRGoogleAppID = @"GOOGLE_APP_ID";
NSString *const kFIRClientID = @"CLIENT_ID";
NSString *const kFIRGCMSenderID = @"GCM_SENDER_ID";
NSString *const kFIRAndroidClientID = @"ANDROID_CLIENT_ID";
NSString *const kFIRDatabaseURL = @"DATABASE_URL";
NSString *const kFIRStorageBucket = @"STORAGE_BUCKET";
// The key to locate the expected bundle identifier in the plist file.
NSString *const kFIRBundleID = @"BUNDLE_ID";
// The key to locate the project identifier in the plist file.
NSString *const kFIRProjectID = @"PROJECT_ID";

NSString *const kFIRIsMeasurementEnabled = @"IS_MEASUREMENT_ENABLED";
NSString *const kFIRIsAnalyticsCollectionEnabled = @"FIREBASE_ANALYTICS_COLLECTION_ENABLED";
NSString *const kFIRIsAnalyticsCollectionDeactivated = @"FIREBASE_ANALYTICS_COLLECTION_DEACTIVATED";

NSString *const kFIRIsAnalyticsEnabled = @"IS_ANALYTICS_ENABLED";
NSString *const kFIRIsSignInEnabled = @"IS_SIGNIN_ENABLED";

// TODO: Remove bug from comment before open source
// Library version ID. Fix b/28753358 (>1 digit minor version number support)
NSString *const kFIRLibraryVersionID =
    @"3"     // Major version (one or more digits)
    @"6"     // Minor version (exactly 1 digit)
    @"00"    // Build number (exactly 2 digits)
    @"000";  // Fixed "000"
// Plist file name.
NSString *const kServiceInfoFileName = @"GoogleService-Info";
// Plist file type.
NSString *const kServiceInfoFileType = @"plist";

@interface FIROptions ()

/**
 * This property maintains the actual configuration key-value pairs.
 */
@property(nonatomic, readwrite) NSDictionary *optionsDictionary;

/**
 * Combination of analytics options from both the main plist and the GoogleService-info.plist.
 * Values which are present in the main plist override values from the GoogleService-info.plist.
 */
@property(nonatomic, readonly) NSDictionary *analyticsOptionsDictionary;

@end

@implementation FIROptions {
  /// Backing variable for self.analyticsOptionsDictionary.
  NSDictionary *_analyticsOptionsDictionary;
  dispatch_once_t _createAnalyticsOptionsDictionaryOnce;
}

static FIROptions *sDefaultOptions = nil;
static NSDictionary *sDefaultOptionsDictionary = nil;

#pragma mark - Public only for internal class methods

+ (FIROptions *)defaultOptions {
  if (sDefaultOptions != nil) {
    return sDefaultOptions;
  }

  NSDictionary *defaultOptionsDictionary = [self defaultOptionsDictionary];
  if (defaultOptionsDictionary == nil) {
    return nil;
  }

  sDefaultOptions =
      [[FIROptions alloc] initInternalWithOptionsDictionary:defaultOptionsDictionary];
  return sDefaultOptions;
}

#pragma mark - Private class methods

+ (NSDictionary *)defaultOptionsDictionary {
  if (sDefaultOptionsDictionary != nil) {
    return sDefaultOptionsDictionary;
  }
  NSString *plistFilePath = [FIROptions plistFilePathWithName:kServiceInfoFileName];
  if (plistFilePath == nil) {
    return nil;
  }
  sDefaultOptionsDictionary = [NSDictionary dictionaryWithContentsOfFile:plistFilePath];
  if (sDefaultOptionsDictionary == nil) {
    FIRLogError(kFIRLoggerCore, @"I-COR000011", @"The configuration file is not a dictionary: "
                @"'%@.%@'.", kServiceInfoFileName, kServiceInfoFileType);
  }
  return sDefaultOptionsDictionary;
}

// Returns the path of the plist file with a given file name.
+ (NSString *)plistFilePathWithName:(NSString *)fileName {
  NSArray *bundles = [FIRBundleUtil relevantBundles];
  NSString *plistFilePath =
      [FIRBundleUtil optionsDictionaryPathWithResourceName:fileName
                                               andFileType:kServiceInfoFileType
                                                 inBundles:bundles];
  if (plistFilePath == nil) {
    FIRLogError(kFIRLoggerCore, @"I-COR000012", @"Could not locate configuration file: '%@.%@'.",
                fileName, kServiceInfoFileType);
  }
  return plistFilePath;
}

+ (void)resetDefaultOptions {
  sDefaultOptions = nil;
  sDefaultOptionsDictionary = nil;
}

#pragma mark - Private instance methods

- (instancetype)initInternalWithOptionsDictionary:(NSDictionary *)optionsDictionary {
  self = [super init];
  if (self) {
    _optionsDictionary = optionsDictionary;
    _usingOptionsFromDefaultPlist = YES;
  }
  return self;
}

- (id)copyWithZone:(NSZone *)zone {
  FIROptions *newOptions = [[[self class] allocWithZone:zone] init];
  if (newOptions) {
    newOptions.optionsDictionary = self.optionsDictionary;
    newOptions.deepLinkURLScheme = self.deepLinkURLScheme;
  }
  return newOptions;
}

#pragma mark - Public instance methods

- (instancetype)initWithGoogleAppID:(NSString *)googleAppID
                           bundleID:(NSString *)bundleID
                        GCMSenderID:(NSString *)GCMSenderID
                             APIKey:(NSString *)APIKey
                           clientID:(NSString *)clientID
                         trackingID:(NSString *)trackingID
                    androidClientID:(NSString *)androidClientID
                        databaseURL:(NSString *)databaseURL
                      storageBucket:(NSString *)storageBucket
                  deepLinkURLScheme:(NSString *)deepLinkURLScheme {
  self = [super init];
  if (self) {
    if (!googleAppID) {
      [NSException raise:kFirebaseCoreErrorDomain format:@"Please specify a valid Google App ID."];
    } else if (!GCMSenderID) {
      [NSException raise:kFirebaseCoreErrorDomain format:@"Please specify a valid GCM Sender ID."];
    }

    NSMutableDictionary *mutableOptionsDict = [NSMutableDictionary dictionary];
    [mutableOptionsDict setValue:googleAppID forKey:kFIRGoogleAppID];
    [mutableOptionsDict setValue:bundleID forKey:kFIRBundleID];
    [mutableOptionsDict setValue:GCMSenderID forKey:kFIRGCMSenderID];
    [mutableOptionsDict setValue:APIKey forKey:kFIRAPIKey];
    [mutableOptionsDict setValue:clientID forKey:kFIRClientID];
    [mutableOptionsDict setValue:trackingID forKey:kFIRTrackingID];
    [mutableOptionsDict setValue:androidClientID forKey:kFIRAndroidClientID];
    [mutableOptionsDict setValue:databaseURL forKey:kFIRDatabaseURL];
    [mutableOptionsDict setValue:storageBucket forKey:kFIRStorageBucket];
    self.optionsDictionary = [NSDictionary dictionaryWithDictionary:mutableOptionsDict];
    self.deepLinkURLScheme = deepLinkURLScheme;
  }
  return self;
}

- (instancetype)initWithContentsOfFile:(NSString *)plistPath {
  self = [super init];
  if (self) {
    if (plistPath == nil) {
      FIRLogError(kFIRLoggerCore, @"I-COR000013", @"The plist file path is nil.");
      return nil;
    }
    _optionsDictionary = [NSDictionary dictionaryWithContentsOfFile:plistPath];
    if (_optionsDictionary == nil) {
      FIRLogError(kFIRLoggerCore, @"I-COR000014", @"The configuration file at %@ does not exist or "
                  @"is not a well-formed plist file.", plistPath);
      return nil;
    }
  }
  return self;
}

- (NSString *)APIKey {
  return self.optionsDictionary[kFIRAPIKey];
}

- (NSString *)clientID {
  return self.optionsDictionary[kFIRClientID];
}

- (NSString *)trackingID {
  return self.optionsDictionary[kFIRTrackingID];
}

- (NSString *)GCMSenderID {
  return self.optionsDictionary[kFIRGCMSenderID];
}

- (NSString *)projectID {
  return self.optionsDictionary[kFIRProjectID];
}

- (NSString *)androidClientID {
  return self.optionsDictionary[kFIRAndroidClientID];
}

- (NSString *)googleAppID {
  return self.optionsDictionary[kFIRGoogleAppID];
}

- (NSString *)libraryVersionID {
  return kFIRLibraryVersionID;
}

- (NSString *)databaseURL {
  return self.optionsDictionary[kFIRDatabaseURL];
}

- (NSString *)storageBucket {
  return self.optionsDictionary[kFIRStorageBucket];
}

- (NSDictionary *)analyticsOptionsDictionary {
  dispatch_once(&_createAnalyticsOptionsDictionaryOnce, ^{
    NSMutableDictionary *tempAnalyticsOptions = [[NSMutableDictionary alloc] init];
    NSDictionary *mainInfoDictionary = [NSBundle mainBundle].infoDictionary;
    NSArray *measurementKeys = @[ kFIRIsMeasurementEnabled,
                                  kFIRIsAnalyticsCollectionEnabled,
                                  kFIRIsAnalyticsCollectionDeactivated ];
    for (NSString *key in measurementKeys) {
      id value = mainInfoDictionary[key] ?: self.optionsDictionary[key] ?: nil;
      if (!value) {
        continue;
      }
      tempAnalyticsOptions[key] = value;
    }
    _analyticsOptionsDictionary = tempAnalyticsOptions;
  });
  return _analyticsOptionsDictionary;
}

- (NSString *)bundleID {
  return self.optionsDictionary[kFIRBundleID];
}

/**
 * Whether or not Measurement was enabled. Measurement is enabled unless explicitly disabled in
 * GoogleService-Info.plist. This uses the old plist flag IS_MEASUREMENT_ENABLED, which should still
 * be supported.
 */
- (BOOL)isMeasurementEnabled {
  if (self.isAnalyticsCollectionDeactivated) {
    return NO;
  }
  if (!self.analyticsOptionsDictionary[kFIRIsMeasurementEnabled]) {
    return YES;  // Enable Measurement by default when the key is not in the dictionary.
  }
  return [self.analyticsOptionsDictionary[kFIRIsMeasurementEnabled] boolValue];
}

- (BOOL)isAnalyticsCollectionEnabled {
  if (self.isAnalyticsCollectionDeactivated) {
    return NO;
  }
  if (!self.analyticsOptionsDictionary[kFIRIsAnalyticsCollectionEnabled]) {
    return self.isMeasurementEnabled;  // Fall back to older plist flag.
  }
  return [self.analyticsOptionsDictionary[kFIRIsAnalyticsCollectionEnabled] boolValue];
}

- (BOOL)isAnalyticsCollectionDeactivated {
  if (!self.analyticsOptionsDictionary[kFIRIsAnalyticsCollectionDeactivated]) {
    return NO;  // Analytics Collection is not deactivated when the key is not in the dictionary.
  }
  return [self.analyticsOptionsDictionary[kFIRIsAnalyticsCollectionDeactivated] boolValue];
}

- (BOOL)isAnalyticsEnabled {
  return [self.optionsDictionary[kFIRIsAnalyticsEnabled] boolValue];
}

- (BOOL)isSignInEnabled {
  return [self.optionsDictionary[kFIRIsSignInEnabled] boolValue];
}

@end

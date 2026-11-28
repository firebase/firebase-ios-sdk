// Copyright 2026 Google LLC
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

// Shared body of the Objective-C API coverage tests. Each test file imports FirebaseCore in a
// different way and then includes this file, so every import style must expose the whole
// Objective-C API. The code is compiled but never run; compiling it is the test.
//
// Keep this in sync with the public headers in FirebaseCore/Sources/Public/FirebaseCore.

// The log levels must stay compile-time constants.
static const FIRLoggerLevel kFIRCoreAPICoverageLevels[] __attribute__((unused)) = {
    FIRLoggerLevelError, FIRLoggerLevelWarning, FIRLoggerLevelNotice, FIRLoggerLevelInfo,
    FIRLoggerLevelDebug, FIRLoggerLevelMin,     FIRLoggerLevelMax,
};

static void FIRCoreAPICoverage(void) __attribute__((unused));
static void FIRCoreAPICoverage(void) {
  // FIRApp
  [FIRApp configure];
  FIROptions *options = [[FIROptions alloc] initWithGoogleAppID:@"1:123:ios:abc"
                                                    GCMSenderID:@"123"];
  [FIRApp configureWithOptions:options];
  [FIRApp configureWithName:@"name" options:options];
  FIRApp *_Nullable app = [FIRApp defaultApp];
  app = [FIRApp appNamed:@"name"];
  NSDictionary<NSString *, FIRApp *> *_Nullable apps = [FIRApp allApps];
  apps = FIRApp.allApps;
  FIRAppVoidBoolCallback callback = ^(BOOL success) {
  };
  [app deleteApp:callback];
  [app deleteApp:^(BOOL success){
  }];
  NSString *name = app.name;
  name = [app name];
  FIROptions *appOptions = app.options;
  appOptions = [app options];
  BOOL enabled = app.dataCollectionDefaultEnabled;
  enabled = app.isDataCollectionDefaultEnabled;
  enabled = [app isDataCollectionDefaultEnabled];
  app.dataCollectionDefaultEnabled = NO;
  [app setDataCollectionDefaultEnabled:YES];

  // FIROptions
  FIROptions *_Nullable defaultOptions = [FIROptions defaultOptions];
  FIROptions *_Nullable fileOptions = [[FIROptions alloc] initWithContentsOfFile:@"path"];
  NSString *_Nullable optionalString = options.APIKey;
  options.APIKey = @"key";
  NSString *string = options.bundleID;
  options.bundleID = @"bundle";
  optionalString = options.clientID;
  options.clientID = @"client";
  string = options.GCMSenderID;
  options.GCMSenderID = @"sender";
  optionalString = options.projectID;
  options.projectID = @"project";
  string = options.googleAppID;
  options.googleAppID = @"1:123:ios:abc";
  optionalString = options.databaseURL;
  options.databaseURL = @"https://example.firebaseio.com";
  optionalString = options.storageBucket;
  options.storageBucket = @"bucket";
  optionalString = options.appGroupID;
  options.appGroupID = @"group";
  FIROptions *copiedOptions = [options copy];
  id<NSCopying> copyingOptions = options;

  // FIRConfiguration
  FIRConfiguration *configuration = [FIRConfiguration sharedInstance];
  configuration = FIRConfiguration.sharedInstance;
  [configuration setLoggerLevel:FIRLoggerLevelDebug];
  FIRLoggerLevel level = [configuration loggerLevel];
  switch (level) {
    case FIRLoggerLevelError:
    case FIRLoggerLevelWarning:
    case FIRLoggerLevelNotice:
    case FIRLoggerLevelInfo:
    case FIRLoggerLevelDebug:
      break;
  }

  // FIRTimestamp
  FIRTimestamp *timestamp = [[FIRTimestamp alloc] initWithSeconds:1 nanoseconds:2];
  timestamp = [FIRTimestamp timestampWithSeconds:1 nanoseconds:2];
  timestamp = [FIRTimestamp timestampWithDate:[NSDate date]];
  timestamp = [FIRTimestamp timestamp];
  NSDate *date = [timestamp dateValue];
  NSComparisonResult comparison = [timestamp compare:timestamp];
  int64_t seconds = timestamp.seconds;
  int32_t nanoseconds = timestamp.nanoseconds;
  FIRTimestamp *copiedTimestamp = [timestamp copy];
  id<NSCopying> copyingTimestamp = timestamp;

  // FIRFirebaseVersion
#ifdef __cplusplus
  // FIRVersion.h declares FIRFirebaseVersion() without `extern "C"`, so Objective-C++ callers
  // reference a C++-mangled symbol that doesn't exist and fail to link. Re-enable this when the
  // declaration gains FOUNDATION_EXPORT.
  NSString *version = @"";
#else
  NSString *version = FIRFirebaseVersion();
#endif

  (void)apps;
  (void)name;
  (void)appOptions;
  (void)enabled;
  (void)defaultOptions;
  (void)fileOptions;
  (void)optionalString;
  (void)string;
  (void)copiedOptions;
  (void)copyingOptions;
  (void)date;
  (void)comparison;
  (void)seconds;
  (void)nanoseconds;
  (void)copiedTimestamp;
  (void)copyingTimestamp;
  (void)version;
}

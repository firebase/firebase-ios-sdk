// Copyright 2021 Google LLC
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

#import "Crashlytics/Crashlytics/Public/FirebaseCrashlytics/FIRCrashlyticsReport.h"

#import "Crashlytics/Crashlytics/Components/FIRCLSContext.h"
#import "Crashlytics/Crashlytics/Components/FIRCLSGlobals.h"
#import "Crashlytics/Crashlytics/Helpers/FIRCLSLogger.h"
#import "Crashlytics/Crashlytics/Models/FIRCLSInternalReport.h"

@interface FIRCrashlyticsReport () {
  NSString *_reportID;
  NSDate *_dateCreated;
  BOOL _hasCrash;

  FIRCLSUserLoggingABStorage _logStorage;
  const char *_activeLogPath;

  uint32_t _internalKVCounter;
  FIRCLSUserLoggingKVStorage _internalKVStorage;

  uint32_t _userKVCounter;
  FIRCLSUserLoggingKVStorage _userKVStorage;
}

@property(nonatomic, strong) FIRCLSInternalReport *internalReport;

@end

@implementation FIRCrashlyticsReport

- (instancetype)initWithInternalReport:(FIRCLSInternalReport *)internalReport {
  self = [super init];
  if (!self) {
    return nil;
  }

  _internalReport = internalReport;
  _reportID = [[internalReport identifier] copy];
  _dateCreated = [[internalReport dateCreated] copy];
  _hasCrash = [internalReport isCrash];

  _logStorage.maxSize = _firclsContext.readonly->logging.logStorage.maxSize;
  _logStorage.maxEntries = _firclsContext.readonly->logging.logStorage.maxEntries;
  _logStorage.restrictBySize = _firclsContext.readonly->logging.logStorage.restrictBySize;
  _logStorage.entryCount = _firclsContext.readonly->logging.logStorage.entryCount;
  _logStorage.aPath = [FIRCrashlyticsReport filesystemPathForContentFile:FIRCLSReportLogAFile
                                                        inInternalReport:internalReport];
  _logStorage.bPath = [FIRCrashlyticsReport filesystemPathForContentFile:FIRCLSReportLogBFile
                                                        inInternalReport:internalReport];

  _activeLogPath = _logStorage.aPath;

  // TODO: correct kv accounting
  // The internal report will have non-zero compacted and incremental keys. The right thing to do
  // is count them, so we can kick off compactions/pruning at the right times. By
  // setting this value to zero, we're allowing more entries to be made than there really
  // should be. Not the end of the world, but we should do better eventually.
  _internalKVCounter = 0;
  _userKVCounter = 0;

  _userKVStorage.maxCount = _firclsContext.readonly->logging.userKVStorage.maxCount;
  _userKVStorage.maxIncrementalCount =
      _firclsContext.readonly->logging.userKVStorage.maxIncrementalCount;
  _userKVStorage.compactedPath =
      [FIRCrashlyticsReport filesystemPathForContentFile:FIRCLSReportUserCompactedKVFile
                                        inInternalReport:internalReport];
  _userKVStorage.incrementalPath =
      [FIRCrashlyticsReport filesystemPathForContentFile:FIRCLSReportUserIncrementalKVFile
                                        inInternalReport:internalReport];

  _internalKVStorage.maxCount = _firclsContext.readonly->logging.internalKVStorage.maxCount;
  _internalKVStorage.maxIncrementalCount =
      _firclsContext.readonly->logging.internalKVStorage.maxIncrementalCount;
  _internalKVStorage.compactedPath =
      [FIRCrashlyticsReport filesystemPathForContentFile:FIRCLSReportInternalCompactedKVFile
                                        inInternalReport:internalReport];
  _internalKVStorage.incrementalPath =
      [FIRCrashlyticsReport filesystemPathForContentFile:FIRCLSReportInternalIncrementalKVFile
                                        inInternalReport:internalReport];

  return self;
}

+ (const char *)filesystemPathForContentFile:(NSString *)contentFile
                            inInternalReport:(FIRCLSInternalReport *)internalReport {
  if (!internalReport) {
    return nil;
  }

  // We need to be defensive because strdup will crash
  // if given a nil.
  NSString *objCString = [internalReport pathForContentFile:contentFile];
  const char *fileSystemString = [objCString fileSystemRepresentation];
  if (!objCString || !fileSystemString) {
    return nil;
  }

  // Paths need to be duplicated because fileSystemRepresentation returns C strings
  // that are freed outside of this context.
  return strdup(fileSystemString);
}

- (BOOL)checkContextForMethod:(NSString *)methodName {
  if (!FIRCLSContextIsInitialized()) {
    FIRCLSErrorLog(@"%@ failed for FIRCrashlyticsReport because Crashlytics context isn't "
                   @"initialized.",
                   methodName);
    return false;
  }
  return true;
}

#pragma mark - API: Getters

- (NSString *)reportID {
  return _reportID;
}

- (NSDate *)dateCreated {
  return _dateCreated;
}

- (BOOL)hasCrash {
  return _hasCrash;
}

#pragma mark - API: Logging

- (void)log:(NSString *)msg {
  if (![self checkContextForMethod:@"log:"]) {
    return;
  }

  FIRCLSLogToStorage(&_logStorage, &_activeLogPath, @"%@", msg);
}

- (void)logWithFormat:(NSString *)format, ... {
  if (![self checkContextForMethod:@"logWithFormat:"]) {
    return;
  }

  va_list args;
  va_start(args, format);
  [self logWithFormat:format arguments:args];
  va_end(args);
}

- (void)logWithFormat:(NSString *)format arguments:(va_list)args {
  if (![self checkContextForMethod:@"logWithFormat:arguments:"]) {
    return;
  }

  [self log:[[NSString alloc] initWithFormat:format arguments:args]];
}

#pragma mark - API: setUserID

- (void)setUserID:(NSString *)userID {
  if (![self checkContextForMethod:@"setUserID:"]) {
    return;
  }

  FIRCLSUserLoggingRecordKeyValue(FIRCLSUserIdentifierKey, userID, &_internalKVStorage,
                                  &_internalKVCounter);
}

#pragma mark - API: setCustomValue

- (void)setCustomValue:(id)value forKey:(NSString *)key {
  if (![self checkContextForMethod:@"setCustomValue:forKey:"]) {
    return;
  }

  FIRCLSUserLoggingRecordKeyValue(key, value, &_userKVStorage, &_userKVCounter);
}

- (void)setCustomKeysAndValues:(NSDictionary *)keysAndValues {
  if (![self checkContextForMethod:@"setCustomKeysAndValues:"]) {
    return;
  }

  FIRCLSUserLoggingRecordKeysAndValues(keysAndValues, &_userKVStorage, &_userKVCounter);
}

@end

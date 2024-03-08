// Copyright 2024 Google LLC
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
#include "Crashlytics/Crashlytics/Components/FIRCLSGlobals.h"
#include "Crashlytics/Crashlytics/Components/FIRCLSUserLogging.h"
#import "Crashlytics/Crashlytics/Helpers/FIRCLSLogger.h"
#import "Crashlytics/Crashlytics/Models/FIRCLSFileManager.h"
#import "Crashlytics/Crashlytics/Models/FIRCLSInternalReport.h"

#if SWIFT_PACKAGE
@import FirebaseCrashlyticsSwift;
#else  // Swift Package Manager
#import <FirebaseCrashlytics/FirebaseCrashlytics-Swift.h>
#endif  // CocoaPods

@interface FIRCLSRolloutsPersistenceManager : NSObject <FIRCLSPersistenceLog>
@property(nonatomic, readonly) FIRCLSFileManager *fileManager;
@end

@implementation FIRCLSRolloutsPersistenceManager
- (instancetype)initWithFileManager:(FIRCLSFileManager *)fileManager {
  self = [super init];
  if (!self) {
    return nil;
  }
  _fileManager = fileManager;
  return self;
}

- (void)updateRolloutsStateToPersistenceWithRollouts:(NSData *_Nonnull)rollouts
                                            reportID:(NSString *_Nonnull)reportID {
  NSString *rolloutsPath = [[[_fileManager activePath] stringByAppendingPathComponent:reportID]
      stringByAppendingPathComponent:FIRCLSReportRolloutsFile];
  if (![_fileManager fileExistsAtPath:rolloutsPath]) {
    if (![_fileManager createFileAtPath:rolloutsPath contents:nil attributes:nil]) {
      FIRCLSDebugLog(@"Could not create rollouts.clsrecord file. Error was code: %d - message: %s",
                     errno, strerror(errno));
    }
  }

  NSFileHandle *rolloutsFile = [NSFileHandle fileHandleForUpdatingAtPath:rolloutsPath];

  dispatch_sync(FIRCLSGetLoggingQueue(), ^{
    [rolloutsFile seekToEndOfFile];
    [rolloutsFile writeData:rollouts];
    NSData *newLineData = [@"\n" dataUsingEncoding:NSUTF8StringEncoding];
    [rolloutsFile writeData:newLineData];
  });
}

- (void)debugLogWithMessage:(NSString *_Nonnull)message {
  FIRCLSDebugLog(message);
}

@end

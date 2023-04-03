//
// Copyright 2022 Google LLC
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

#import "Crashlytics/Crashlytics/Models/FIRCLSFileManager.h"
#import "Crashlytics/Crashlytics/Models/FIRCLSInternalReport.h"
#import "Crashlytics/Crashlytics/Models/FIRCLSSettings.h"

NS_ASSUME_NONNULL_BEGIN

///
/// The ContextManager determines when to build the context object,
/// and write its metadata. It was created because the FIRCLSContext
/// is interacted with via functions, which makes it hard to include in tests.
/// In addition, we this class is responsible for re-writing the Metadata object
/// when the App Quality Session ID changes.
///
@interface FIRCLSContextManager : NSObject

/// This should be set immediately when the FirebaseSessions SDK generates
/// a new Session ID.
@property(nonatomic, copy) NSString *appQualitySessionId;

- (BOOL)setupContextWithReport:(FIRCLSInternalReport *)report
                      settings:(FIRCLSSettings *)settings
                   fileManager:(FIRCLSFileManager *)fileManager;

@end

NS_ASSUME_NONNULL_END

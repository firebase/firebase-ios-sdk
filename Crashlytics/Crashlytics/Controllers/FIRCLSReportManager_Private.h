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

#import "Crashlytics/Crashlytics/Controllers/FIRCLSReportManager.h"
#import "Crashlytics/Crashlytics/Controllers/FIRCLSReportUploader.h"
#import "Crashlytics/Crashlytics/Models/FIRCLSLaunchMarkerModel.h"

@class FIRCLSInstallIdentifierModel;

@interface FIRCLSReportManager ()

@property(nonatomic, strong) NSOperationQueue *operationQueue;
@property(nonatomic, strong) FIRCLSFileManager *fileManager;

@end

@interface FIRCLSReportManager (PrivateMethods)

@property(nonatomic, strong) FIRCLSLaunchMarkerModel *launchMarker;

@end

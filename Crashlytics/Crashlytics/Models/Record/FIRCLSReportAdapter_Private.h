/*
 * Copyright 2020 Google
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

#import "FIRCLSReportAdapter.h"

#import "FIRCLSRecordApplication.h"
#import "FIRCLSRecordBinaryImage.h"
#import "FIRCLSRecordExecutable.h"
#import "FIRCLSRecordHost.h"
#import "FIRCLSRecordIdentity.h"
#import "FIRCLSRecordKeyValue.h"
#import "FIRCLSRecordProcessStats.h"
#import "FIRCLSRecordRegister.h"
#import "FIRCLSRecordRuntime.h"
#import "FIRCLSRecordSignal.h"
#import "FIRCLSRecordStorage.h"
#import "FIRCLSRecordThread.h"

@interface FIRCLSReportAdapter ()

@property(nonatomic, strong) NSString *folderPath;
@property(nonatomic, strong) NSString *googleAppID;

@property(nonatomic, strong) FIRCLSRecordSignal *signal;
@property(nonatomic, strong) NSArray<FIRCLSRecordThread *> *threads;
@property(nonatomic, strong) FIRCLSRecordProcessStats *processStats;
@property(nonatomic, strong) FIRCLSRecordStorage *storage;
@property(nonatomic, strong) NSArray<FIRCLSRecordBinaryImage *> *binaryImages;
@property(nonatomic, strong) FIRCLSRecordRuntime *runtime;
@property(nonatomic, strong) FIRCLSRecordIdentity *identity;
@property(nonatomic, strong) FIRCLSRecordHost *host;
@property(nonatomic, strong) FIRCLSRecordApplication *application;
@property(nonatomic, strong) FIRCLSRecordExecutable *executable;
@property(nonatomic, strong) NSDictionary<NSString *, NSString *> *keyValues;

@property(nonatomic) google_crashlytics_Report report;

@end

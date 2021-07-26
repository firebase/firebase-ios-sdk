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

#import <Foundation/Foundation.h>

#import "Crashlytics/Crashlytics/Components/FIRCLSCrashedMarkerFile.h"
#import "Crashlytics/Crashlytics/Controllers/FIRCLSManagerData.h"
#import "Crashlytics/Crashlytics/Controllers/FIRCLSMetricKitManager.h"
#import "Crashlytics/Crashlytics/Helpers/FIRCLSFile.h"
#import "Crashlytics/Crashlytics/Models/FIRCLSExecutionIdentifierModel.h"
#import "Crashlytics/Crashlytics/Models/FIRCLSInternalReport.h"
#import "Crashlytics/Crashlytics/Public/FirebaseCrashlytics/FIRCrashlyticsReport.h"

@interface FIRCLSMetricKitManager () {
  NSLock *_mutex;
  FBLPromise *_metricKitDataAvailable;
  FIRCLSExistingReportManager *_existingReportManager;
  FIRCLSFileManager *_fileManager;
  FIRCLSManagerData *_managerData;
}

@end

@implementation FIRCLSMetricKitManager

- (instancetype)initWithManagerData:(FIRCLSManagerData *)managerData
              existingReportManager:(FIRCLSExistingReportManager *)existingReportManager
                        fileManager:(FIRCLSFileManager *)fileManager {
  _existingReportManager = existingReportManager;
  _fileManager = fileManager;
  _managerData = managerData;
  return self;
}

/*
 * Registers the MetricKit manager to receive MetricKit reports by adding self to the
 * MXMetricManager subscribers. Also initializes the promise that we'll use to ensure that any
 * MetricKit report files are included in Crashylytics fatal reports. If no crash occurred on the
 * last run of the app, this promise is immediately resolved so that the upload of any nonfatal
 * events can proceed.
 */
- (void)registerMetricKitManager {
  [[MXMetricManager sharedManager] addSubscriber:self];
  _metricKitDataAvailable = [FBLPromise pendingPromise];

  // If there was no crash on the last run of the app, then we aren't expecting a MetricKit
  // diagnostic report and should resolve the promise immediately.
  NSString *crashedMarkerFileName = [NSString stringWithUTF8String:FIRCLSCrashedMarkerFileName];
  NSString *crashedMarkerFileFullPath =
      [[_fileManager rootPath] stringByAppendingPathComponent:crashedMarkerFileName];
  if (![_fileManager fileExistsAtPath:crashedMarkerFileFullPath]) {
    [_mutex lock];
    [_metricKitDataAvailable fulfill:nil];
    [_mutex unlock];
  }
}

/*
 * This method receives diagnostic payloads from MetricKit whenever a fatal or nonfatal MetricKit
 * event occurs. If a fatal event, this method will be called when the app restarts. Since we're
 * including a MetricKit report file in the Crashlytics report to be sent to the backend, we need
 * to make sure that we process the payloads and write the included information to file before
 * the report is sent up. If this method is called due to a nonfatal event, it will be called
 * immediately after the event. Since we send nonfatal events on the next run of the app, we can
 * write out the information but won't need to resolve the promise.
 */
- (void)didReceiveDiagnosticPayloads:(NSArray<MXDiagnosticPayload *> *)payloads {
  NSUInteger payloadCount = [payloads count];
  FIRCLSDebugLog(@"[Crashlytics:Crash] received %lu diagnostic payloads from MetricKit",
                 payloadCount);

  if ([payloads count] == 0) {
    return;
  }

  MXDiagnosticPayload *diagnosticPayload = [payloads objectAtIndex:0];
  if (!diagnosticPayload) {
    return;
  }

  // TODO: Time stamp information is only available in begin and end time periods. Hopefully this is
  // updated with iOS 15.
  NSTimeInterval beginSecondsSince1970 = [diagnosticPayload.timeStampBegin timeIntervalSince1970];
  NSTimeInterval endSecondsSince1970 = [diagnosticPayload.timeStampEnd timeIntervalSince1970];

  // Get file path for the active reports directory.
  NSString *activePath = [[_fileManager activePath] stringByAppendingString:@"/"];

  // If newestReportID is nil or the file no longer exists, then this callback function was
  // triggered for nonfatal MetricKit events.
  NSString *newestUnsentReportID =
      [_existingReportManager.newestUnsentReport.reportID stringByAppendingString:@"/"];
  NSString *metricKitReportFile;
  BOOL fatal =
      (newestUnsentReportID != nil) && ([_fileManager fileExistsAtPath:metricKitReportFile]);

  // Set the metrickit path appropriately depending on whether the diagnostic report came from
  // a fatal or nonfatal event. If fatal, use the report from the last run of the app. Otherwise,
  // use the report for the current run.
  if (!fatal) {
    // TODO: write out thread names? We don't do this for nonfatals currently,
    // so it's okay to leave for now.
    NSString *currentReportID =
        [_managerData.executionIDModel.executionID stringByAppendingString:@"/"];
    metricKitReportFile = [[activePath stringByAppendingString:currentReportID]
        stringByAppendingString:FIRCLSMetricKitNonfatalReportFile];
  } else {
    metricKitReportFile = [[activePath stringByAppendingString:newestUnsentReportID]
        stringByAppendingString:FIRCLSMetricKitFatalReportFile];
  }

  // Need to copy the string passed to the log method or it causes a crash (GUI logging issue).
  FIRCLSDebugLog(@"file path %@ for MetricKit", [metricKitReportFile copy]);
  FIRCLSFile metricKitFile;
  if (!FIRCLSFileInitWithPath(&metricKitFile, [metricKitReportFile UTF8String], false)) {
    FIRCLSDebugLog("Unable to open MetricKit file");
    return;
  }

  // Write out time information to the MetricKit report file.
  FIRCLSFileWriteSectionStart(&metricKitFile, "time");
  FIRCLSFileWriteHashEntryUint64(&metricKitFile, "beginTime", beginSecondsSince1970);
  FIRCLSFileWriteHashEntryUint64(&metricKitFile, "endTime", endSecondsSince1970);
  FIRCLSFileWriteSectionEnd(&metricKitFile);

  // Write out each type of diagnostic if it exists in the report
  BOOL hasCrash = [diagnosticPayload.crashDiagnostics count] > 0;
  BOOL hasHang = [diagnosticPayload.hangDiagnostics count] > 0;
  BOOL hasCPUException = [diagnosticPayload.cpuExceptionDiagnostics count] > 0;
  BOOL hasDiskWriteException = [diagnosticPayload.diskWriteExceptionDiagnostics count] > 0;

  // For each diagnostic type, write out a section in the MetricKit report file. This section will
  // have subsections for threads, metadata, and event specific metadata.
  if (hasCrash) {
    FIRCLSFileWriteSectionStart(&metricKitFile, "crash event");
    MXCrashDiagnostic *crashDiagnostic = [diagnosticPayload.crashDiagnostics objectAtIndex:0];

    NSData *threads = [crashDiagnostic.callStackTree JSONRepresentation];
    NSData *metadata = [crashDiagnostic.metaData JSONRepresentation];
    [self writeThreadsToFile:&metricKitFile threads:threads];
    [self writeMetadataToFile:&metricKitFile metadata:metadata];

    NSString *nilString = @"";
    NSMutableDictionary *crashDict = @{
      @"termination reason" :
              (crashDiagnostic.terminationReason) ? crashDiagnostic.terminationReason : nilString,
      @"virtual memory region info" : (crashDiagnostic.virtualMemoryRegionInfo)
          ? crashDiagnostic.virtualMemoryRegionInfo
          : nilString,
      @"exception type" : crashDiagnostic.exceptionType,
      @"exception code" : crashDiagnostic.exceptionCode,
      @"signal" : crashDiagnostic.signal
    };
    [self writeEventSpecificDataToFile:&metricKitFile event:@"crash" data:crashDict];

    FIRCLSFileWriteSectionEnd(&metricKitFile);
  }

  if (hasHang) {
    FIRCLSFileWriteSectionStart(&metricKitFile, "hang event");
    MXHangDiagnostic *hangDiagnostic = [diagnosticPayload.hangDiagnostics objectAtIndex:0];

    NSData *threads = [hangDiagnostic.callStackTree JSONRepresentation];
    NSData *metadata = [hangDiagnostic.metaData JSONRepresentation];
    [self writeThreadsToFile:&metricKitFile threads:threads];
    [self writeMetadataToFile:&metricKitFile metadata:metadata];

    NSDictionary *hangDict = @{@"hang duration" : hangDiagnostic.hangDuration};
    [self writeEventSpecificDataToFile:&metricKitFile event:@"hang" data:hangDict];

    FIRCLSFileWriteSectionEnd(&metricKitFile);
  }

  if (hasCPUException) {
    FIRCLSFileWriteSectionStart(&metricKitFile, "CPU exception event");
    MXCPUExceptionDiagnostic *cpuExceptionDiagnostic =
        [diagnosticPayload.cpuExceptionDiagnostics objectAtIndex:0];

    NSData *threads = [cpuExceptionDiagnostic.callStackTree JSONRepresentation];
    NSData *metadata = [cpuExceptionDiagnostic.metaData JSONRepresentation];
    [self writeThreadsToFile:&metricKitFile threads:threads];
    [self writeMetadataToFile:&metricKitFile metadata:metadata];

    NSDictionary *cpuDict = @{
      @"total CPU time" : cpuExceptionDiagnostic.totalCPUTime,
      @"total sampled time" : cpuExceptionDiagnostic.totalSampledTime
    };
    [self writeEventSpecificDataToFile:&metricKitFile event:@"CPU exception" data:cpuDict];

    FIRCLSFileWriteSectionEnd(&metricKitFile);
  }

  if (hasDiskWriteException) {
    FIRCLSFileWriteSectionStart(&metricKitFile, "disk write exception event");
    MXDiskWriteExceptionDiagnostic *diskWriteExceptionDiagnostic =
        [diagnosticPayload.diskWriteExceptionDiagnostics objectAtIndex:0];

    NSData *threads = [diskWriteExceptionDiagnostic.callStackTree JSONRepresentation];
    NSData *metadata = [diskWriteExceptionDiagnostic.metaData JSONRepresentation];
    [self writeThreadsToFile:&metricKitFile threads:threads];
    [self writeMetadataToFile:&metricKitFile metadata:metadata];

    NSDictionary *diskDict =
        @{@"total writes caused" : diskWriteExceptionDiagnostic.totalWritesCaused};
    [self writeEventSpecificDataToFile:&metricKitFile event:@"disk write exception" data:diskDict];

    FIRCLSFileWriteSectionEnd(&metricKitFile);
  }

  // If this method was called because of a fatal event, fulfill the MetricKit promise so that
  // uploading of the Crashlytics report continues. If not, the promise has already been fulfillled.
  if (fatal) {
    [_mutex lock];
    [_metricKitDataAvailable fulfill:nil];
    [_mutex unlock];
  }
}

/*
 * Required for MXMetricManager subscribers. Since we aren't currently collecting any MetricKit
 * metrics, this method is left empty.
 */
- (void)didReceiveMetricPayloads:(NSArray<MXMetricPayload *> *)payloads {
  FIRCLSDebugLog(@"[Crashlytics:Crash] received %d MetricKit metric payloads\n", payloads.count);
}

- (FBLPromise *)waitForMetricKitDataAvailable {
  FBLPromise *result = nil;
  [_mutex lock];
  result = _metricKitDataAvailable;
  [_mutex unlock];
  return result;
}

/*
 * Helper method to write threads for a MetricKit diagnostic event to file.
 */
- (void)writeThreadsToFile:(FIRCLSFile *)metricKitFile threads:(NSData *)threads {
  FIRCLSFileWriteSectionStart(metricKitFile, "threads");
  NSMutableString *threadsString = [[NSMutableString alloc] initWithData:threads
                                                                encoding:NSUTF8StringEncoding];
  [threadsString replaceOccurrencesOfString:@"\n"
                                 withString:@""
                                    options:NSCaseInsensitiveSearch
                                      range:NSMakeRange(0, [threadsString length])];
  [threadsString replaceOccurrencesOfString:@" "
                                 withString:@""
                                    options:NSCaseInsensitiveSearch
                                      range:NSMakeRange(0, [threadsString length])];
  FIRCLSFileWriteStringUnquoted(metricKitFile, [threadsString UTF8String]);
  FIRCLSFileWriteSectionEnd(metricKitFile);
}

/*
 * Helper method to write metadata for a MetricKit diagnostic event to file.
 */
- (void)writeMetadataToFile:(FIRCLSFile *)metricKitFile metadata:(NSData *)metadata {
  FIRCLSFileWriteSectionStart(metricKitFile, "metadata");
  NSMutableString *metadataString = [[NSMutableString alloc] initWithData:metadata
                                                                 encoding:NSUTF8StringEncoding];
  [metadataString replaceOccurrencesOfString:@"\n"
                                  withString:@""
                                     options:NSCaseInsensitiveSearch
                                       range:NSMakeRange(0, [metadataString length])];
  [metadataString replaceOccurrencesOfString:@"\t"
                                  withString:@""
                                     options:NSCaseInsensitiveSearch
                                       range:NSMakeRange(0, [metadataString length])];
  FIRCLSFileWriteStringUnquoted(metricKitFile, [metadataString UTF8String]);
  FIRCLSFileWriteSectionEnd(metricKitFile);
}

/*
 * Helper method to write event-specific metadata for a MetricKit diagnostic event to file.
 */
- (void)writeEventSpecificDataToFile:(FIRCLSFile *)metricKitFile
                               event:(NSString *)event
                                data:(NSDictionary *)data {
  NSString *eventName = [event stringByAppendingString:@" information"];
  FIRCLSFileWriteSectionStart(metricKitFile, [eventName UTF8String]);
  FIRCLSFileWriteHashStart(metricKitFile);

  for (NSString *key in data) {
    id value = [data objectForKey:key];
    if ([value isKindOfClass:[NSString class]]) {
      const char *stringValue = [(NSString *)value UTF8String];
      FIRCLSFileWriteHashEntryString(metricKitFile, [key UTF8String], stringValue);
    } else if ([value isKindOfClass:[NSNumber class]]) {
      int intValue = (int)value;
      FIRCLSFileWriteHashEntryUint64(metricKitFile, [key UTF8String],
                                     [[data objectForKey:key] integerValue]);
    }
  };

  FIRCLSFileWriteHashEnd(metricKitFile);
  FIRCLSFileWriteSectionEnd(metricKitFile);
}

@end

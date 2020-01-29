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

#import "FIRCLSRecordAdapter.h"
#import "FIRCLSRecordAdapter_Private.h"

#import "FIRCLSInternalReport.h"
#import "FIRCLSLogger.h"

@implementation FIRCLSRecordAdapter

- (instancetype)initWithPath:(NSString *)folderPath {
  self = [super init];
  if (self) {
    _folderPath = folderPath;

    [self loadBinaryImagesFile];
    [self loadMetaDataFile];
    [self loadSignalFile];
    [self loadKeyValuesFile];
  }
  return self;
}

- (void)loadBinaryImagesFile {
  NSString *path = [self.folderPath stringByAppendingPathComponent:FIRCLSReportBinaryImageFile];
  self.binaryImages = [FIRCLSRecordBinaryImage
      binaryImagesFromDictionaries:[FIRCLSRecordAdapter dictionariesFromEachLineOfFile:path]];
}

- (void)loadMetaDataFile {
  NSString *path = [self.folderPath stringByAppendingPathComponent:FIRCLSReportMetadataFile];
  NSDictionary *dict = [FIRCLSRecordAdapter combinedDictionariesFromFilePath:path];

  self.identity = [[FIRCLSRecordIdentity alloc] initWithDict:dict[@"identity"]];
  self.host = [[FIRCLSRecordHost alloc] initWithDict:dict[@"host"]];
  self.application = [[FIRCLSRecordApplication alloc] initWithDict:dict[@"application"]];
  self.executable = [[FIRCLSRecordExecutable alloc] initWithDict:dict[@"executable"]];
}

- (void)loadSignalFile {
  NSString *path = [self.folderPath stringByAppendingPathComponent:FIRCLSReportSignalFile];
  NSDictionary *dicts = [FIRCLSRecordAdapter combinedDictionariesFromFilePath:path];

  self.signal = [[FIRCLSRecordSignal alloc] initWithDict:dicts[@"signal"]];
  self.runtime = [[FIRCLSRecordRuntime alloc] initWithDict:dicts[@"runtime"]];
  self.processStats = [[FIRCLSRecordProcessStats alloc] initWithDict:dicts[@"process_stats"]];
  self.storage = [[FIRCLSRecordStorage alloc] initWithDict:dicts[@"storage"]];

  // The thread's objc_selector_name is set with the runtime's info
  self.threads = [FIRCLSRecordThread threadsFromDictionaries:dicts[@"threads"]
                                             withThreadNames:dicts[@"thread_names"]
                                      withDispatchQueueNames:dicts[@"dispatch_queue_names"]
                                                 withRuntime:self.runtime];
}

- (void)loadKeyValuesFile {
  NSString *path =
      [self.folderPath stringByAppendingPathComponent:FIRCLSReportInternalIncrementalKVFile];
  self.keyValues = [FIRCLSRecordKeyValue
      keyValuesFromDictionaries:[FIRCLSRecordAdapter dictionariesFromEachLineOfFile:path]];
}

/// Return the persisted crash file as a combined dictionary that way lookups can occur with a key
/// (to avoid ordering dependency)
/// @param filePath Persisted crash file path
+ (NSDictionary *)combinedDictionariesFromFilePath:(NSString *)filePath {
  NSMutableDictionary *joinedDict = [[NSMutableDictionary alloc] init];
  for (NSDictionary *dict in [self dictionariesFromEachLineOfFile:filePath]) {
    [joinedDict addEntriesFromDictionary:dict];
  }
  return joinedDict;
}

/// The persisted crash files contains JSON on separate lines. Read each line and return the JSON
/// data as a dictionary.
/// @param filePath Persisted crash file path
+ (NSArray<NSDictionary *> *)dictionariesFromEachLineOfFile:(NSString *)filePath {
  NSString *content = [[NSString alloc] initWithContentsOfFile:filePath
                                                      encoding:NSUTF8StringEncoding
                                                         error:nil];
  NSArray *lines =
      [content componentsSeparatedByCharactersInSet:NSCharacterSet.newlineCharacterSet];

  NSMutableArray<NSDictionary *> *array = [[NSMutableArray<NSDictionary *> alloc] init];

  int lineNum = 1;
  for (NSString *line in lines) {
    NSError *error;
    NSDictionary *dict =
        [NSJSONSerialization JSONObjectWithData:[line dataUsingEncoding:NSUTF8StringEncoding]
                                        options:0
                                          error:&error];

    if (error) {
      FIRCLSErrorLog(@"Failed to read JSON from file (%@) line (%d) with error: %@", filePath,
                     lineNum, error);
    } else {
      [array addObject:dict];
    }

    lineNum++;
  }

  return array;
}

- (BOOL)hasCrashed {
    for (FIRCLSRecordThread *thread in self.threads) {
        if (thread.crashed) {
            return true;
        }
    }
    
    return false;
}

- (google_crashlytics_Report)nanoPBReportWithGoogleAppID:(NSString *)googleAppID {
    google_crashlytics_Report report = google_crashlytics_Report_init_default;
    report.build_version = FIRCLSEncodeString(self.identity.build_version);
    report.gmp_app_id = FIRCLSEncodeString(googleAppID);
    report.platform = [self nanoPBPlatformFromString:self.host.platform];
    report.installation_uuid = FIRCLSEncodeString(self.identity.install_id);
    report.build_version = FIRCLSEncodeString(self.application.build_version);
    report.display_version = FIRCLSEncodeString(self.application.display_version);
    
    // TODO: Fix missing session payload in report
    // report.session = ...
    
    return report;
}

- (google_crashlytics_Session)nanoPBSession {
    google_crashlytics_Session session = google_crashlytics_Session_init_default;
    session.generator = FIRCLSEncodeString(self.identity.generator);
    session.identifier = FIRCLSEncodeString(self.identity.session_id);
    session.started_at = 0; // TODO: Where does this come from?
    session.ended_at = self.signal.time;
    session.crashed = [self hasCrashed];
    
    return session;
}

- (google_crashlytics_Session_User)nanoPBUser {
    google_crashlytics_Session_User user = google_crashlytics_Session_User_init_default;
//    user = FIRCLSEncodeString(self.)
    return user;
}


- (google_crashlytics_Session_Platform)nanoPBPlatformFromString:(NSString *)str {
    if ([str isEqualToString:@"ios"]) {
        return google_crashlytics_Session_Platform_IPHONE_OS;
    } else if ([str isEqualToString:@"mac"]) {
        return google_crashlytics_Session_Platform_MAC_OS_X;
    } else if ([str isEqualToString:@"tvos"]) {
        return google_crashlytics_Session_Platform_TVOS;
    } else {
        return google_crashlytics_Session_Platform_OTHER;
    }
}

/** Mallocs a pb_bytes_array and copies the given NSString's bytes into the bytes array.
 *
 * @note Memory needs to be free manually, through pb_free or pb_release.
 * @param string The string to encode as pb_bytes.
 */
pb_bytes_array_t *FIRCLSEncodeString(NSString *string) {
  NSData *stringBytes = [string dataUsingEncoding:NSUTF8StringEncoding];
  return FIRCLSEncodeData(stringBytes);
}

/** Mallocs a pb_bytes_array and copies the given NSData bytes into the bytes array.
 *
 * @note Memory needs to be free manually, through pb_free or pb_release.
 * @param data The data to copy into the new bytes array.
 */
pb_bytes_array_t *FIRCLSEncodeData(NSData *data) {
  pb_bytes_array_t *pbBytes = malloc(PB_BYTES_ARRAY_T_ALLOCSIZE(data.length));
  memcpy(pbBytes->bytes, [data bytes], data.length);
  pbBytes->size = (pb_size_t)data.length;
  return pbBytes;
}

@end

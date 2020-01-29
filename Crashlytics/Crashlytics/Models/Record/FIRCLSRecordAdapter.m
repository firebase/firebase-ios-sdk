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

@end

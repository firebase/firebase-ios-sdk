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
#import "FIRCLSReportAdapter_Private.h"

#import "FIRCLSInternalReport.h"
#import "FIRCLSLogger.h"

#import "FIRCLSUserLogging.h"

#import <nanopb/pb.h>
#import <nanopb/pb_decode.h>
#import <nanopb/pb_encode.h>

@implementation FIRCLSReportAdapter

- (instancetype)initWithPath:(NSString *)folderPath
                 googleAppId:(NSString *)googleAppID
                       orgId:(NSString *)orgID {
  self = [super init];
  if (self) {
    _folderPath = folderPath;
    _googleAppID = googleAppID;
    _orgID = orgID;

    [self loadBinaryImagesFile];
    [self loadMetaDataFile];
    [self loadSignalFile];
    [self loadInternalKeyValuesFile];
    [self loadUserKeyValuesFile];
    [self loadUserLogFiles];
    [self loadErrorFiles];

    // TODO: Add support for mach_exception.clsrecord (check Protobuf.scala:524)
    // TODO: When implemented, add support for custom exceptions: custom_exception_a/b.clsrecord

    _report = [self protoReport];
  }
  return self;
}

- (void)dealloc {
  pb_release(google_crashlytics_Report_fields, &_report);
}

//
// MARK: Load from persisted crash files
//

/// Reads from binary_images.clsrecord
- (void)loadBinaryImagesFile {
  NSString *path = [self.folderPath stringByAppendingPathComponent:FIRCLSReportBinaryImageFile];
  self.binaryImages = [FIRCLSRecordBinaryImage
      binaryImagesFromDictionaries:[FIRCLSReportAdapter dictionariesFromEachLineOfFile:path]];
}

/// Reads from metadata.clsrecord
- (void)loadMetaDataFile {
  NSString *path = [self.folderPath stringByAppendingPathComponent:FIRCLSReportMetadataFile];
  NSDictionary *dict = [FIRCLSReportAdapter combinedDictionariesFromFilePath:path];

  self.identity = [[FIRCLSRecordIdentity alloc] initWithDict:dict[@"identity"]];
  self.host = [[FIRCLSRecordHost alloc] initWithDict:dict[@"host"]];
  self.application = [[FIRCLSRecordApplication alloc] initWithDict:dict[@"application"]];
  self.executable = [[FIRCLSRecordExecutable alloc] initWithDict:dict[@"executable"]];
}

/// Reads from signal.clsrecord (does not always exist, written when there is a crash)
- (void)loadSignalFile {
  NSString *path = [self.folderPath stringByAppendingPathComponent:FIRCLSReportSignalFile];
  NSDictionary *dicts = [FIRCLSReportAdapter combinedDictionariesFromFilePath:path];

  self.signal = [[FIRCLSRecordSignal alloc] initWithDict:dicts[@"signal"]];
  self.runtime = [[FIRCLSRecordRuntime alloc] initWithDict:dicts[@"runtime"]];
  self.processStats = [[FIRCLSRecordProcessStats alloc] initWithDict:dicts[@"process_stats"]];
  self.storage = [[FIRCLSRecordStorage alloc] initWithDict:dicts[@"storage"]];

  // The thread's objc_selector_name is set with the runtime's info
  self.threads = [FIRCLSRecordThread threadsFromDictionaries:dicts[@"threads"]
                                                 threadNames:dicts[@"thread_names"]
                                      withDispatchQueueNames:dicts[@"dispatch_queue_names"]
                                                 withRuntime:self.runtime];
}

/// Reads from internal_incremental_kv.clsrecord
- (void)loadInternalKeyValuesFile {
  NSString *path =
      [self.folderPath stringByAppendingPathComponent:FIRCLSReportInternalIncrementalKVFile];
  self.internalKeyValues = [FIRCLSRecordKeyValue
      keyValuesFromDictionaries:[FIRCLSReportAdapter dictionariesFromEachLineOfFile:path]];
}

/// Reads from internal_incremental_kv.clsrecord
- (void)loadUserKeyValuesFile {
  NSString *path =
      [self.folderPath stringByAppendingPathComponent:FIRCLSReportUserIncrementalKVFile];
  self.userKeyValues = [FIRCLSRecordKeyValue
      keyValuesFromDictionaries:[FIRCLSReportAdapter dictionariesFromEachLineOfFile:path]];
}

/// If too many logs are written, then a file (log_a.clsrecord) rollover occurs.
/// Then a secondary log file (log_b.clsrecord) is created.
- (void)loadUserLogFiles {
  NSString *logA = [self.folderPath stringByAppendingPathComponent:FIRCLSReportLogAFile];
  NSString *logB = [self.folderPath stringByAppendingPathComponent:FIRCLSReportLogBFile];

  NSMutableArray<FIRCLSRecordLog *> *logs = [[NSMutableArray<FIRCLSRecordLog *> alloc] init];

  if ([[NSFileManager defaultManager] fileExistsAtPath:logA]) {
    [logs addObjectsFromArray:[FIRCLSRecordLog
                                  logsFromDictionaries:[FIRCLSReportAdapter
                                                           dictionariesFromEachLineOfFile:logA]]];
  }

  if ([[NSFileManager defaultManager] fileExistsAtPath:logB]) {
    [logs addObjectsFromArray:[FIRCLSRecordLog
                                  logsFromDictionaries:[FIRCLSReportAdapter
                                                           dictionariesFromEachLineOfFile:logB]]];
  }

  self.userLogs = logs;
}

/// Load errors.
- (void)loadErrorFiles {
  NSString *errorA = [self.folderPath stringByAppendingPathComponent:FIRCLSReportErrorAFile];
  NSString *errorB = [self.folderPath stringByAppendingPathComponent:FIRCLSReportErrorBFile];

  NSMutableArray<FIRCLSRecordError *> *errors = [[NSMutableArray<FIRCLSRecordError *> alloc] init];

  if ([[NSFileManager defaultManager] fileExistsAtPath:errorA]) {
    [errors
        addObjectsFromArray:[FIRCLSRecordError
                                errorsFromDictionaries:[FIRCLSReportAdapter
                                                           dictionariesFromEachLineOfFile:errorA]]];
  }

  if ([[NSFileManager defaultManager] fileExistsAtPath:errorB]) {
    [errors
        addObjectsFromArray:[FIRCLSRecordError
                                errorsFromDictionaries:[FIRCLSReportAdapter
                                                           dictionariesFromEachLineOfFile:errorB]]];
  }

  self.errors = errors;
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

  int lineNum = 0;
  for (NSString *line in lines) {
    lineNum++;

    if (line.length == 0) {
      // Likely newline at the end of the file
      continue;
    }

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
  }

  return array;
}

//
// MARK: GDTCOREventDataObject
//

- (NSData *)transportBytes {
  pb_ostream_t sizestream = PB_OSTREAM_SIZING;

  // Encode 1 time to determine the size.
  if (!pb_encode(&sizestream, google_crashlytics_Report_fields, &_report)) {
    FIRCLSErrorLog(@"Error in nanopb encoding for size: %s", PB_GET_ERROR(&sizestream));
  }

  // Encode a 2nd time to actually get the bytes from it.
  size_t bufferSize = sizestream.bytes_written;
  CFMutableDataRef dataRef = CFDataCreateMutable(CFAllocatorGetDefault(), bufferSize);
  CFDataSetLength(dataRef, bufferSize);
  pb_ostream_t ostream = pb_ostream_from_buffer((void *)CFDataGetBytePtr(dataRef), bufferSize);
  if (!pb_encode(&ostream, google_crashlytics_Report_fields, &_report)) {
    FIRCLSErrorLog(@"Error in nanopb encoding for bytes: %s", PB_GET_ERROR(&ostream));
  }

  return CFBridgingRelease(dataRef);
}

//
// MARK: Report helper functions
//

// TODO: Add add logic for "development-platform-name", "development-platform-version" -
// Protobuf.scala:583

/// Returns if the app was last in the background
- (BOOL)wasInBackground {
  return [self.internalKeyValues[FIRCLSInBackgroundKey] boolValue];
}

/// Return the last device orientation
- (int)deviceOrientation {
  return [self.internalKeyValues[FIRCLSDeviceOrientationKey] intValue];
}

/// Return the last UI orientation
- (int)uiOrientation {
  return [self.internalKeyValues[FIRCLSUIOrientationKey] intValue];
}

/// Return if the app crashed
- (BOOL)hasCrashed {
  NSString *signalFile = [self.folderPath stringByAppendingPathComponent:FIRCLSReportSignalFile];
  return [[NSFileManager defaultManager] fileExistsAtPath:signalFile];
}

- (NSUInteger)ramUsed {
  return self.processStats.active + self.processStats.inactive + self.processStats.wired;
}

- (BOOL)isJailbroken {
  __block NSArray<NSString *> *knownJailbrokenLibraries;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    knownJailbrokenLibraries = @[ @"mobilesubstrate", @"libsubstrate", @"cydia" ];
  });

  for (FIRCLSRecordBinaryImage *image in self.binaryImages) {
    for (NSString *knownLib in knownJailbrokenLibraries) {
      if ([image.path.lowercaseString isEqualToString:knownLib]) {
        return true;
      }
    }
  }

  return false;
}

- (NSDictionary<NSString *, NSString *> *)keyValuesWithError:(FIRCLSRecordError *)error {
  if (!error) {
    return self.userKeyValues;
  }

  NSMutableDictionary<NSString *, NSString *> *kvs = [self.userKeyValues mutableCopy];
  kvs[@"nserror-domain"] = error.domain;
  kvs[@"nserror-code"] = [NSString stringWithFormat:@"%li", (long)error.code];

  return kvs;
}

- (NSString *)logsContent {
  // Example of how the result should look like:
  // "4175 $ custom_log_msg_1\n5830 $ custom_log_msg_2\n5835 $ custom_log_msg_3"
  // The number is elapsed time from the start of the app
  static NSString *logMessageFormat = @"%tu $ %@\n";

  if (self.userLogs.count == 0) {
    return @"";
  }

  NSMutableString *content = [NSMutableString string];
  for (FIRCLSRecordLog *log in self.userLogs) {
    NSUInteger elapsedTimeFromStartTime =
        log.time - (self.identity.started_at * 1000);  // started_at needs to be in milliseconds
    [content appendFormat:logMessageFormat, elapsedTimeFromStartTime, log.msg];
  }

  // Remove the last newline character
  return [content substringToIndex:[content length] - 1];
}

//
// MARK: NanoPB conversions
//

// NOTE: With nanopb using proto2, for optional primitives fields, setting the value is not enough
// to have the field be included in the proto. You will have to set .has_{field_name} = true.
// Ex: session.ended_at = true; (assume ended_at is a optional uint64)

- (google_crashlytics_Report)protoReport {
  google_crashlytics_Report report = google_crashlytics_Report_init_default;
  report.sdk_version = FIRCLSEncodeString(self.identity.build_version);
  report.gmp_app_id = FIRCLSEncodeString(self.googleAppID);
  report.platform = [self protoPlatformFromString:self.host.platform];
  report.installation_uuid = FIRCLSEncodeString(self.identity.install_id);
  report.build_version = FIRCLSEncodeString(self.application.build_version);
  report.display_version = FIRCLSEncodeString(self.application.display_version);
  report.session = [self protoSession];
  return report;
}

- (google_crashlytics_Session)protoSession {
  google_crashlytics_Session session = google_crashlytics_Session_init_default;
  session.generator = FIRCLSEncodeString(self.identity.generator);
  session.identifier = FIRCLSEncodeString(self.identity.session_id);
  session.started_at = self.identity.started_at;

  session.ended_at = self.signal.time;
  session.has_ended_at = true;

  session.crashed = [self hasCrashed];
  session.has_crashed = true;

  session.app = [self protoSessionApplication];

  session.os = [self protoOperatingSystem];
  session.has_os = true;

  session.device = [self protoSessionDevice];
  session.has_device = true;

  session.generator_type = [self protoGeneratorTypeFromString:self.host.platform];
  session.has_generator_type = true;

  NSString *userId = self.internalKeyValues[FIRCLSUserIdentifierKey];
  if (userId) {
    session.user = [self protoUserWithId:userId];
  }
  session.has_user = true;

  session.events = [self protoEvents];
  session.events_count = (pb_size_t)[self numberOfEvents];

  return session;
}

- (google_crashlytics_Session_User)protoUserWithId:(NSString *)identifier {
  google_crashlytics_Session_User user = google_crashlytics_Session_User_init_default;
  user.identifier = FIRCLSEncodeString(identifier);
  return user;
}

- (google_crashlytics_Session_Application)protoSessionApplication {
  google_crashlytics_Session_Application app = google_crashlytics_Session_Application_init_default;
  app.identifier = FIRCLSEncodeString(self.application.bundle_id);
  app.version = FIRCLSEncodeString(self.application.build_version);
  app.display_version = FIRCLSEncodeString(self.application.display_version);
  app.organization = [self protoOrganization];
  app.has_organization = true;
  return app;
}

- (google_crashlytics_Session_Application_Organization)protoOrganization {
  google_crashlytics_Session_Application_Organization org =
      google_crashlytics_Session_Application_Organization_init_default;
  org.cls_id = FIRCLSEncodeString(self.orgID);
  return org;
}

- (google_crashlytics_Session_OperatingSystem)protoOperatingSystem {
  google_crashlytics_Session_OperatingSystem os =
      google_crashlytics_Session_OperatingSystem_init_default;
  os.platform = [self protoPlatformFromString:self.host.platform];
  os.version = FIRCLSEncodeString(self.host.os_display_version);
  os.build_version = FIRCLSEncodeString(self.host.os_build_version);
  os.jailbroken = [self isJailbroken];
  os.has_jailbroken = true;
  return os;
}

- (google_crashlytics_Session_Device)protoSessionDevice {
  google_crashlytics_Session_Device device = google_crashlytics_Session_Device_init_default;
  device.arch = [self protoArchitectureFromString:self.executable.architecture];
  device.model = FIRCLSEncodeString(self.host.model);
  device.ram = [self ramUsed];
  device.has_ram = true;
  device.disk_space = self.storage.total;
  device.has_disk_space = true;
  device.language = FIRCLSEncodeString(self.host.locale);
  return device;
}

- (NSUInteger)numberOfEvents {
  NSUInteger sum = [self hasCrashed] ? 1 : 0;
  sum += self.errors.count;
  return sum;
}

- (google_crashlytics_Session_Event *)protoEvents {
  // TODO: Add custom exceptions (when supported)
  NSUInteger numberOfEvents = [self numberOfEvents];

  // Add recorded error events
  google_crashlytics_Session_Event *events =
      malloc(sizeof(google_crashlytics_Session_Event) * numberOfEvents);

  for (NSUInteger i = 0; i < self.errors.count; i++) {
    events[i] = [self protoEventForError:self.errors[i]];
  }

  // Add crash event
  if ([self hasCrashed]) {
    events[numberOfEvents - 1] = [self protoEventForCrash];
  }

  return events;
}

- (google_crashlytics_Session_Event)protoEventForCrash {
  google_crashlytics_Session_Event crash = google_crashlytics_Session_Event_init_default;
  crash.timestamp = self.signal.time;
  crash.type = FIRCLSEncodeString(@"crashed");

  crash.app = [self protoEventApplicationForCrash];
  crash.has_app = true;

  crash.device = [self protoEventDevice];
  crash.has_device = true;

  crash.log.content = FIRCLSEncodeString([self logsContent]);
  crash.has_log = true;

  return crash;
}

- (google_crashlytics_Session_Event)protoEventForError:(FIRCLSRecordError *)recordedError {
  google_crashlytics_Session_Event error = google_crashlytics_Session_Event_init_default;
  error.timestamp = recordedError.time;
  error.type = FIRCLSEncodeString(@"error");
  error.app = [self protoEventApplicationForError:recordedError];
  error.has_app = true;
  error.device = [self protoEventDevice];
  error.has_device = true;
  error.log.content = FIRCLSEncodeString([self logsContent]);
  error.has_log = true;
  return error;
}

- (google_crashlytics_Session_Event_Application)protoEventApplicationForCrash {
  google_crashlytics_Session_Event_Application app =
      google_crashlytics_Session_Event_Application_init_default;

  app.execution.binaries = [self protoBinaryImages];
  app.execution.binaries_count = (pb_size_t)self.binaryImages.count;
  app.execution.signal = [self protoSignal];
  app.execution.threads = [self protoThreadsWithArray:self.threads];
  app.execution.threads_count = (pb_size_t)self.threads.count;

  app.background = [self wasInBackground];
  app.has_background = true;

  app.ui_orientation = [self uiOrientation];
  app.ui_orientation = true;

  // TODO: Add crash_info_entry values for Swift, Protobuf.scala:444
  app.custom_attributes = [self protoCustomAttributesWithKeyValues:self.userKeyValues];
  app.custom_attributes_count = (pb_size_t)self.userKeyValues.count;

  return app;
}

- (google_crashlytics_Session_Event_Application)protoEventApplicationForError:
    (FIRCLSRecordError *)error {
  google_crashlytics_Session_Event_Application app =
      google_crashlytics_Session_Event_Application_init_default;

  // TODO: Filter by binaries by stacktrace, Protobuf.scala:93
  app.execution.binaries = [self protoBinaryImages];
  app.execution.binaries_count = (pb_size_t)self.binaryImages.count;

  google_crashlytics_Session_Event_Application_Execution_Signal emptySignal =
      google_crashlytics_Session_Event_Application_Execution_Signal_init_default;
  app.execution.signal = emptySignal;

  // Create single thread from stacktrace
  google_crashlytics_Session_Event_Application_Execution_Thread *threads =
      malloc(sizeof(google_crashlytics_Session_Event_Application_Execution_Thread) * 1);
  google_crashlytics_Session_Event_Application_Execution_Thread thread =
      google_crashlytics_Session_Event_Application_Execution_Thread_init_default;
  thread.frames = [self protoFramesWithStacktrace:error.stacktrace
                                 threadImportance:thread.importance];
  thread.frames_count = (pb_size_t)error.stacktrace.count;
  threads[0] = thread;
  app.execution.threads = threads;
  app.execution.threads_count = 1;

  app.background = [self wasInBackground];
  app.has_background = true;

  app.ui_orientation = [self uiOrientation];
  app.has_ui_orientation = true;

  NSDictionary<NSString *, NSString *> *keyValues = [self keyValuesWithError:error];
  app.custom_attributes = [self protoCustomAttributesWithKeyValues:keyValues];
  app.custom_attributes_count = (pb_size_t)keyValues.count;

  return app;
}

/// Generate an array of CustomAttributes from the user defined key values.
/// For recorded errors, the error's nserror-domain and nserror-code are also added.
/// @param keyValues Dictionary of custom attributes
- (google_crashlytics_CustomAttribute *)protoCustomAttributesWithKeyValues:
    (NSDictionary<NSString *, NSString *> *)keyValues {
  google_crashlytics_CustomAttribute *attributes =
      malloc(sizeof(google_crashlytics_CustomAttribute) * keyValues.allKeys.count);

  for (NSUInteger i = 0; i < keyValues.allKeys.count; i++) {
    google_crashlytics_CustomAttribute attribute = google_crashlytics_CustomAttribute_init_default;
    NSString *key = keyValues.allKeys[i];
    attribute.key = FIRCLSEncodeString(key);
    attribute.value = FIRCLSEncodeString(keyValues[key]);
    attributes[i] = attribute;
  }

  return attributes;
}

- (google_crashlytics_Session_Event_Application_Execution_Thread *)protoThreadsWithArray:
    (NSArray<FIRCLSRecordThread *> *)array {
  google_crashlytics_Session_Event_Application_Execution_Thread *threads =
      malloc(sizeof(google_crashlytics_Session_Event_Application_Execution_Thread) * array.count);

  for (NSUInteger i = 0; i < array.count; i++) {
    google_crashlytics_Session_Event_Application_Execution_Thread thread =
        google_crashlytics_Session_Event_Application_Execution_Thread_init_default;

    thread.name = FIRCLSEncodeString(array[i].name);
    thread.importance = array[i].importance;  // TODO: Update frame importance for exceptions. Protobuf.scala:384
    thread.alternate_name = FIRCLSEncodeString(array[i].alternate_name);
    thread.objc_selector_name = FIRCLSEncodeString(array[i].objc_selector_name);

    thread.frames = [self protoFramesWithStacktrace:array[i].stacktrace
                                   threadImportance:thread.importance];
    thread.frames_count = (pb_size_t)array[i].stacktrace.count;

    thread.registers = [self protoRegistersWithArray:array[i].registers];
    thread.registers_count = (pb_size_t)array[i].registers.count;

    threads[i] = thread;
  }

  return threads;
}

- (google_crashlytics_Session_Event_Application_Execution_Thread_Frame *)
    protoFramesWithStacktrace:(NSArray<NSNumber *> *)stacktrace
             threadImportance:(NSUInteger)importance {
  google_crashlytics_Session_Event_Application_Execution_Thread_Frame *frames =
      malloc(sizeof(google_crashlytics_Session_Event_Application_Execution_Thread_Frame) *
             stacktrace.count);

  for (NSUInteger i = 0; i < stacktrace.count; i++) {
    google_crashlytics_Session_Event_Application_Execution_Thread_Frame frame =
        google_crashlytics_Session_Event_Application_Execution_Thread_Frame_init_default;
    frame.pc = stacktrace[i].unsignedIntegerValue;
    frame.importance = importance;
    frame.has_importance = true;
    frames[i] = frame;
  }

  return frames;
}

- (google_crashlytics_Session_Event_Application_Execution_Thread_Register *)protoRegistersWithArray:
    (NSArray<FIRCLSRecordRegister *> *)array {
  google_crashlytics_Session_Event_Application_Execution_Thread_Register *registers = malloc(
      sizeof(google_crashlytics_Session_Event_Application_Execution_Thread_Register) * array.count);

  for (NSUInteger i = 0; i < array.count; i++) {
    google_crashlytics_Session_Event_Application_Execution_Thread_Register reg =
        google_crashlytics_Session_Event_Application_Execution_Thread_Register_init_default;
    reg.name = FIRCLSEncodeString(array[i].name);
    reg.value = array[i].value;

    registers[i] = reg;
  }

  return registers;
}

- (google_crashlytics_Session_Event_Application_Execution_Signal)protoSignal {
  google_crashlytics_Session_Event_Application_Execution_Signal signal =
      google_crashlytics_Session_Event_Application_Execution_Signal_init_default;

  signal.address = self.signal.address;
  signal.code = FIRCLSEncodeString(self.signal.code_name);
  signal.name = FIRCLSEncodeString(self.signal.name);

  return signal;
}

- (google_crashlytics_Session_Event_Application_Execution_BinaryImage *)protoBinaryImages {
  google_crashlytics_Session_Event_Application_Execution_BinaryImage *images =
      malloc(sizeof(google_crashlytics_Session_Event_Application_Execution_BinaryImage) *
             self.binaryImages.count);

  for (NSUInteger i = 0; i < self.binaryImages.count; i++) {
    google_crashlytics_Session_Event_Application_Execution_BinaryImage image =
        google_crashlytics_Session_Event_Application_Execution_BinaryImage_init_default;
    image.name = FIRCLSEncodeString(self.binaryImages[i].path);
    image.uuid = FIRCLSEncodeString(self.binaryImages[i].uuid);
    image.base_address = self.binaryImages[i].base;
    image.size = self.binaryImages[i].size;

    // TODO: Fix analysis issue: "Use of zero-allocated memory"
    images[i] = image;
  }

  return images;
}

- (google_crashlytics_Session_Event_Device)protoEventDevice {
  google_crashlytics_Session_Event_Device device =
      google_crashlytics_Session_Event_Device_init_default;
  device.orientation = [self deviceOrientation];
  device.has_orientation = true;
  device.ram_used = [self ramUsed];
  device.has_ram_used = true;
  device.disk_used = self.storage.total - self.storage.free;
  device.has_disk_used = true;
  return device;
}

- (google_crashlytics_Session_Platform)protoPlatformFromString:(NSString *)str {
  NSString *platform = str.lowercaseString;

  if ([platform isEqualToString:@"ios"]) {
    return google_crashlytics_Session_Platform_IPHONE_OS;
  } else if ([platform isEqualToString:@"mac"]) {
    return google_crashlytics_Session_Platform_MAC_OS_X;
  } else if ([platform isEqualToString:@"tvos"]) {
    return google_crashlytics_Session_Platform_TVOS;
  } else {
    return google_crashlytics_Session_Platform_OTHER;
  }
}

- (google_crashlytics_Session_GeneratorType)protoGeneratorTypeFromString:(NSString *)str {
  NSString *platform = str.lowercaseString;

  if ([platform isEqualToString:@"ios"]) {
    return google_crashlytics_Session_GeneratorType_IOS_SDK;
  } else if ([platform isEqualToString:@"mac"]) {
    return google_crashlytics_Session_GeneratorType_MACOS_SDK;
  } else if ([platform isEqualToString:@"tvos"]) {
    return google_crashlytics_Session_GeneratorType_TVOS_SDK;
  } else {
    return google_crashlytics_Session_GeneratorType_UNKNOWN_GENERATOR;
  }
}

- (google_crashlytics_Session_Architecture)protoArchitectureFromString:(NSString *)str {
  NSString *arch = str.uppercaseString;

  if ([arch isEqualToString:@"X86_32"]) {
    return google_crashlytics_Session_Architecture_X86_32;
  } else if ([arch isEqualToString:@"X86_64"]) {
    return google_crashlytics_Session_Architecture_X86_64;
  } else if ([arch isEqualToString:@"ARM_UNKNOWN"]) {
    return google_crashlytics_Session_Architecture_ARM_UNKNOWN;
  } else if ([arch isEqualToString:@"ARMV6"]) {
    return google_crashlytics_Session_Architecture_ARMV6;
  } else if ([arch isEqualToString:@"ARMV7"]) {
    return google_crashlytics_Session_Architecture_ARMV7;
  } else if ([arch isEqualToString:@"ARM7S"]) {
    return google_crashlytics_Session_Architecture_ARMV7S;
  } else if ([arch isEqualToString:@"ARM64"]) {
    return google_crashlytics_Session_Architecture_ARM64;
  } else if ([arch isEqualToString:@"X86_64H"]) {
    return google_crashlytics_Session_Architecture_X86_64H;
  } else if ([arch isEqualToString:@"ARMV7K"]) {
    return google_crashlytics_Session_Architecture_ARMV7K;
  } else if ([arch isEqualToString:@"ARM64E"]) {
    return google_crashlytics_Session_Architecture_ARM64E;
  } else {
    return google_crashlytics_Session_Architecture_UNKNOWN;
  }
}

/** Mallocs a pb_bytes_array and copies the given NSString's bytes into the bytes array.
 * @note Memory needs to be free manually, through pb_free or pb_release.
 * @param string The string to encode as pb_bytes.
 */
pb_bytes_array_t *FIRCLSEncodeString(NSString *string) {
  NSString *stringToEncode = string ? string : @"";
  NSData *stringBytes = [stringToEncode dataUsingEncoding:NSUTF8StringEncoding];
  return FIRCLSEncodeData(stringBytes);
}

/** Mallocs a pb_bytes_array and copies the given NSData bytes into the bytes array.
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

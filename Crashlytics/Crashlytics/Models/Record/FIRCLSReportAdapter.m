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

- (instancetype)initWithPath:(NSString *)folderPath googleAppId:googleAppID {
  self = [super init];
  if (self) {
    _folderPath = folderPath;
    _googleAppID = googleAppID;

    [self loadBinaryImagesFile];
    [self loadMetaDataFile];
    [self loadInternalKeyValuesFile];
    [self loadUserKeyValuesFile];
    [self loadUserLogFiles];
    [self loadErrorFiles];

    [self loadAllCrashFiles];

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
  // TODO: Should sort? If so, sort inside FIRCLSRecordBinaryImage. Protobuf:253
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

/// Reads from all the possible crash files, and fills in the data whenever they exist. Crash files
/// only exist for certain types of crashes. (eg. exception.clsrecord is only written when an
/// uncaught exception crashed the app).
- (void)loadAllCrashFiles {
  BOOL hasInitializedCommonComponents = false;

  for (NSString *crashFilePath in [FIRCLSInternalReport crashFileNames]) {
    NSString *path = [self.folderPath stringByAppendingPathComponent:crashFilePath];

    // Skip if the certain crash file doesn't exist
    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
      continue;
    }

    NSDictionary *dicts = [FIRCLSReportAdapter combinedDictionariesFromFilePath:path];

    NSDictionary *exceptionDict = dicts[@"exception"];
    NSDictionary *machExceptionDict = dicts[@"mach_exception"];
    NSDictionary *signalDict = dicts[@"signal"];

    // These fields are specific to the type of crash file
    if (exceptionDict) {
      self.exception = [[FIRCLSRecordException alloc] initWithDict:exceptionDict];

    } else if (machExceptionDict) {
      self.mach_exception = [[FIRCLSRecordMachException alloc] initWithDict:machExceptionDict];

    } else if (signalDict) {
      self.signal = [[FIRCLSRecordSignal alloc] initWithDict:signalDict];
    }

    // These fields are common across all crash files. The order of precedence is
    // Exception > Mach Exception > Signal. Since we are iterating in that order,
    // once any of these fields have been, do not overwrite them.
    if (hasInitializedCommonComponents) {
      continue;
    }

    hasInitializedCommonComponents = true;

    self.runtime = [[FIRCLSRecordRuntime alloc] initWithDict:dicts[@"runtime"]];
    self.processStats = [[FIRCLSRecordProcessStats alloc] initWithDict:dicts[@"process_stats"]];
    self.storage = [[FIRCLSRecordStorage alloc] initWithDict:dicts[@"storage"]];

    // The thread's objc_selector_name is set with the runtime's info
    self.threads = [FIRCLSRecordThread threadsFromDictionaries:dicts[@"threads"]
                                                   threadNames:dicts[@"thread_names"]
                                        withDispatchQueueNames:dicts[@"dispatch_queue_names"]
                                                   withRuntime:self.runtime];
  }
}

// Reimplements Protobuf.scala#L102 (getCrash)
- (FIRCLSRecordCrashBase *)getCrash {
  if (self.exception) {
    return self.exception;
  } else if (self.mach_exception) {
    return self.mach_exception;
  } else if (self.signal) {
    return self.signal;
  } else {
    return nil;
  }
}

- (NSUInteger)sessionEndedAt {
  if ([self hasCrashed]) {
    return [self getCrash].time;
  }

  if (self.errors.count > 0) {
    return self.errors.lastObject.time;
  }

  return 0;
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
  return [self getCrash] != nil;
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

  // TODO: should this be set by the backend?
  session.ended_at = [self sessionEndedAt];

  session.generator = FIRCLSEncodeString(self.identity.generator);
  session.identifier = FIRCLSEncodeString(self.identity.session_id);
  session.started_at = self.identity.started_at;
  session.crashed = [self hasCrashed];
  session.app = [self protoSessionApplication];
  session.os = [self protoOperatingSystem];
  session.device = [self protoSessionDevice];
  session.generator_type = [self protoGeneratorTypeFromString:self.host.platform];

  NSString *userId = self.internalKeyValues[FIRCLSUserIdentifierKey];
  if (userId) {
    session.user = [self protoUserWithId:userId];
  }

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
  return app;
}

- (google_crashlytics_Session_OperatingSystem)protoOperatingSystem {
  google_crashlytics_Session_OperatingSystem os =
      google_crashlytics_Session_OperatingSystem_init_default;
  os.platform = [self protoPlatformFromString:self.host.platform];
  os.version = FIRCLSEncodeString(self.host.os_display_version);
  os.build_version = FIRCLSEncodeString(self.host.os_build_version);
  os.jailbroken = [self isJailbroken];
  return os;
}

- (google_crashlytics_Session_Device)protoSessionDevice {
  google_crashlytics_Session_Device device = google_crashlytics_Session_Device_init_default;
  device.arch = [self protoArchitectureFromString:self.executable.architecture];
  device.model = FIRCLSEncodeString(self.host.model);
  device.ram = [self ramUsed];
  device.disk_space = self.storage.total;
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
  FIRCLSRecordCrashBase *crash = [self getCrash];
  if (crash) {
    events[numberOfEvents - 1] = [self protoEventForCrash:crash];
  }

  return events;
}

- (google_crashlytics_Session_Event)protoEventForCrash:(FIRCLSRecordCrashBase *)crash {
  google_crashlytics_Session_Event crashProto = google_crashlytics_Session_Event_init_default;

  crashProto.timestamp = crash.time;
  crashProto.type = FIRCLSEncodeString(@"crashed");
  crashProto.app = [self protoEventApplicationForCrash];
  crashProto.device = [self protoEventDevice];
  crashProto.log.content = FIRCLSEncodeString([self logsContent]);

  return crashProto;
}

- (google_crashlytics_Session_Event)protoEventForError:(FIRCLSRecordError *)recordedError {
  google_crashlytics_Session_Event error = google_crashlytics_Session_Event_init_default;
  error.timestamp = recordedError.time;
  error.type = FIRCLSEncodeString(@"error");
  error.app = [self protoEventApplicationForError:recordedError];
  error.device = [self protoEventDevice];
  error.log.content = FIRCLSEncodeString([self logsContent]);

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

  // TODO: Fill in Exception object

  app.background = [self wasInBackground];
  app.ui_orientation = [self uiOrientation];

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
  thread.frames = [self protoFramesWithStacktrace:error.stacktrace];
  thread.frames_count = (pb_size_t)error.stacktrace.count;
  threads[0] = thread;
  app.execution.threads = threads;
  app.execution.threads_count = 1;

  app.background = [self wasInBackground];
  app.ui_orientation = [self uiOrientation];

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
    thread.importance = 0;  // TODO: Is there any logic here? Protobuf.scala:384
    thread.alternate_name = FIRCLSEncodeString(array[i].alternate_name);
    thread.objc_selector_name = FIRCLSEncodeString(array[i].objc_selector_name);

    thread.frames = [self protoFramesWithStacktrace:array[i].stacktrace];
    thread.frames_count = (pb_size_t)array[i].stacktrace.count;

    thread.registers = [self protoRegistersWithArray:array[i].registers];
    thread.registers_count = (pb_size_t)array[i].registers.count;

    threads[i] = thread;
  }

  return threads;
}

- (google_crashlytics_Session_Event_Application_Execution_Thread_Frame *)protoFramesWithStacktrace:
    (NSArray<NSNumber *> *)stacktrace {
  google_crashlytics_Session_Event_Application_Execution_Thread_Frame *frames =
      malloc(sizeof(google_crashlytics_Session_Event_Application_Execution_Thread_Frame) *
             stacktrace.count);

  for (NSUInteger i = 0; i < stacktrace.count; i++) {
    google_crashlytics_Session_Event_Application_Execution_Thread_Frame frame =
        google_crashlytics_Session_Event_Application_Execution_Thread_Frame_init_default;
    frame.pc = stacktrace[i].unsignedIntegerValue;

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

// Reimplements Protobuf.scala#L503
- (google_crashlytics_Session_Event_Application_Execution_Signal)protoSignal {
  google_crashlytics_Session_Event_Application_Execution_Signal signalProto =
      google_crashlytics_Session_Event_Application_Execution_Signal_init_default;

  if (self.signal) {
    signalProto.address = self.signal.address;
    signalProto.code = FIRCLSEncodeString(self.signal.code_name);
    signalProto.name = FIRCLSEncodeString(self.signal.name);
  }

  // The address is the second code, if we have 2 codes, from Protobuf.scala#L525
  if (self.mach_exception) {
    if (self.mach_exception.codes.count > 1) {
      signalProto.address = [self.mach_exception.codes[1] unsignedIntValue];
    }
    signalProto.code = FIRCLSEncodeString(self.mach_exception.code_name);
    signalProto.name = FIRCLSEncodeString(self.mach_exception.name);
  }

  return signalProto;
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
  device.ram_used = [self ramUsed];
  device.disk_used = self.storage.total - self.storage.free;
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
  NSData *stringBytes = [string dataUsingEncoding:NSUTF8StringEncoding];
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

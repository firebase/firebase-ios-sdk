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

#import <Foundation/Foundation.h>

#include "Crashlytics/Crashlytics/Handlers/FIRCLSException.h"

#import "Crashlytics/Crashlytics/Private/FIRExceptionModel_Private.h"
#import "Crashlytics/Crashlytics/Private/FIRStackFrame_Private.h"

#include "Crashlytics/Crashlytics/Components/FIRCLSApplication.h"
#include "Crashlytics/Crashlytics/Components/FIRCLSContext.h"
#include "Crashlytics/Crashlytics/Components/FIRCLSGlobals.h"
#include "Crashlytics/Crashlytics/Components/FIRCLSProcess.h"
#import "Crashlytics/Crashlytics/Components/FIRCLSUserLogging.h"

#include "Crashlytics/Crashlytics/Handlers/FIRCLSHandler.h"
#include "Crashlytics/Crashlytics/Helpers/FIRCLSFile.h"
#import "Crashlytics/Crashlytics/Helpers/FIRCLSLogger.h"
#import "Crashlytics/Crashlytics/Helpers/FIRCLSUtility.h"

#import "Crashlytics/Crashlytics/Controllers/FIRCLSReportManager_Private.h"
#import "Crashlytics/Crashlytics/Models/FIRCLSExecutionIdentifierModel.h"
#import "Crashlytics/Crashlytics/Models/FIRCLSFileManager.h"
#import "Crashlytics/Crashlytics/Models/FIRCLSInternalReport.h"
#include "Crashlytics/Crashlytics/Operations/Symbolication/FIRCLSDemangleOperation.h"

// C++/Objective-C exception handling
#include <cxxabi.h>
#include <exception>
#include <string>
#include <typeinfo>

#if !TARGET_OS_IPHONE
#import <AppKit/NSApplication.h>
#import <objc/runtime.h>
#endif

#pragma mark Prototypes
static void FIRCLSTerminateHandler(void);
#if !TARGET_OS_IPHONE
void FIRCLSNSApplicationReportException(id self, SEL cmd, NSException *exception);

typedef void (*NSApplicationReportExceptionFunction)(id, SEL, NSException *);

static BOOL FIRCLSIsNSApplicationCrashOnExceptionsEnabled(void);
static NSApplicationReportExceptionFunction FIRCLSOriginalNSExceptionReportExceptionFunction(void);
static Method FIRCLSGetNSApplicationReportExceptionMethod(void);

#endif

#pragma mark - API
void FIRCLSExceptionInitialize(FIRCLSExceptionReadOnlyContext *roContext,
                               FIRCLSExceptionWritableContext *rwContext) {
  if (!FIRCLSUnlinkIfExists(roContext->path)) {
    FIRCLSSDKLog("Unable to reset the exception file %s\n", strerror(errno));
  }

  roContext->originalTerminateHandler = std::set_terminate(FIRCLSTerminateHandler);

#if !TARGET_OS_IPHONE
  // If FIRCLSApplicationSharedInstance is null, we don't need this
  if (FIRCLSIsNSApplicationCrashOnExceptionsEnabled() && FIRCLSApplicationSharedInstance()) {
    Method m = FIRCLSGetNSApplicationReportExceptionMethod();

    roContext->originalNSApplicationReportException =
        (void *)method_setImplementation(m, (IMP)FIRCLSNSApplicationReportException);
  }
#endif

  rwContext->customExceptionCount = 0;
}

void FIRCLSExceptionRecordModel(FIRExceptionModel *exceptionModel, NSString *rolloutsInfoJSON) {
  const char *name = [[exceptionModel.name copy] UTF8String];
  const char *reason = [[exceptionModel.reason copy] UTF8String] ?: "";
  FIRCLSExceptionRecord(FIRCLSExceptionTypeCustom, name, reason, [exceptionModel.stackTrace copy],
                        rolloutsInfoJSON);
}

NSString *FIRCLSExceptionRecordOnDemandModel(FIRExceptionModel *exceptionModel,
                                             int previousRecordedOnDemandExceptions,
                                             int previousDroppedOnDemandExceptions,
                                             BOOL shouldSuspendThread) {
  const char *name = [[exceptionModel.name copy] UTF8String];
  const char *reason = [[exceptionModel.reason copy] UTF8String] ?: "";

  return FIRCLSExceptionRecordOnDemand(FIRCLSExceptionTypeCustom, name, reason,
                                       [exceptionModel.stackTrace copy], exceptionModel.isFatal,
                                       previousRecordedOnDemandExceptions,
                                       previousDroppedOnDemandExceptions, shouldSuspendThread);
}

void FIRCLSExceptionRecordNSException(NSException *exception) {
  FIRCLSSDKLog("Recording an NSException\n");

  NSArray *returnAddresses = [exception callStackReturnAddresses];

  NSString *name = [exception name];
  NSString *reason = [exception reason] ?: @"";

  // It's tempting to try to make use of callStackSymbols here.  But, the output
  // of that function is not intended to be machine-readable.  We could parse it,
  // but that isn't really worthwhile, considering that address-based symbolication
  // needs to work anyways.

  // package our frames up into the appropriate format
  NSMutableArray *frames = [NSMutableArray new];

  for (NSNumber *address in returnAddresses) {
    [frames addObject:[FIRStackFrame stackFrameWithAddress:[address unsignedIntegerValue]]];
  }

  FIRCLSExceptionRecord(FIRCLSExceptionTypeObjectiveC, [name UTF8String], [reason UTF8String],
                        frames, nil);
}

static void FIRCLSExceptionRecordFrame(FIRCLSFile *file, FIRStackFrame *frame) {
  FIRCLSFileWriteHashStart(file);

  FIRCLSFileWriteHashEntryUint64(file, "pc", [frame address]);

  NSString *string = [frame symbol];
  if (string) {
    FIRCLSFileWriteHashEntryHexEncodedString(file, "symbol", [string UTF8String]);
  }

  FIRCLSFileWriteHashEntryUint64(file, "offset", [frame offset]);

  string = [frame library];
  if (string) {
    FIRCLSFileWriteHashEntryHexEncodedString(file, "library", [string UTF8String]);
  }

  string = [frame fileName];
  if (string) {
    FIRCLSFileWriteHashEntryHexEncodedString(file, "file", [string UTF8String]);
  }

  FIRCLSFileWriteHashEntryUint64(file, "line", [frame lineNumber]);

  FIRCLSFileWriteHashEnd(file);
}

static bool FIRCLSExceptionIsNative(FIRCLSExceptionType type) {
  return type == FIRCLSExceptionTypeObjectiveC || type == FIRCLSExceptionTypeCpp;
}

static const char *FIRCLSExceptionNameForType(FIRCLSExceptionType type) {
  switch (type) {
    case FIRCLSExceptionTypeObjectiveC:
      return "objective-c";
    case FIRCLSExceptionTypeCpp:
      return "c++";
    case FIRCLSExceptionTypeCustom:
      return "custom";
    default:
      break;
  }

  return "unknown";
}

void FIRCLSExceptionWrite(FIRCLSFile *file,
                          FIRCLSExceptionType type,
                          const char *name,
                          const char *reason,
                          NSArray<FIRStackFrame *> *frames,
                          NSString *rolloutsInfoJSON) {
  FIRCLSFileWriteSectionStart(file, "exception");

  FIRCLSFileWriteHashStart(file);

  FIRCLSFileWriteHashEntryString(file, "type", FIRCLSExceptionNameForType(type));
  FIRCLSFileWriteHashEntryHexEncodedString(file, "name", name);
  FIRCLSFileWriteHashEntryHexEncodedString(file, "reason", reason);
  FIRCLSFileWriteHashEntryUint64(file, "time", time(NULL));

  if ([frames count]) {
    FIRCLSFileWriteHashKey(file, "frames");
    FIRCLSFileWriteArrayStart(file);

    for (FIRStackFrame *frame in frames) {
      FIRCLSExceptionRecordFrame(file, frame);
    }

    FIRCLSFileWriteArrayEnd(file);
  }

  if (rolloutsInfoJSON) {
    FIRCLSFileWriteHashKey(file, "rollouts");
    FIRCLSFileWriteStringUnquoted(file, [rolloutsInfoJSON UTF8String]);
    FIRCLSFileWriteHashEnd(file);
  }

  FIRCLSFileWriteHashEnd(file);

  FIRCLSFileWriteSectionEnd(file);
}

void FIRCLSExceptionRecord(FIRCLSExceptionType type,
                           const char *name,
                           const char *reason,
                           NSArray<FIRStackFrame *> *frames,
                           NSString *rolloutsInfoJSON) {
  if (!FIRCLSContextIsInitialized()) {
    return;
  }

  bool native = FIRCLSExceptionIsNative(type);

  FIRCLSSDKLog("Recording an exception structure (%d)\n", native);

  // exceptions can happen on multiple threads at the same time
  if (native) {
    dispatch_sync(_firclsExceptionQueue, ^{
      const char *path = _firclsContext.readonly->exception.path;
      FIRCLSFile file;

      if (!FIRCLSFileInitWithPath(&file, path, false)) {
        FIRCLSSDKLog("Unable to open exception file\n");
        return;
      }

      FIRCLSExceptionWrite(&file, type, name, reason, frames, nil);

      // We only want to do this work if we have the expectation that we'll actually crash
      FIRCLSHandler(&file, mach_thread_self(), NULL, YES);

      FIRCLSFileClose(&file);
    });
  } else {
    FIRCLSUserLoggingWriteAndCheckABFiles(
        &_firclsContext.readonly->logging.customExceptionStorage,
        &_firclsContext.writable->logging.activeCustomExceptionPath, ^(FIRCLSFile *file) {
          FIRCLSExceptionWrite(file, type, name, reason, frames, rolloutsInfoJSON);
        });
  }

  FIRCLSSDKLog("Finished recording an exception structure\n");
}

// Prepares a new active report for on-demand delivery and returns the path to the report.
// Should only be used for platforms in which exceptions do not crash the app (flutter, Unity, etc).
NSString *FIRCLSExceptionRecordOnDemand(FIRCLSExceptionType type,
                                        const char *name,
                                        const char *reason,
                                        NSArray<FIRStackFrame *> *frames,
                                        BOOL fatal,
                                        int previousRecordedOnDemandExceptions,
                                        int previousDroppedOnDemandExceptions,
                                        BOOL shouldSuspendThread) {
  if (!FIRCLSContextIsInitialized()) {
    return nil;
  }

  FIRCLSSDKLog("Recording an exception structure on demand\n");

  FIRCLSFileManager *fileManager = [[FIRCLSFileManager alloc] init];

  // Create paths for new report.
  NSString *currentReportPath =
      [NSString stringWithUTF8String:_firclsContext.readonly->initialReportPath];
  NSString *newReportID = [[[FIRCLSExecutionIdentifierModel alloc] init] executionID];
  NSString *newReportPath = [fileManager.activePath stringByAppendingPathComponent:newReportID];
  NSString *customFatalIndicatorFilePath =
      [newReportPath stringByAppendingPathComponent:FIRCLSCustomFatalIndicatorFile];
  NSString *newKVPath =
      [newReportPath stringByAppendingPathComponent:FIRCLSReportInternalIncrementalKVFile];

  // Create new report and copy into it the current state of custom keys and log and the sdk.log,
  // binary_images.clsrecord, and metadata.clsrecord files.
  // Also copy rollouts.clsrecord if applicable.
  NSError *error = nil;
  BOOL copied = [fileManager.underlyingFileManager copyItemAtPath:currentReportPath
                                                           toPath:newReportPath
                                                            error:&error];
  if (error || !copied) {
    FIRCLSSDKLog("Unable to create a new report to record on-demand exeption.");
    return nil;
  }

  // Once the report is copied, remove non-fatal events from current report.
  if ([fileManager
          fileExistsAtPath:[NSString stringWithUTF8String:_firclsContext.readonly->logging
                                                              .customExceptionStorage.aPath]]) {
    [fileManager
        removeItemAtPath:[NSString stringWithUTF8String:_firclsContext.readonly->logging
                                                            .customExceptionStorage.aPath]];
  }
  if ([fileManager
          fileExistsAtPath:[NSString stringWithUTF8String:_firclsContext.readonly->logging
                                                              .customExceptionStorage.bPath]]) {
    [fileManager
        removeItemAtPath:[NSString stringWithUTF8String:_firclsContext.readonly->logging
                                                            .customExceptionStorage.bPath]];
  }
  *_firclsContext.readonly->logging.customExceptionStorage.entryCount = 0;
  _firclsContext.writable->exception.customExceptionCount = 0;

  // Record how many on-demand exceptions occurred before this one as well as how many were dropped.
  FIRCLSFile kvFile;
  if (!FIRCLSFileInitWithPath(&kvFile, [newKVPath UTF8String], true)) {
    FIRCLSSDKLogError("Unable to open k-v file\n");
    return nil;
  }
  FIRCLSFileWriteSectionStart(&kvFile, "kv");
  FIRCLSFileWriteHashStart(&kvFile);
  FIRCLSFileWriteHashEntryHexEncodedString(&kvFile, "key",
                                           [FIRCLSOnDemandRecordedExceptionsKey UTF8String]);
  FIRCLSFileWriteHashEntryHexEncodedString(
      &kvFile, "value",
      [[[NSNumber numberWithInt:previousRecordedOnDemandExceptions] stringValue] UTF8String]);
  FIRCLSFileWriteHashEnd(&kvFile);
  FIRCLSFileWriteSectionEnd(&kvFile);
  FIRCLSFileWriteSectionStart(&kvFile, "kv");
  FIRCLSFileWriteHashStart(&kvFile);
  FIRCLSFileWriteHashEntryHexEncodedString(&kvFile, "key",
                                           [FIRCLSOnDemandDroppedExceptionsKey UTF8String]);
  FIRCLSFileWriteHashEntryHexEncodedString(
      &kvFile, "value",
      [[[NSNumber numberWithInt:previousDroppedOnDemandExceptions] stringValue] UTF8String]);
  FIRCLSFileWriteHashEnd(&kvFile);
  FIRCLSFileWriteSectionEnd(&kvFile);
  FIRCLSFileClose(&kvFile);

  // If the event was fatal, write out an empty file to indicate that the report contains a fatal
  // event. This is used to report events to Analytics for CFU calculations.
  if (fatal && ![fileManager createFileAtPath:customFatalIndicatorFilePath
                                     contents:nil
                                   attributes:nil]) {
    FIRCLSSDKLog("Unable to create custom exception file. On demand exception will not be logged "
                 "with analytics.");
  }

  // Write out the exception in the new report.
  const char *newActiveCustomExceptionPath =
      fatal ? [[newReportPath stringByAppendingPathComponent:FIRCLSReportExceptionFile] UTF8String]
            : [[newReportPath stringByAppendingPathComponent:FIRCLSReportCustomExceptionAFile]
                  UTF8String];
  FIRCLSFile file;
  if (!FIRCLSFileInitWithPath(&file, newActiveCustomExceptionPath, true)) {
    FIRCLSSDKLog("Unable to open log file for on demand custom exception\n");
    return nil;
  }
  FIRCLSExceptionWrite(&file, type, name, reason, frames, nil);

  FIRCLSHandler(&file, mach_thread_self(), NULL, shouldSuspendThread);
  FIRCLSFileClose(&file);

  // Return the path to the new report.
  FIRCLSSDKLog("Finished recording on demand exception structure\n");
  return newReportPath;
}

// Ignore this message here, because we know that this call will not leak.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Winvalid-noreturn"
void FIRCLSExceptionRaiseTestObjCException(void) {
  [NSException raise:@"CrashlyticsTestException"
              format:@"This is an Objective-C exception used for testing."];
}

void FIRCLSExceptionRaiseTestCppException(void) {
  throw "Crashlytics C++ Test Exception";
}
#pragma clang diagnostic pop

static const char *FIRCLSExceptionDemangle(const char *symbol) {
  return [[FIRCLSDemangleOperation demangleCppSymbol:symbol] UTF8String];
}

static void FIRCLSCatchAndRecordActiveException(std::type_info *typeInfo) {
  if (!FIRCLSIsValidPointer(typeInfo)) {
    FIRCLSSDKLog("Error: invalid parameter\n");
    return;
  }

  const char *name = typeInfo->name();
  FIRCLSSDKLog("Recording exception of type '%s'\n", name);

  // This is a funny technique to get the exception object. The inner @try
  // has the ability to capture NSException-derived objects. It seems that
  // c++ tries can do that in some cases, but I was warned by the WWDC labs
  // that there are cases where that will not work (like for NSException subclasses).
  try {
    @try {
      // This could potentially cause a call to std::terminate() if there is actually no active
      // exception.
      throw;
    } @catch (NSException *exception) {
#if TARGET_OS_IPHONE
      FIRCLSExceptionRecordNSException(exception);
#else
      // There's no need to record this here, because we're going to get
      // the value forward to us by AppKit
      FIRCLSSDKLog("Skipping ObjC exception at this point\n");
#endif
    }
  } catch (const char *exc) {
    FIRCLSExceptionRecord(FIRCLSExceptionTypeCpp, "const char *", exc, nil, nil);
  } catch (const std::string &exc) {
    FIRCLSExceptionRecord(FIRCLSExceptionTypeCpp, "std::string", exc.c_str(), nil, nil);
  } catch (const std::exception &exc) {
    FIRCLSExceptionRecord(FIRCLSExceptionTypeCpp, FIRCLSExceptionDemangle(name), exc.what(), nil,
                          nil);
  } catch (const std::exception *exc) {
    FIRCLSExceptionRecord(FIRCLSExceptionTypeCpp, FIRCLSExceptionDemangle(name), exc->what(), nil,
                          nil);
  } catch (const std::bad_alloc &exc) {
    // it is especially important to avoid demangling in this case, because the expectation at this
    // point is that all allocations could fail
    FIRCLSExceptionRecord(FIRCLSExceptionTypeCpp, "std::bad_alloc", exc.what(), nil, nil);
  } catch (...) {
    FIRCLSExceptionRecord(FIRCLSExceptionTypeCpp, FIRCLSExceptionDemangle(name), "", nil, nil);
  }
}

#pragma mark - Handlers
static void FIRCLSTerminateHandler(void) {
  FIRCLSSDKLog("C++ terminate handler invoked\n");

  void (*handler)(void) = _firclsContext.readonly->exception.originalTerminateHandler;
  if (handler == FIRCLSTerminateHandler) {
    FIRCLSSDKLog("Error: original handler was set recursively\n");
    handler = NULL;
  }

  // Restore pre-existing handler, if any. Do this early, so that
  // if std::terminate is called while we are executing here, we do not recurse.
  if (handler) {
    FIRCLSSDKLog("restoring pre-existing handler\n");

    // To prevent infinite recursion in this function, check that we aren't resetting the terminate
    // handler to the same function again, which would be this function in the event that we can't
    // actually change the handler during a terminate.
    if (std::set_terminate(handler) == handler) {
      FIRCLSSDKLog("handler has already been restored, aborting\n");
      abort();
    }
  }

  // we can use typeInfo to record the type of the exception,
  // but we must use a catch to get the value
  std::type_info *typeInfo = __cxxabiv1::__cxa_current_exception_type();
  if (typeInfo) {
    FIRCLSCatchAndRecordActiveException(typeInfo);
  } else {
    FIRCLSSDKLog("no active exception\n");
  }

  // only do this if there was a pre-existing handler
  if (handler) {
    FIRCLSSDKLog("invoking pre-existing handler\n");
    handler();
  }

  FIRCLSSDKLog("aborting\n");
  abort();
}

void FIRCLSExceptionCheckHandlers(void *delegate) {
#if !TARGET_OS_IPHONE
  // Check this on OS X all the time, even if the debugger is attached. This is a common
  // source of errors, so we want to be extra verbose in this case.
  if (FIRCLSApplicationSharedInstance()) {
    if (!FIRCLSIsNSApplicationCrashOnExceptionsEnabled()) {
      FIRCLSWarningLog(@"Warning: NSApplicationCrashOnExceptions is not set. This will "
                       @"result in poor top-level uncaught exception reporting.");
    }
  }
#endif

  if (_firclsContext.readonly->debuggerAttached) {
    return;
  }

  void *ptr = NULL;

  ptr = (void *)std::get_terminate();
  if (ptr != FIRCLSTerminateHandler) {
    FIRCLSLookupFunctionPointer(ptr, ^(const char *name, const char *lib) {
      FIRCLSWarningLog(@"Warning: std::get_terminate is '%s' in '%s'", name, lib);
    });
  }

#if TARGET_OS_IPHONE
  ptr = (void *)NSGetUncaughtExceptionHandler();
  if (ptr) {
    FIRCLSLookupFunctionPointer(ptr, ^(const char *name, const char *lib) {
      FIRCLSWarningLog(@"Warning: NSUncaughtExceptionHandler is '%s' in '%s'", name, lib);
    });
  }
#else
  if (FIRCLSApplicationSharedInstance() && FIRCLSIsNSApplicationCrashOnExceptionsEnabled()) {
    // In this case, we *might* be able to intercept exceptions. But, verify we've still
    // swizzled the method.
    Method m = FIRCLSGetNSApplicationReportExceptionMethod();

    if (method_getImplementation(m) != (IMP)FIRCLSNSApplicationReportException) {
      FIRCLSWarningLog(
          @"Warning: top-level NSApplication-reported exceptions cannot be intercepted");
    }
  }
#endif
}

#pragma mark - AppKit Handling
#if !TARGET_OS_IPHONE
static BOOL FIRCLSIsNSApplicationCrashOnExceptionsEnabled(void) {
  return [[NSUserDefaults standardUserDefaults] boolForKey:@"NSApplicationCrashOnExceptions"];
}

static Method FIRCLSGetNSApplicationReportExceptionMethod(void) {
  return class_getInstanceMethod(NSClassFromString(@"NSApplication"), @selector(reportException:));
}

static NSApplicationReportExceptionFunction FIRCLSOriginalNSExceptionReportExceptionFunction(void) {
  return (NSApplicationReportExceptionFunction)
      _firclsContext.readonly->exception.originalNSApplicationReportException;
}

void FIRCLSNSApplicationReportException(id self, SEL cmd, NSException *exception) {
  FIRCLSExceptionRecordNSException(exception);

  // Call the original implementation
  FIRCLSOriginalNSExceptionReportExceptionFunction()(self, cmd, exception);
}

#endif

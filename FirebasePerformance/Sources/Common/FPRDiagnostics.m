// Copyright 2020 Google LLC
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

#import "FirebasePerformance/Sources/Common/FPRDiagnostics.h"
#import "FirebasePerformance/Sources/Common/FPRDiagnostics_Private.h"
#import "FirebasePerformance/Sources/Configurations/FPRConfigurations.h"

void __FPRAssert(id object, BOOL condition, const char *func) {
  static BOOL diagnosticsEnabled = NO;
  static dispatch_once_t onceToken;
  NSDictionary<NSString *, NSString *> *environment = [NSProcessInfo processInfo].environment;
  // Enable diagnostics when in test environment
  if (environment[@"XCTestConfigurationFilePath"] != nil) {
    diagnosticsEnabled = [FPRDiagnostics isEnabled];
  } else {
    dispatch_once(&onceToken, ^{
      diagnosticsEnabled = [FPRDiagnostics isEnabled];
    });
  }

  if (__builtin_expect(!condition && diagnosticsEnabled, NO)) {
    FPRLogError(kFPRDiagnosticFailure, @"Failure in %s, information follows:", func);
    FPRLogNotice(kFPRDiagnosticLog, @"Stack for failure in %s:\n%@", func,
                 [NSThread callStackSymbols]);
    if ([[object class] respondsToSelector:@selector(emitDiagnostics)]) {
      [[object class] performSelector:@selector(emitDiagnostics) withObject:nil];
    }
    if ([object respondsToSelector:@selector(emitDiagnostics)]) {
      [object performSelector:@selector(emitDiagnostics) withObject:nil];
    }
    FPRLogNotice(kFPRDiagnosticLog, @"End of diagnostics for %s failure.", func);
  }
}

@implementation FPRDiagnostics

static FPRConfigurations *_configuration;

+ (void)initialize {
  _configuration = [FPRConfigurations sharedInstance];
}

+ (FPRConfigurations *)configuration {
  return _configuration;
}

+ (void)setConfiguration:(FPRConfigurations *)config {
  _configuration = config;
}

+ (BOOL)isEnabled {
  // Check a soft-linked FIRCore class to see if this is running in the app store.
  Class FIRAppEnvironmentUtil = NSClassFromString(@"FIRAppEnvironmentUtil");
  SEL isFromAppStore = NSSelectorFromString(@"isFromAppStore");
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
  if (FIRAppEnvironmentUtil && [FIRAppEnvironmentUtil respondsToSelector:isFromAppStore] &&
      [FIRAppEnvironmentUtil performSelector:isFromAppStore]) {
    return NO;
  }
#pragma clang diagnostic pop
  BOOL enabled = [FPRDiagnostics.configuration diagnosticsEnabled];
  if (enabled) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      FPRLogNotice(kFPRDiagnosticInfo, @"Firebase Performance Diagnostics have been enabled!");
    });
  }
  return enabled;
}

@end

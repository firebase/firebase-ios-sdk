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

#import "FirebasePerformance/Sources/Public/FirebasePerformance/FIRPerformance.h"
#import "FirebasePerformance/Sources/FIRPerformance+Internal.h"
#import "FirebasePerformance/Sources/FIRPerformance_Private.h"

#import "FirebasePerformance/Sources/Common/FPRConstants.h"
#import "FirebasePerformance/Sources/Configurations/FPRConfigurations.h"
#import "FirebasePerformance/Sources/FPRClient+Private.h"
#import "FirebasePerformance/Sources/FPRClient.h"
#import "FirebasePerformance/Sources/FPRConsoleLogger.h"
#import "FirebasePerformance/Sources/FPRDataUtils.h"
#import "FirebasePerformance/Sources/Instrumentation/FPRInstrumentation.h"
#import "FirebasePerformance/Sources/Timer/FIRTrace+Internal.h"

static NSString *const kFirebasePerfErrorDomain = @"com.firebase.perf";

@implementation FIRPerformance

#pragma mark - Public methods

+ (instancetype)sharedInstance {
  static FIRPerformance *firebasePerformance = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    firebasePerformance = [[FIRPerformance alloc] init];
  });
  return firebasePerformance;
}

+ (FIRTrace *)startTraceWithName:(NSString *)name {
  FIRTrace *trace = [[self sharedInstance] traceWithName:name];
  [trace start];
  return trace;
}

- (FIRTrace *)traceWithName:(NSString *)name {
  if (![self isPerfConfigured]) {
    FPRLogError(kFPRTraceNotCreated, @"Failed creating trace %@. Firebase is not configured.",
                name);
    [NSException raise:kFirebasePerfErrorDomain
                format:@"The default Firebase app has not yet been configured. Add "
                       @"`FirebaseApp.configure()` to your application initialization."];
    return nil;
  }
  FIRTrace *trace = [[FIRTrace alloc] initWithName:name];
  return trace;
}

/**
 * Checks if the SDK has been successfully configured.
 *
 * @return YES if SDK is configured successfully, otherwise NO.
 */
- (BOOL)isPerfConfigured {
  return self.fprClient.isConfigured;
}

#pragma mark - Internal methods

- (instancetype)init {
  self = [super init];
  if (self) {
    _customAttributes = [[NSMutableDictionary<NSString *, NSString *> alloc] init];
    _customAttributesSerialQueue =
        dispatch_queue_create("com.google.perf.customAttributes", DISPATCH_QUEUE_SERIAL);
    _fprClient = [FPRClient sharedInstance];
  }
  return self;
}

- (BOOL)isDataCollectionEnabled {
  return [FPRConfigurations sharedInstance].isDataCollectionEnabled;
}

- (void)setDataCollectionEnabled:(BOOL)dataCollectionEnabled {
  [[FPRConfigurations sharedInstance] setDataCollectionEnabled:dataCollectionEnabled];
}

- (BOOL)isInstrumentationEnabled {
  return self.fprClient.isSwizzled || [FPRConfigurations sharedInstance].isInstrumentationEnabled;
}

- (void)setInstrumentationEnabled:(BOOL)instrumentationEnabled {
  [[FPRConfigurations sharedInstance] setInstrumentationEnabled:instrumentationEnabled];
  if (instrumentationEnabled) {
    [self.fprClient checkAndStartInstrumentation];
  } else {
    if (self.fprClient.isSwizzled) {
      FPRLogError(kFPRInstrumentationDisabledAfterConfigure,
                  @"Failed to disable instrumentation because Firebase Performance has already "
                  @"been configured. It will be disabled when the app restarts.");
    }
  }
}

#pragma mark - Custom attributes related methods

- (NSDictionary<NSString *, NSString *> *)attributes {
  return [self.customAttributes copy];
}

- (void)setValue:(NSString *)value forAttribute:(nonnull NSString *)attribute {
  NSString *validatedName = FPRReservableAttributeName(attribute);
  NSString *validatedValue = FPRValidatedAttributeValue(value);

  BOOL canAddAttribute = YES;
  if (validatedName == nil) {
    FPRLogError(kFPRAttributeNoName,
                @"Failed to initialize because of a nil or zero length attribute name.");
    canAddAttribute = NO;
  }

  if (validatedValue == nil) {
    FPRLogError(kFPRAttributeNoValue,
                @"Failed to initialize because of a nil or zero length attribute value.");
    canAddAttribute = NO;
  }

  if (self.customAttributes.allKeys.count >= kFPRMaxGlobalCustomAttributesCount) {
    FPRLogError(kFPRMaxAttributesReached,
                @"Only %d attributes allowed. Already reached maximum attribute count.",
                kFPRMaxGlobalCustomAttributesCount);
    canAddAttribute = NO;
  }

  if (canAddAttribute) {
    // Ensure concurrency during update of attributes.
    dispatch_sync(self.customAttributesSerialQueue, ^{
      self.customAttributes[validatedName] = validatedValue;
    });
  }
}

- (NSString *)valueForAttribute:(NSString *)attribute {
  // TODO(b/175053654): Should this be happening on the serial queue for thread safety?
  return self.customAttributes[attribute];
}

- (void)removeAttribute:(NSString *)attribute {
  [self.customAttributes removeObjectForKey:attribute];
}

@end

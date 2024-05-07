#import "Crashlytics/Crashlytics/Components/FIRCLSAppMemory.h"
#import "Crashlytics/Crashlytics/Components/FIRCLSContext.h"
#import "Crashlytics/Crashlytics/Components/FIRCLSUserLogging.h"
#import "Crashlytics/Crashlytics/Handlers/FIRCLSException.h"
#import "Crashlytics/Crashlytics/Public/FirebaseCrashlytics/FIRCrashlytics.h"

#import <mach/mach.h>
#import <mach/task.h>
#import <atomic>

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 The memory tracker takes care of centralizing the knowledge around memory.
 It does the following:

 1- Wraps memory pressure. This is more useful than `didReceiveMemoryWarning`
 as it vends different levels of pressure caused by the app as well as the rest of the OS.

 2- Vends a memory level. This is pretty novel. It vends levels of where the app is wihtin
 the memory limit.

 Some useful info.

 Memory Pressure is mostly useful when the app is in the background.
 It helps understand how much `pressure` is on the app due to external concerns. Using
 this data, we can make informed decisions around the reasons the app might have been
 terminated.

 Memory Level is useful in the foreground as well as background. It indicates where the app is
 within its memory limit. That limit being calculated by the addition of `remaining` and
 `footprint`. Using this data, we can also make informaed decisions around foreground and background
 memory terminations, aka. OOMs.

 See: https://github.com/naftaly/Footprint
 */

typedef NS_ENUM(NSUInteger, FIRCLSAppMemoryTrackerChangeType) {
  FIRCLSAppMemoryTrackerChangeTypeNone,
  FIRCLSAppMemoryTrackerChangeTypeLevel,
  FIRCLSAppMemoryTrackerChangeTypePressure
};

@interface FIRCLSAppMemoryTracker () {
  dispatch_queue_t _heartbeatQueue;
  dispatch_source_t _pressureSource;
  dispatch_source_t _limitSource;
  std::atomic<FIRCLSAppMemoryPressure> _pressure;
  std::atomic<FIRCLSAppMemoryLevel> _level;
}
@end

@implementation FIRCLSAppMemoryTracker

- (instancetype)init {
  if (self = [super init]) {
    _heartbeatQueue = dispatch_queue_create_with_target(
        "com.firebase.crashlytics.memory.heartbeat", DISPATCH_QUEUE_SERIAL,
        dispatch_get_global_queue(QOS_CLASS_UTILITY, 0));
    _level = FIRCLSAppMemoryLevelNormal;
    _pressure = FIRCLSAppMemoryPressureNormal;
  }
  return self;
}

- (void)dealloc {
  [self stop];
}

- (void)start {
  // kill the old ones
  if (_pressureSource || _limitSource) {
    [self stop];
  }

  // memory pressure
  uintptr_t mask = DISPATCH_MEMORYPRESSURE_NORMAL | DISPATCH_MEMORYPRESSURE_WARN |
                   DISPATCH_MEMORYPRESSURE_CRITICAL;
  _pressureSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_MEMORYPRESSURE, 0, mask,
                                           dispatch_get_main_queue());

  __weak __typeof(self) weakMe = self;

  dispatch_source_set_event_handler(_pressureSource, ^{
    [weakMe _memoryPressureChanged:YES];
  });
  dispatch_activate(_pressureSource);

  // memory limit (level)
  _limitSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, _heartbeatQueue);
  dispatch_source_set_event_handler(_limitSource, ^{
    [weakMe _heartbeat:YES];
  });
  dispatch_source_set_timer(_limitSource, dispatch_time(DISPATCH_TIME_NOW, 0), NSEC_PER_SEC,
                            NSEC_PER_SEC / 10);
  dispatch_activate(_limitSource);

#if CLS_TARGET_OS_HAS_UIKIT
  // We won't always hit this depending on how Crashlytics is setup in the app,
  // but at least we can try.
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(_appDidFinishLaunching)
                                               name:UIApplicationDidFinishLaunchingNotification
                                             object:nil];
#endif
  [self _handleMemoryChange:[self currentAppMemory] type:FIRCLSAppMemoryTrackerChangeTypeNone];
}

#if CLS_TARGET_OS_HAS_UIKIT
- (void)_appDidFinishLaunching {
  [self _handleMemoryChange:[self currentAppMemory] type:FIRCLSAppMemoryTrackerChangeTypeNone];
}
#endif

- (void)stop {
  if (_pressureSource) {
    dispatch_source_cancel(_pressureSource);
    _pressureSource = nil;
  }

  if (_limitSource) {
    dispatch_source_cancel(_limitSource);
    _limitSource = nil;
  }
}

- (nullable FIRCLSAppMemory *)currentAppMemory {
  task_vm_info_data_t info = {};
  mach_msg_type_number_t count = TASK_VM_INFO_COUNT;
  kern_return_t err = task_info(mach_task_self(), TASK_VM_INFO, (task_info_t)&info, &count);
  if (err != KERN_SUCCESS) {
    return nil;
  }

#if TARGET_OS_SIMULATOR
  // in simulator, remaining is always 0. So let's fake it.
  // How about a limit of 3GB.
  uint64_t limit = 3000000000;
  uint64_t remaining = limit < info.phys_footprint ? 0 : limit - info.phys_footprint;
#else
  uint64_t remaining = info.limit_bytes_remaining;
#endif

  return [[FIRCLSAppMemory alloc] initWithFootprint:info.phys_footprint
                                          remaining:remaining
                                           pressure:_pressure];
}

static void __MEMORY_PRESSURE_HIGH_OOM_IS_IMMINENT__() __attribute__((noinline));
static void __MEMORY_PRESSURE_HIGH_OOM_IS_IMMINENT__() {
  __asm__ __volatile__("");  // no tail-call optimization
}

static void __MEMORY_LEVEL_HIGH_OOM_IS_IMMINENT__() __attribute__((noinline));
static void __MEMORY_LEVEL_HIGH_OOM_IS_IMMINENT__() {
  __asm__ __volatile__("");  // no tail-call optimization
}

// This will push non-fatals as well as kv's for user and internal data.
// User data is so we see it in the keys section in the Firebase Dashboard.
// Internal is to load the data on next run in the internal report to check for an OOM.
// I'd like to have this in it's own memory kv store, but that's for a future enhancement.
- (void)_handleMemoryChange:(FIRCLSAppMemory *)memory type:(FIRCLSAppMemoryTrackerChangeType)type {
  // KV pushes
  NSDictionary<NSString *, id> *const kv = memory.serialize;
  if (FIRCLSContextIsInitialized()) {
    for (NSString *key in kv) {
      FIRCLSUserLoggingRecordInternalKeyValue(key, kv[key]);
    }
    FIRCLSUserLoggingRecordUserKeysAndValues(kv);
  }

  // non-fatals
  if (type == FIRCLSAppMemoryTrackerChangeTypeLevel &&
      memory.level >= FIRCLSAppMemoryLevelCritical) {
    NSString *level = FIRCLSAppMemoryLevelToString(memory.level).uppercaseString;
    NSString *reason = [NSString stringWithFormat:@"Memory Level Is %@", level];
    FIRExceptionModel *model = [[FIRExceptionModel alloc] initWithName:@"Memry Level"
                                                                reason:reason];
    model.stackTrace = @[ [FIRStackFrame
        stackFrameWithAddress:(uintptr_t)&__MEMORY_LEVEL_HIGH_OOM_IS_IMMINENT__] ];
    FIRCLSExceptionRecordModel(model, nil);
  }

  if (type == FIRCLSAppMemoryTrackerChangeTypePressure &&
      memory.pressure >= FIRCLSAppMemoryPressureCritical) {
    NSString *pressure = FIRCLSAppMemoryPressureToString(memory.pressure).uppercaseString;
    NSString *reason = [NSString stringWithFormat:@"Memory Pressure Is %@", pressure];
    FIRExceptionModel *model = [[FIRExceptionModel alloc] initWithName:@"Memory Pressure"
                                                                reason:reason];
    model.stackTrace = @[ [FIRStackFrame
        stackFrameWithAddress:(uintptr_t)&__MEMORY_PRESSURE_HIGH_OOM_IS_IMMINENT__] ];
    FIRCLSExceptionRecordModel(model, nil);
  }
}

- (void)_heartbeat:(BOOL)sendObservers {
  // This handles the memory limit.
  FIRCLSAppMemory *memory = [self currentAppMemory];
  FIRCLSAppMemoryLevel newLevel = memory.level;
  FIRCLSAppMemoryLevel oldLevel = _level.exchange(newLevel);
  if (newLevel != oldLevel && sendObservers) {
    [self _handleMemoryChange:memory type:FIRCLSAppMemoryTrackerChangeTypeLevel];
    dispatch_async(dispatch_get_main_queue(), ^{
      [[NSNotificationCenter defaultCenter]
          postNotificationName:FIRCLSAppMemoryLevelChangedNotification
                        object:self
                      userInfo:@{
                        FIRCLSAppMemoryNewValueKey : @(newLevel),
                        FIRCLSAppMemoryOldValueKey : @(oldLevel)
                      }];
    });
#if TARGET_OS_SIMULATOR

    // On the simulator, if we're at a terminal level
    // let's fake an OOM by sending a SIGKILL signal
    //
    // NOTE: Some teams might want to do this in prod.
    // For example, we could send a SIGTERM so the system
    // catches a stack trace.
    if (newLevel == FIRCLSAppMemoryLevelTerminal) {
      kill(getpid(), SIGKILL);
      _exit(0);
    }
#endif
  }
}

- (void)_memoryPressureChanged:(BOOL)sendObservers {
  // This handles system based memory pressure.
  FIRCLSAppMemoryPressure pressure = FIRCLSAppMemoryPressureNormal;
  dispatch_source_memorypressure_flags_t flags = dispatch_source_get_data(_pressureSource);
  if (flags == DISPATCH_MEMORYPRESSURE_NORMAL) {
    pressure = FIRCLSAppMemoryPressureNormal;
  } else if (flags == DISPATCH_MEMORYPRESSURE_WARN) {
    pressure = FIRCLSAppMemoryPressureWarn;
  } else if (flags == DISPATCH_MEMORYPRESSURE_CRITICAL) {
    pressure = FIRCLSAppMemoryPressureCritical;
  }
  FIRCLSAppMemoryPressure oldPressure = _pressure.exchange(pressure);
  if (oldPressure != pressure && sendObservers) {
    [self _handleMemoryChange:[self currentAppMemory]
                         type:FIRCLSAppMemoryTrackerChangeTypePressure];
    [[NSNotificationCenter defaultCenter]
        postNotificationName:FIRCLSAppMemoryPressureChangedNotification
                      object:self
                    userInfo:@{
                      FIRCLSAppMemoryNewValueKey : @(pressure),
                      FIRCLSAppMemoryOldValueKey : @(oldPressure)
                    }];
  }
}

- (FIRCLSAppMemoryPressure)pressure {
  return _pressure.load();
}

- (FIRCLSAppMemoryLevel)level {
  return _level.load();
}

@end

@implementation FIRCLSAppMemory

- (instancetype)initWithFootprint:(uint64_t)footprint
                        remaining:(uint64_t)remaining
                         pressure:(FIRCLSAppMemoryPressure)pressure {
  if (self = [super init]) {
    _footprint = footprint;
    _remaining = remaining;
    _pressure = pressure;
  }
  return self;
}

- (nullable instancetype)initWithJSONObject:(NSDictionary *)jsonObject {
  NSNumber *const footprintRef = jsonObject[@"memory_footprint"];
  NSNumber *const remainingRef = jsonObject[@"memory_remaining"];
  NSString *const pressureRef = jsonObject[@"memory_pressure"];

  uint64_t footprint = 0;
  if ([footprintRef isKindOfClass:NSNumber.class]) {
    footprint = footprintRef.unsignedLongLongValue;
  } else if ([footprintRef isKindOfClass:NSString.class]) {
    footprint = ((NSString *)footprintRef).longLongValue;
  } else {
    return nil;
  }

  uint64_t remaining = 0;
  if ([remainingRef isKindOfClass:NSNumber.class]) {
    remaining = remainingRef.unsignedLongLongValue;
  } else if ([remainingRef isKindOfClass:NSString.class]) {
    remaining = ((NSString *)remainingRef).longLongValue;
  } else {
    return nil;
  }

  FIRCLSAppMemoryPressure pressure = FIRCLSAppMemoryPressureNormal;
  if ([pressureRef isKindOfClass:NSString.class]) {
    pressure = FIRCLSAppMemoryPressureFromString(pressureRef);
  }

  return [self initWithFootprint:footprint remaining:remaining pressure:pressure];
}

- (BOOL)isEqual:(id)object {
  if (![object isKindOfClass:self.class]) {
    return NO;
  }
  FIRCLSAppMemory *comp = (FIRCLSAppMemory *)object;
  return comp.footprint == self.footprint && comp.remaining == self.remaining &&
         comp.pressure == self.pressure;
}

- (nonnull NSDictionary<NSString *, id> *)serialize {
  return @{
    @"memory_footprint" : @(self.footprint),
    @"memory_remaining" : @(self.remaining),
    @"memory_limit" : @(self.limit),
    @"memory_level" : FIRCLSAppMemoryLevelToString(self.level),
    @"memory_pressure" : FIRCLSAppMemoryPressureToString(self.pressure)
  };
}

- (uint64_t)limit {
  return _footprint + _remaining;
}

- (FIRCLSAppMemoryLevel)level {
  double usedRatio = (double)self.footprint / (double)self.limit;

  return usedRatio < 0.25   ? FIRCLSAppMemoryLevelNormal
         : usedRatio < 0.50 ? FIRCLSAppMemoryLevelWarn
         : usedRatio < 0.75 ? FIRCLSAppMemoryLevelUrgent
         : usedRatio < 0.95 ? FIRCLSAppMemoryLevelCritical
                            : FIRCLSAppMemoryLevelTerminal;
}

- (BOOL)isOutOfMemory {
  return self.level >= FIRCLSAppMemoryLevelCritical ||
         self.pressure >= FIRCLSAppMemoryPressureCritical;
}

@end

NSString *FIRCLSAppMemoryLevelToString(FIRCLSAppMemoryLevel level) {
  switch (level) {
    case FIRCLSAppMemoryLevelNormal:
      return @"normal";
    case FIRCLSAppMemoryLevelWarn:
      return @"warn";
    case FIRCLSAppMemoryLevelUrgent:
      return @"urgent";
    case FIRCLSAppMemoryLevelCritical:
      return @"critical";
    case FIRCLSAppMemoryLevelTerminal:
      return @"terminal";
  }
}

FIRCLSAppMemoryLevel FIRCLSAppMemoryLevelFromString(NSString *const level) {
  if ([level isEqualToString:@"normal"]) {
    return FIRCLSAppMemoryLevelNormal;
  }

  if ([level isEqualToString:@"warn"]) {
    return FIRCLSAppMemoryLevelWarn;
  }

  if ([level isEqualToString:@"urgent"]) {
    return FIRCLSAppMemoryLevelUrgent;
  }

  if ([level isEqualToString:@"critical"]) {
    return FIRCLSAppMemoryLevelCritical;
  }

  if ([level isEqualToString:@"terminal"]) {
    return FIRCLSAppMemoryLevelTerminal;
  }

  return FIRCLSAppMemoryLevelNormal;
}

NSString *FIRCLSAppMemoryPressureToString(FIRCLSAppMemoryPressure pressure) {
  switch (pressure) {
    case FIRCLSAppMemoryPressureNormal:
      return @"normal";
    case FIRCLSAppMemoryPressureWarn:
      return @"warn";
    case FIRCLSAppMemoryPressureCritical:
      return @"critical";
  }
}

FIRCLSAppMemoryPressure FIRCLSAppMemoryPressureFromString(NSString *const pressure) {
  if ([pressure isEqualToString:@"normal"]) {
    return FIRCLSAppMemoryPressureNormal;
  }

  if ([pressure isEqualToString:@"warn"]) {
    return FIRCLSAppMemoryPressureWarn;
  }

  if ([pressure isEqualToString:@"critical"]) {
    return FIRCLSAppMemoryPressureCritical;
  }

  return FIRCLSAppMemoryPressureNormal;
}

NSNotificationName const FIRCLSAppMemoryLevelChangedNotification =
    @"FIRCLSAppMemoryLevelChangedNotification";
NSNotificationName const FIRCLSAppMemoryPressureChangedNotification =
    @"FIRCLSAppMemoryPressureChangedNotification";
NSString *const FIRCLSAppMemoryNewValueKey = @"FIRCLSAppMemoryNewValueKey";
NSString *const FIRCLSAppMemoryOldValueKey = @"FIRCLSAppMemoryOldValueKey";

NS_ASSUME_NONNULL_END

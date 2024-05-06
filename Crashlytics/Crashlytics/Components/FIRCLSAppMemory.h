#import <Foundation/Foundation.h>

/**
 # Application Memory

 There are two kinds of app memory handled here, LIMIT and PRESSURE.

 ## LIMIT
 Limit (aka AppMemoryLevel) is the maximum amount of memory you can use by through
 things like malloc, object allocations and so on (mostly heap). Once you hit this high-water
 mark, the OS will terminate the application by sending it a SIGKILL signal. This is valid in
 the foreground as well as the background.

 ## PRESSURE
 Pressure (aka AppMemoryPressure) is how much the iOS ecosystem is pushing on the
 current app to be a good memory citizen. Usually, when your app is in the foreground it
 has a high priority thus doesn't get too much pressure. But there are exceptions such as
 CarPlay apps, music apps and so on that can sometimes have a higher priority than the
 foreground app, this is where pressure can come in very handy. That being said, pressure
 is mostly useful in the background, it can help you not get your app jetsamed or simply
 stay up longer for whatever reason you might have.

 My recommendation around memory pressure however is to have a robust app restoration
 system and not bother too much with background memory, as long as your foreground
 memory consumption is well handled.

 ## RECS
 Follow the memory limit with an eagle eye. Make sure you act upon the changes as they
 happen instead of all at once as with `didReceiveMemoryWarning`. Don't simple drop
 everything you have in memory. Take it step by step. An good way to do this is to keep your
 cache total cost limits in line with the memory limit.
 */
NS_ASSUME_NONNULL_BEGIN

// Notification sent when the memory level changes.
FOUNDATION_EXPORT NSNotificationName const FIRCLSAppMemoryLevelChangedNotification;

// Notification sent when the memory pressure changes.
FOUNDATION_EXPORT NSNotificationName const FIRCLSAppMemoryPressureChangedNotification;

// Notification keys that hold new and old values in the _userInfo_ dictionary.
FOUNDATION_EXPORT NSString *const FIRCLSAppMemoryNewValueKey;
FOUNDATION_EXPORT NSString *const FIRCLSAppMemoryOldValueKey;

// The memory limit level
typedef NS_ENUM(NSUInteger, FIRCLSAppMemoryLevel) {

  // Everything is A-OK, go on with your business.
  FIRCLSAppMemoryLevelNormal = 0,

  // Things are starting to get heavy.
  FIRCLSAppMemoryLevelWarn,

  // Things are getting serious, allocations should be handled carefully.
  FIRCLSAppMemoryLevelUrgent,

  // At this point you are seconds away from being terminated.
  // You likely just received or are about to receive a
  // UIApplicationDidReceiveMemoryWarningNotification.
  FIRCLSAppMemoryLevelCritical,

  // You have been or will be terminated. Out-Of-Memory. SIGKILL.
  FIRCLSAppMemoryLevelTerminal
};

// The memory pressure
typedef NS_ENUM(NSUInteger, FIRCLSAppMemoryPressure) {
  FIRCLSAppMemoryPressureNormal = 0,
  FIRCLSAppMemoryPressureWarn,
  FIRCLSAppMemoryPressureCritical,
};

/**
 AppMemory is a simple container object for everything important on Apple platforms
 surrounding memory.
 */
@interface FIRCLSAppMemory : NSObject

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

// Footprint is the amount of memory used up against the memory limit (level).
@property(readonly, nonatomic, assign) uint64_t footprint;

// Remaining is how much memory is left before the app is terminated.
// same as `os_proc_available_memory`.
// https://developer.apple.com/documentation/os/3191911-os_proc_available_memory
@property(readonly, nonatomic, assign) uint64_t remaining;

// The limi is the maximum amount of memory that can be used by this app,
// it's the value that if attained the app will be terminated.
// Do not cache this value as it can change at runtime (it's very very rare however).
@property(readonly, nonatomic, assign) uint64_t limit;

// The current memory level.
@property(readonly, nonatomic, assign) FIRCLSAppMemoryLevel level;

// The current memory pressure.
@property(readonly, nonatomic, assign) FIRCLSAppMemoryPressure pressure;

// True when the app is totally out of memory.
- (BOOL)isOutOfMemory;

// A serialized version of the instance.
- (nonnull NSDictionary<NSString *, id> *)serialize;

@end

/**
 Helpers to convert to and from pressure/level and strings.
 */
FOUNDATION_EXPORT NSString *FIRCLSAppMemoryLevelToString(FIRCLSAppMemoryLevel level);
FOUNDATION_EXPORT FIRCLSAppMemoryLevel FIRCLSAppMemoryLevelFromString(NSString *const level);

FOUNDATION_EXPORT NSString *FIRCLSAppMemoryPressureToString(FIRCLSAppMemoryPressure pressure);
FOUNDATION_EXPORT FIRCLSAppMemoryPressure
FIRCLSAppMemoryPressureFromString(NSString *const pressure);

/**
 Internal and for tests.
 */
@interface FIRCLSAppMemory ()
- (nullable instancetype)initWithJSONObject:(NSDictionary *)jsonObject;
- (instancetype)initWithFootprint:(uint64_t)footprint
                        remaining:(uint64_t)remaining
                         pressure:(FIRCLSAppMemoryPressure)pressure NS_DESIGNATED_INITIALIZER;
@end

@interface FIRCLSAppMemoryTracker : NSObject

@property(atomic, readonly) FIRCLSAppMemoryPressure pressure;
@property(atomic, readonly) FIRCLSAppMemoryLevel level;

- (void)start;
- (void)stop;

- (nullable FIRCLSAppMemory *)currentAppMemory;

@end

NS_ASSUME_NONNULL_END

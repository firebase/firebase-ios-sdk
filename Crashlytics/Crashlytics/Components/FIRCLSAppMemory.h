#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSNotificationName const FIRCLSAppMemoryLevelChangedNotification;
FOUNDATION_EXPORT NSNotificationName const FIRCLSAppMemoryPressureChangedNotification;
FOUNDATION_EXPORT NSString *const FIRCLSAppMemoryNewValueKey;
FOUNDATION_EXPORT NSString *const FIRCLSAppMemoryOldValueKey;

typedef NS_ENUM(NSUInteger, FIRCLSAppMemoryLevel) {
    FIRCLSAppMemoryLevelNormal = 0,
    FIRCLSAppMemoryLevelWarn,
    FIRCLSAppMemoryLevelUrgent,
    FIRCLSAppMemoryLevelCritical,
    FIRCLSAppMemoryLevelTerminal
};
FOUNDATION_EXPORT NSString *FIRCLSAppMemoryLevelToString(FIRCLSAppMemoryLevel level);
FOUNDATION_EXPORT FIRCLSAppMemoryLevel FIRCLSAppMemoryLevelFromString(NSString *const level);

typedef NS_ENUM(NSUInteger, FIRCLSAppMemoryPressure) {
    FIRCLSAppMemoryPressureNormal = 0,
    FIRCLSAppMemoryPressureWarn,
    FIRCLSAppMemoryPressureCritical,
};
FOUNDATION_EXPORT NSString *FIRCLSAppMemoryPressureToString(FIRCLSAppMemoryPressure pressure);
FOUNDATION_EXPORT FIRCLSAppMemoryPressure FIRCLSAppMemoryPressureFromString(NSString *const pressure);

@interface FIRCLSAppMemory : NSObject

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@property (readonly, nonatomic, assign) uint64_t footprint;
@property (readonly, nonatomic, assign) uint64_t remaining;
@property (readonly, nonatomic, assign) uint64_t limit;
@property (readonly, nonatomic, assign) FIRCLSAppMemoryLevel level;
@property (readonly, nonatomic, assign) FIRCLSAppMemoryPressure pressure;

- (BOOL)isOutOfMemory;
- (nonnull NSDictionary<NSString *,id> *)serialize;

@end

// Internal and for tests.
@interface FIRCLSAppMemory ()
- (nullable instancetype)initWithJSONObject:(NSDictionary *)jsonObject;
- (instancetype)initWithFootprint:(uint64_t)footprint remaining:(uint64_t)remaining pressure:(FIRCLSAppMemoryPressure)pressure NS_DESIGNATED_INITIALIZER;
@end

@interface FIRCLSAppMemoryTracker : NSObject

@property (atomic, readonly) FIRCLSAppMemoryPressure pressure;
@property (atomic, readonly) FIRCLSAppMemoryLevel level;

- (void)start;
- (void)stop;

- (nullable FIRCLSAppMemory *)currentAppMemory;

@end

NS_ASSUME_NONNULL_END

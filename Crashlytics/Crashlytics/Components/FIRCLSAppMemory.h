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

+ (nullable instancetype)current;
- (nullable instancetype)initWithJSONObject:(NSDictionary *)jsonObject;

@property (readonly, nonatomic, assign) uint64_t footprint;
@property (readonly, nonatomic, assign) uint64_t remaining;
@property (readonly, nonatomic, assign) uint64_t limit;
@property (readonly, nonatomic, assign) FIRCLSAppMemoryLevel level;
@property (readonly, nonatomic, assign) FIRCLSAppMemoryPressure pressure;

- (BOOL)isLikelyOutOfMemory;
- (nonnull NSDictionary<NSString *,id> *)serialize;

@end

// Internal and for tests.
@interface FIRCLSAppMemory ()
- (instancetype)initWithFootprint:(uint64_t)footprint remaining:(uint64_t)remaining pressure:(FIRCLSAppMemoryPressure)pressure;
@end

NS_ASSUME_NONNULL_END

#import <Foundation/Foundation.h>

#import "FIRLibrary.h"

@class FIRApp;
@class FIRSegmentation;

NS_ASSUME_NONNULL_BEGIN

/// Provides and creates instances of Segmentation. Used in the
/// interop registration process to keep track of Segmentation instances for each `FIRApp` instance.
@protocol FIRSegmentationProvider

/// Cached instances of Segmentation objects.
@property(nonatomic, strong) NSMutableDictionary<NSString *, FIRSegmentation *> *instances;

/// Default method for retrieving a Segmentation instance, or creating one if it doesn't exist.
- (FIRSegmentation *)segmentation;

@end

/// A concrete implementation for FIRSegmentationInterop to create Segmentation instances and
/// register with Core's component system.
@interface FIRSegmentationComponent : NSObject <FIRSegmentationProvider, FIRLibrary>

/// The FIRApp that instances will be set up with.
@property(nonatomic, weak, readonly) FIRApp *app;

/// Cached instances of Segmentation objects.
@property(nonatomic, strong) FIRSegmentation * segmentationInstance;

/// Default method for retrieving a Segmentation instance, or creating one if it doesn't exist.
- (FIRSegmentation *)segmentation;

/// Default initializer.
- (instancetype)initWithApp:(FIRApp *)app NS_DESIGNATED_INITIALIZER;

- (instancetype)init __attribute__((unavailable("Use `initWithApp:`.")));

@end

NS_ASSUME_NONNULL_END

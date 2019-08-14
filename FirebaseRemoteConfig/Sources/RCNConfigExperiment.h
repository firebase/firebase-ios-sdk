#import <Foundation/Foundation.h>

@class FIRExperimentController;
@class RCNConfigDBManager;

/// Handles experiment information update and persistence.
@interface RCNConfigExperiment : NSObject

/// Designated initializer;
- (instancetype)initWithDBManager:(RCNConfigDBManager *)DBManager
             experimentController:(FIRExperimentController *)controller NS_DESIGNATED_INITIALIZER;

/// Use `initWithDBManager:` instead.
- (instancetype)init NS_UNAVAILABLE;

/// Update/Persist experiment information from config fetch response.
- (void)updateExperimentsWithResponse:(NSArray<NSDictionary<NSString *, id> *> *)response;

/// Update experiments to Firebase Analytics when activateFetched happens.
- (void)updateExperiments;
@end

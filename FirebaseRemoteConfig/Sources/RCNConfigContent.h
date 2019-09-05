#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, RCNDBSource) {
  RCNDBSourceActive,
  RCNDBSourceDefault,
  RCNDBSourceFetched,
};

@class RCNConfigDBManager;

/// This class handles all the config content that is fetched from the server, cached in local
/// config or persisted in database.
@interface RCNConfigContent : NSObject
/// Shared Singleton Instance
+ (instancetype)sharedInstance;

/// Fetched config (aka pending config) data that is latest data from server that might or might
/// not be applied.
@property(nonatomic, readonly, copy) NSDictionary *fetchedConfig;
/// Active config that is available to external users;
@property(nonatomic, readonly, copy) NSDictionary *activeConfig;
/// Local default config that is provided by external users;
@property(nonatomic, readonly, copy) NSDictionary *defaultConfig;
/// List of features enabled on this client.
@property(nonatomic, readonly, copy) NSMutableArray *enabledFeatureKeys;
/// List of rollouts that this client is a eligible for. Refer to the rollouts 'featureEnabled' key
/// to determine if this client is included yet in the rollout.
@property(nonatomic, readonly, copy) NSMutableArray *activeRollouts;

- (instancetype)init NS_UNAVAILABLE;

/// Designated initializer;
- (instancetype)initWithDBManager:(RCNConfigDBManager *)DBManager NS_DESIGNATED_INITIALIZER;

/// Returns true if initalization succeeded.
- (BOOL)initializationSuccessful;

/// Update config content from fetch response in JSON format.
- (void)updateConfigContentWithResponse:(NSDictionary *)response
                           forNamespace:(NSString *)FIRNamespace;

/// Copy from a given dictionary to one of the data source.
/// @param fromDictionary The data to copy from.
/// @param toSource       The data source to copy to(pending/active/default).
- (void)copyFromDictionary:(NSDictionary *)fromDictionary
                  toSource:(RCNDBSource)source
              forNamespace:(NSString *)FIRNamespace;

@end

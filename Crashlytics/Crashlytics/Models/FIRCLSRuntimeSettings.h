//
//  FIRCLSRuntimeSettings.h
//  FirebaseCore
//
//  Created by Sam Edson on 4/27/20.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface FIRCLSRuntimeSettings : NSObject

/**
 * Configures the SDK to send and receive data from test backends
 */
@property(nonatomic, readonly) BOOL isDevelopmentMode;

/**
 * Forces on the GDT report uploader
 */
@property(nonatomic, readonly) BOOL isGDTEnabled;

@end

NS_ASSUME_NONNULL_END

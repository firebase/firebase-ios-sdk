//
//  FIRAppAttestationTokenHandler.h
//  FirebaseAppAttestation
//
//  Created by Maksym Malyhin on 2020-03-31.
//

#import <Foundation/Foundation.h>

@class FIRAppAttestationToken;

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(AppAttestationTokenHandler)
typedef void (^FIRAppAttestationTokenHandler)(FIRAppAttestationToken *_Nullable token,
                                              NSError *_Nullable error);

NS_ASSUME_NONNULL_END

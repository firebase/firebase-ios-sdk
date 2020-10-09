#import <TargetConditionals.h>
#if TARGET_OS_WATCH
#warning "Firebase Firestore does not support watchOS"
#endif

#ifndef RCNConfigDefines_h
#define RCNConfigDefines_h

#if defined(DEBUG)
#define RCN_MUST_NOT_BE_MAIN_THREAD()                                                 \
  do {                                                                                \
    NSAssert(![NSThread isMainThread], @"Must not be executing on the main thread."); \
  } while (0);
#else
#define RCN_MUST_NOT_BE_MAIN_THREAD() \
  do {                                \
  } while (0);
#endif

#define RCNExperimentTableKeyPayload "experiment_payload"
#define RCNExperimentTableKeyMetadata "experiment_metadata"

#endif

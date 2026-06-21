# Firebase Auth Thread Safety

This document describes how Firebase Auth maintains thread-safety. The Firebase
Auth library (not including Firebase Auth UI and Auth Provider UIs for now)
must be thread-safe, meaning developers are free to call any method in any
thread at any time. Thus, all code that may take part in race conditions must
be protected in some way.

## Local Synchronization

When contested data and accessing code is limited in scope, for example,
a mutable array accessed only by two methods, a `@synchronized` directive is
probably the simplest solution. Make sure the object to be locked on is not
`nil`, e.g., `self`.

## Global Work Queue

A more scalable solution used throughout the current code base is to execute
all potentially conflicting code in the same serial dispatch queue, which is
referred as "the auth global work queue", or in some other serial queue that
has its target queue set to this auth global work queue. This way we don't
have to think about which variables may be contested. We only need to make
sure all public APIs that may have thread-safety issues make the dispatch.
The auth global work queue is defined in
[FIRAuthGlobalWorkQueue.h](../Source/Private/FIRAuthGlobalWorkQueue.h).

In following sub-sections, we divided methods into three categories, according
to the two criteria below:

1.  Whether the method is public or private:
    *   A public method can be directly called by developers.
    *   A private method can only be called by our own code.
2.  Whether the method is synchronous or asynchronous.
    *   A synchronous method returns some value or object in the calling
        thread immediately.
    *   An asynchronous method returns nothing but calls the callback provided
        by the caller at some point in future.

### Public Asynchronous Methods

Unless it's a simple wrapper of another public asynchronous method, a public
asynchronous method shall

*   Dispatch asynchronously to the auth global work queue immediately.
*   Dispatch asynchronously to the main queue before calling the callback.
    This is to make developers' life easier so they don't have to manage
    thread-safety.

The code would look like:

```objectivec
- (void)doSomethingWithCompletion:(nullable CompletionBlock)completion {
  dispatch_async(FIRAuthGlobalWorkQueue(), ^{
    // Do things...
    if (completion) {
      dispatch_async(dispatch_get_main_queue(), ^{
        completion(args);
      });
    }
  });
}
```

### Public Synchronous Methods

A public synchronous method that needs protection shall dispatch
*synchronously* to the auth global work queue for its work. The code would
look like:

```objectivec
- (ReturnType)something {
  __block ReturnType result;
  dispatch_sync(FIRAuthGlobalWorkQueue(), ^{
    // Compute result.
    result = computedResult;
  });
  return result;
}
```

**But don't call methods protected this way from private methods, or a
deadlock would occur.** This is because you are not supposed to
`dispatch_sync` to the queue you're already in. This can be easily worked
around by creating an equivalent private synchronous method to be called by
both public and private methods and making the public synchronous method a
wrapper of that. For example,

```objectivec
- (ReturnType)somethingInternal {
  // Compute result.
  return computedResult;
}

- (ReturnType)something {
  __block ReturnType result;
  dispatch_sync(FIRAuthGlobalWorkQueue(), ^{
    result = [self somethingInternal];
  });
  return result;
}
```

### Private Methods

Generally speaking there is nothing special needed to be done for private
methods:

*   The calling code should already be in the auth global work queue.
*   The callback, if any, is provided by our own code, so it expects to called
    in the auth global work queue as well. This is usually already the case,
    unless the method pass the callback to some other asynchronous methods
    outside our library, in which case we need to manually make the callback
    called in the auth global work queue.

Just beware you can't call public synchronous methods protected by the auth
global work queue from private methods as stated in the preceding sub-section.

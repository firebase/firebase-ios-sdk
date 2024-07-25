# Using Core's Component System

FirebaseCore has a dependency injection system (referred to as "Interop") used to depend on
functionalities provided by other Firebase products (specifically, the frameworks that offer those
products). This gives the ability to depend on a typesafe interface-only API to consume without
depending on the entire product and simulates optional dependencies - depending on the definition
but not the product itself and only functioning when the product implementing that definition is
included.

## Table of Contents

- [Overview](#overview)
- [Protocol Only Frameworks](#protocol-only-frameworks)
- [Types and Core API](#types-and-core-api)
- [Registering with Core](#registering-with-core)
    - [Singletons and Instance Management](#singletons-and-instance-management)
        - [Single Instance per `FIRApp`](#single-instance-per-firapp)
            - [Framework does not provide functionality (example: Functions)](#framework-does-not-provide-functionality-(example:-functions))
            - [Framework provides functionality to other Frameworks (example: Auth)](#framework-provides-functionality-to-other-frameworks-(example:-auth))
        - [Multiple Instances per FIRApp](#multiple-instances-per-firapp)
    - [Depending on Functionality from Another Framework](#depending-on-functionality-from-another-framework)
- [Advanced Use Cases](#advanced-use-cases)
    - [Providing Multiple Components and Sharing Instances](#providing-multiple-components-and-sharing-instances)


## Overview

When a Firebase framework wants to provide functionality to another Firebase framework, it must be
done through the Interop system. Both frameworks depend on a shared protocol in the Interop folder
that describes the functionality provided by one framework and required by the other. Let's use `A`
and `B`, where `B` depends on functionality provided by `A` and the functionality is described by
protocol `AInterop`.

During configuration, `A` tells Core that it provides functionality for `AInterop` and `B` tells
Core it would like functionality `AInterop` (and specifies whether it is required or optional) as
well as how to instantiate an instance of `B`. When a developer requests `B`, FirebaseCore
instantiates `B` and passes a container that contains the instance of `A` that provides `AInterop`.

`B` has no idea what class `A` is, and it doesn't need to. All `B` needs to know is that it has an
instance of an object that conforms to `AInterop` and provides the functionality it needs.

This system allows Firebase frameworks to depend on each other in a typesafe way and allows us to
explicitly declare version dependencies on the interfaces required instead of the product's version.

## Protocol Headers

In order to share protocols between two frameworks, we introduced headers that
declare the desired protocol(s).

Both the implementing and dependent framework will import the
`<ProductName>Interop` headers: the implementing framework must conform to the protocols defined
and register it with Core, while the dependent framework will use the protocol definition to use
methods defined by it.

An Interop folder can have multiple protocols, but all should be implemented by the product it
is named after.

Protocols *can not* declare class methods. This is an intentional decision to ensure all interfaces
interact properly based on the `FIRApp` that's used.

## Types and Core API

For the rest of the documentation, it's important to be familiar with the various classes and API
provided by Core. Since the frameworks are written in Objective-C, we'll use the Objective-C names.
The Swift names are identical but dropping the `FIR` prefix.

- `@class FIRComponent`
  - A component to register with Core to be consumed by other frameworks. It declares the protocol
    offered, dependencies, and a block for Core to instantiate it.
- `@class FIRComponentContainer`
  - A container that holds different components that are registered with Core.
- `#define FIR_COMPONENT(protocol, container)` (macro)
  - The macro to request an instance conforming to a given protocol from a container. Due to
    Objective-C's lightweight generic system, the safest and most readable API is provided by a
    macro that uses internal types to give compiler warnings if a developer tries to assign the
    result to a variable with the incorrect type.
- `@protocol FIRLibrary`
  - Describes functionality for frameworks registering components in the `FIRComponentContainer` as
    well as other Core configuration functionality. It allows Core to fetch components lazily from
    the implementing framework.


## Registering with Core

Each Firebase framework should register with Core in the `+load` method of the class conforming to
`FIRLibrary`. This needs to happen at `+load` time because Core needs to resolve any
dependencies before a class has a chance to be called by a developer (if called at all).

```obj-c
#import "FirebaseCore/Extension/FirebaseCoreInternal.h"

@interface FIRFoo <FIRLibrary>
@end

@implementation FIRFoo

+ (void)load {
  // Register with Core as a library. The version should be fetched from a constant defined
  // elsewhere, but that's not covered or relevant for this example.
  [FIRApp registerInternalLibrary:self
                         withName:@"fire-foo"
                      withVersion:@"1.0.0"];
}

// TODO: Conform to `FIRLibrary`. See later sections for more information.

@end
```

### Singletons and Instance Management

All Firebase frameworks provide singleton access for convenience that map to a specific `FIRApp`:
`[FIRAuth auth]`, `[FIRFunctions functionsForApp:]`, etc. Some frameworks can also have multiple
instances per `FIRApp` such as Storage: `[FIRStorage storageForApp:URL:]`.

These instances must be created and managed by Core through the component system. This allows the
`FIRApp` lifecycle to control the lifecycle of instances associated with itself. There are different
ways to do so depending on the product's offerings.

#### Single Instance per `FIRApp`

The registration for a single instance per `FIRApp` changes if the framework provides functionality
to other frameworks or not.

##### Framework does not provide functionality (example: Functions)

In this case, the framework is a "leaf node" since no other frameworks depend on functionality from
it. It has a private, empty protocol that it uses to register with the container. Using Functions as
an example:

```obj-c
// FIRFunctions.m

/// Empty protocol to register Functions as a component with Core.
@protocol FIRFunctionsInstanceProvider
@end

/// Privately conform to the protocol for component registration.
@interface FIRFunctions () <FIRFunctionsInstanceProvider, FIRLibrary>
@end

@implementation FIRFunctions

+ (void)load {
  NSString *version = @"<# Fetch the version here #>";
  [FIRApp registerInternalLibrary:self withName:@"fire-fun" withVersion:version];
}

/// The array of components to register with Core. Since Functions is a leaf node and
/// doesn't provide any functionality to other frameworks, it should use Core for instance
/// management only.
+ (NSArray<FIRComponent *> *)componentsToRegister {
  // Each component needs a block for Core to call in order to instantiate instances of the
  // desired class.
  FIRComponentCreationBlock creationBlock =
    ^id _Nullable(FIRComponentContainer *container, BOOL *isCacheable) {
      // We want the same instance to be returned when requested from the container, enable
      // `isCacheable`.
      *isCacheable = YES;

      // Use an appropriate initializer and inject anything required from the container.
      return [[FIRFunctions alloc] initWithApp:container.app];
    };

  // Create the component that can create instances of `FIRFunctions`.
  FIRComponent *internalProvider =
      [FIRComponent componentWithProtocol:@protocol(FIRFunctionsInstanceProvider)
                            creationBlock:creationBlock];

  // Return the array of components, in this case only the internal instance provider.
  return @[ internalProvider ];
}

// The public entry point for the SDK.
+ (FIRFunctions *)functionsForApp:(FIRApp *)app {
  // Get the instance from the `FIRApp`'s container. This will create a new instance the
  // first time it is called, and since `isCacheable` is set in the component creation
  // block, it will return the existing instance on subsequent calls.
  id<FIRFunctionsInstanceProvider> instance =
      FIR_COMPONENT(FIRFunctionsInstanceProvider, app.container);

  // In the component creation block, we return an instance of `FIRFunctions`. Cast it and
  // return it.
  return (FIRFunctions *)instance;
}

// ... Other `FIRFunctions` methods.

@end
```

##### Framework provides functionality to other Frameworks (example: Auth)

This example will be very similar to the one above, but let's define a simple protocol that Auth
could conform to and provide to other frameworks:

```obj-c
// FIRAuthInterop.h in the FirebaseAuthInterop framework.

@protocol FIRAuthInterop
/// Get the current Auth user's UID. Returns nil if there is no user signed in.
- (nullable NSString *)getUserID;
@end
```

```obj-c
// FIRAuth.m in the FirebaseAuth framework.

/// Privately conform to the protocol for interop and component registration.
@interface FIRAuth () <FIRAuthInteroperable, FIRLibrary>
@end

+ (void)load {
  // Remember to register in +load!
  NSString *version = @"<# Fetch the version here #>";
  [FIRApp registerInternalLibrary:self withName:@"fire-auth" withVersion:version];
}

/// The components to register with Core.
+ (NSArray<FIRComponent *> *)componentsToRegister {
  // Provide a component that will return an instance of `FIRAuth`.
  FIRComponentCreationBlock authCreationBlock =
      ^id _Nullable(FIRComponentContainer *container, BOOL *isCacheable) {
        // Cache so the same `FIRAuth` instance is returned each time.
        *isCacheable = YES;
        return [[FIRAuth alloc] initWithApp:container.app];
      };
  FIRComponent *authInterop =
      [FIRComponent componentWithProtocol:@protocol(FIRAuthInteroperable)
                            creationBlock:authCreationBlock];
  return @[authInterop];
}

// The public entry point for the SDK.
+ (FIRAuth *)authForApp:(FIRApp *)app {
  // Use the instance from the provided app's container.
  id<FIRAuthInteroperable> auth = FIR_COMPONENT(FIRAuthInteroperable, app.container);
  return (FIRAuth *)auth;
}
```

#### Multiple Instances per `FIRApp`

Instead of directly providing an instance from the container, Firestore and similar products should
create a "provider" that stores and creates instances with the required parameters. This means a
single provider per `FIRApp`, but multiple instances are possible per provider.

```obj-c
/// Provider protocol to register with Core.
@protocol FSTFirestoreMultiDBProvider

/// Cached instances of Firestore objects.
@property(nonatomic, strong) NSMutableDictionary<NSString *, FIRFirestore *> *instances;

/// Firestore can be initialized with an app as well as a database. The instance provider is already
/// associated with a `FIRApp` so pass in any other required parameters (in this case, just the
/// database string).
- (FIRFirestore *)firestoreForDatabase:(NSString *)database;

@end
```

Instead of the Firestore class conforming to `FSTInstanceProvider`, the work can be done in a
separate class to keep `Firestore.m` cleaner.

```obj-c
/// A concrete implementation for FSTFirestoreMultiDBProvider to create Firestore instances.
@interface FSTFirestoreComponent : NSObject <FSTFirestoreMultiDBProvider, FIRLibrary>

/// The `FIRApp` that instances will be set up with.
@property(nonatomic, weak, readonly) FIRApp *app;

/// Cached instances of Firestore objects.
@property(nonatomic, strong) NSMutableDictionary<NSString *, FIRFirestore *> *instances;

/// Default method for retrieving a Firestore instance, or creating one if it doesn't exist.
- (FIRFirestore *)firestoreForDatabase:(NSString *)database;

/// Default initializer.
- (instancetype)initWithApp:(FIRApp *)app NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
@end

@implementation FSTFirestoreInstanceProvider

// Explicitly @synthesize because instances is part of the FSTInstanceProvider protocol.
@synthesize instances = _instances;

+ (void)load {
  // Remember to register in +load!
  NSString *version = @"<# Fetch the version here #>";
  [FIRApp registerInternalLibrary:self withName:@"fire-fst" withVersion:version];
}

- (instancetype)initWithApp:(FIRApp *)app {
  self = [super init];
  if (self) {
    _instances = [[NSMutableDictionary alloc] init];
    _app = app;
  }
  return self;
}

/// `FSTFirestoreMultiDBProvider` conformance.
- (FIRFirestore *)firestoreForDatabase:(NSString *)database {
  // Regular initialization code to create Firestore instances with required parameters...
}

// `FIRLibrary` conformance.
+ (NSArray<FIRComponent *> *)componentsToRegister {
  // Ignore any dependencies for simplicity in this example.
  FIRComponentCreationBlock creationBlock =
    ^id _Nullable(FIRComponentContainer *container, BOOL *isCacheable) {
      *isCacheable = YES;

      // NOTE: Instead of returning an instance of Firestore, return an instance of the
      //       instance provider.
      return [[FIRFirestoreComponent alloc] initWithApp:container.app];
    };
  FIRComponent *firestoreProvider =
      [FIRComponent componentWithProtocol:@protocol(FSTFirestoreMultiDBProvider)
                            creationBlock:creationBlock];
  return @[ firestoreProvider ];
}

@end
```

All `Firestore.m` needs to do now is call the component container from the singleton calls:

```obj-c
+ (instancetype)firestoreForApp:(FIRApp *)app database:(NSString *)database {
  id<FSTFirestoreMultiDBProvider> provider =
      FIR_COMPONENT(FSTFirestoreMultiDBProvider, app.container);
  return [provider firestoreForDatabase:database];
}
```

### Depending on Functionality from Another Framework

*If you haven't already read [Registering with Core](#registering-with-core), please do so until you
get back to this spot as it lays the groundwork necessary to understand this section.*

Adding dependencies is easy once components are registered with Core. Let's take the example from
Functions above and add a dependency to `FIRAuthInterop` defined above.

**Important**: You will also need to add `FirebaseAuthInterop` headers to your
               product's podspec `source_files` attribute for CocoaPods and something
               comparable for any other package manager supported. Note, for Swift Package Manager,
               nothing special is needed as long as all the pods and headers are in the same repo.

Before adding the dependency on `FIRAuthInterop`.

```obj-c
+ (NSArray<FIRComponent *> *)componentsToRegister {
  FIRComponentCreationBlock creationBlock =
    ^id _Nullable(FIRComponentContainer *container, BOOL *isCacheable) {
      *isCacheable = YES;
      return [[FIRFunctions alloc] initWithApp:container.app];
    };

  FIRComponent *internalProvider =
      [FIRComponent componentWithProtocol:@protocol(FIRFunctionsInstanceProvider)
                            creationBlock:creationBlock];

  return @[ internalProvider ];
}
```

After adding the dependency on `FIRAuthInterop`. See comments with "ADDED:".

```obj-c
+ (NSArray<FIRComponent *> *)componentsToRegister {
  FIRComponentCreationBlock creationBlock =
    ^id _Nullable(FIRComponentContainer *container, BOOL *isCacheable) {
      *isCacheable = YES;

      // ADDED: Retrieve an instance that conforms to `FIRAuthInterop` from the container.
      id<FIRAuthInterop> auth = FIR_COMPONENT(FIRAuthInterop, container);

      // ADDED: Note the constructor has a new parameter: auth. It's good practice to inject
      //        the instance needed in the constructor instead of pulling it from the app
      //        passed in. This allows for better unit testing with fakes since any object
      //        can conform to `FIRAuthInterop` and be verified easily.
      return [[FIRFunctions alloc] initWithApp:container.app auth:auth];
    };

  // ADDED: A longer constructor is used to instantiate the `FIRComponent`; this time
  //        it includes instantiation timing and an array of dependencies. The timing
  //        allows components to be initialized upon configure time or lazily, when
  //        it is requested from the container. Pass in the `auth` dependency created
  //        above.
  FIRComponent *internalProvider =
      [FIRComponent componentWithProtocol:@protocol(FIRFunctionsInstanceProvider)
                      instantiationTiming:FIRInstantiationTimingLazy
                            creationBlock:creationBlock];

  return @[ internalProvider ];
}
```

Based on the new constructor, Functions can now use the `auth` instance as defined by the
protocol:

```obj-c
NSString *userID = [auth getUserID];
if (userID) {
  // Auth is available and a user is signed in!
}
```

## Advanced Use Cases

### Providing Multiple Components and Sharing Instances

Consider a situation where a framework wants to offer functionality defined in multiple protocols
with the same instance. For example, Auth could provide `FIRAuthUserInterop` and
`FIRAuthSignInInterop`. If a single Auth instance should be shared between those two protocols, the
system currently doesn't work.

In order to alleviate this, Auth could create a third private protocol
(`FIRAuthCombinedInterop`) that conforms to both `FIRAuthUserInterop` and `FIRAuthSignInInterop` and
becomes a dependency for each of those two components and returned in the component creation block.
An abbreviated code sample:

```obj-c

+ (NSArray<FIRComponent *> *)componentsToRegister {
  // Standard creation block to get an instance of Auth.
  FIRComponentCreationBlock authBlock =
    ^id _Nullable(FIRComponentContainer *container, BOOL *isCacheable) {
      *isCacheable = YES;
      return [[FIRAuth alloc] initWithApp:container.app];
    };

  FIRComponentCreationBlock combinedBlock =
    ^id _Nullable(FIRComponentContainer *container, BOOL *isCacheable) {
      // No need to cache, let it use the cached value from the combined component.
      return FIR_COMPONENT(FIRAuthCombinedInterop, container);
    };

  // Declare the three components provided.
  FIRComponent *authComponent =
      [FIRComponent componentWithProtocol:@protocol(FIRAuthCombinedInterop)
                            creationBlock:authBlock];

  // Both the user and sign in components depend on the previous component as
  // declared in the dependency above.

  FIRComponent *userComponent =
      [FIRComponent componentWithProtocol:@protocol(FIRAuthUserInterop)
                      instantiationTiming:FIRInstantiationTimingLazy
                            creationBlock:combinedBlock];

  FIRComponent *signInComponent =
      [FIRComponent componentWithProtocol:@protocol(FIRAuthSignInInterop)
                      instantiationTiming:FIRInstantiationTimingLazy
                            creationBlock:combinedBlock];

  return @[ authComponent, userComponent, signInComponent ];
}
```

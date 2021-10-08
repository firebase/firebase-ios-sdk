# Firebase Testing Support (for automated test developers)

Firebase Testing Support is a collection of libraries that provide type definitions and tools required for writing tests for code that uses Firebase, e.g.:

- Instances of types like `Query` cannot be created with a simple constructor which makes unit testing of the code that depends on them difficult/impossible. Firestore Testing Support lib provides a type `QueryFake` that can be instantiated and used instead of actual `Query` instances in the tests.

## Usage

### Add dependency to your test target

#### Swift Package Manager

```
dependencies: [
    ...
    "FirebaseFirestoreTestingSupport"
],

```

### Use the fake types in the tests instead of real types

See test for example, e.g. [QueryFakeTests.swift](../FirebaseTestingSupport/Firestore/Tests/QueryFakeTests.swift).

## Development

### Generate project


#### Swift Package Manager

- Open the main package definition:

```
xed Package.swift
```

- Select (or add if not exists yet) a scheme for the test target, e.g. `FirestoreTestingSupportTests`

- make required modifications and run tests as needed.
# Building with CMake

Some portions of this repository are portable beyond iOS and can be built using
CMake.

## Dependencies

You need:
  * A C++ compiler
  * `cmake`

### macOS

You need [Xcode](https://developer.apple.com/xcode/), which you can get from
the Mac App Store.

You can get other development tools via [homebrew](https://brew.sh). Adjust as
needed for other package managers.

```
brew install cmake
```

### Ubuntu

Ubuntu Trusty includes CMake 2.8.12 which should be sufficient. Newer versions
are fine too.

```
sudo apt-get install cmake
```

### Windows

An easy way to get development tools is via [Chocolatey](https://chocolatey.org/).

Unfortunately, the `cmake.install` package is semi-broken, so use the portable
version.

```
choco install cmake.portable
```

## Setup

CMake builds out-of source, so create a separate build directory for the target
you want to work on.

```
mkdir build
cd build
cmake ..
```

You only need to do this once.

## Initial Build

The first build will download, compile all dependencies of the project, and run
an initial battery of tests.

To perform the initial build, you can use CMake

```
cmake --build .
```

or use the underlying build system, e.g.

```
make -j all
```

## Working with a Project

Once the initial build has completed, you can work with a specific subproject
to make changes and test just that project in isolation.

For example, to work with just Firestore,

```
cd build/Firestore
make -j all test
```

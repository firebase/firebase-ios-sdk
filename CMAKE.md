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

## Testing

Once CMake has run once, you can just run `make` repeatedly and it will
regenerate Makefiles as needed.

To build everything and run tests:
```
make -j all test
```

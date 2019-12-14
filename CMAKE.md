# Building with CMake

Some portions of this repository are portable beyond iOS and can be built using
CMake.

## Dependencies

You need:

  * A C++11 compiler
  * CMake 3.9
  * Ninja (optional)
  * CocoaPods (macOS-only)

For dependencies:

  * Go
  * Perl
  * Yasm (Windows-only)


### macOS

You need [Xcode](https://developer.apple.com/xcode/), which you can get from
the Mac App Store.

You can get other development tools via [homebrew](https://brew.sh). Adjust as
needed for other package managers.

```bash
brew install cmake
brew install golang
brew install ccache     # optional
brew install ninja      # optional
gem install cocoapods   # may need sudo
```

Note that CocoaPods is only needed for its ruby library, no Podfiles actually
need to be set up and no `pod install` is required for the CMake build.


### Ubuntu

If you're on a relatively recent Linux, the system-provided CMake may be
sufficient.

```bash
sudo apt-get install build-essential
sudo apt-get install cmake
sudo apt-get install ccache       # optional
sudo apt-get install ninja-build  # optional

sudo apt-get install golang
```

### Windows

You need [Visual Studio](https://visualstudio.microsoft.com/vs/). The 2017
Community edition building for x64 gets regular testing. We're working on
support for Visual Studio 2015.

An easy way to get development tools is via [Chocolatey](https://chocolatey.org/).

```cmd
choco install git
choco install cmake --installargs 'ADD_CMAKE_TO_PATH=System'
choco install ninja

# Build scripts use bash and python
choco install msys2

# Required for building gRPC and its dependencies
choco install activeperl
choco install golang
choco install nasm

# Optional: can speed up builds
choco install openssl
```

## Building

CMake builds out-of source, so create a separate build directory for the target
you want to work on.

The first time you build, it will download all dependencies of the project so
it might take a while.


### Basic build

The basic shape of the build is to:
  * create and enter the build tree
  * run CMake to prepare the build tree
  * build sources
  * run tests

On most systems that looks like this:

```bash
mkdir build
cd build
cmake ..
cmake --build .
cmake --build . --target test
```

### Useful flags to pass to CMake

Standard CMake flags:

  * `-G Ninja` -- build with Ninja instead of the default.
  * `-DCMAKE_BUILD_TYPE=Release` -- optimized build

Dependencies:

  * `-DOPENSSL_ROOT_DIR=path/to/openssl` -- where to find a pre-built OpenSSL,
    if you prefer that over the default BoringSSL. See `FindOpenSSL.cmake` in
    your CMake distribution.
  * `-DZLIB_ROOT=path/to/zlib` -- where to find a pre-built zlib, if you prefer
    that. See `FindZLIB.cmake` in your CMake distribution.

Firebase-specific goodies:

  * `-DFIREBASE_DOWNLOAD_DIR:PATH=.downloads` -- put downloaded files outside
    the build tree.
  * `-DWITH_ASAN=ON` -- enable the address sanitizer (Clang, GCC)
  * `-DWITH_TSAN=ON` -- enable the thread sanitizer (Clang, GCC)
  * `-DWITH_UBSAN=ON` -- enable the undefined behavior sanitizer (Clang, GCC)

For example:

On Mac or Linux:
```bash
cmake -H. -Bbuild -G Ninja -DFIREBASE_DOWNLOAD_DIR:PATH=$HOME/.downloads
cd build
ninja && ninja test
```

On Windows:
```cmd
mkdir %USERPROFILE%\AppData\LocalLow\CMake
cmake -H. -Bbuild -G Ninja ^
    -DFIREBASE_DOWNLOAD_DIR:PATH=%USERPROFILE%\AppData\LocalLow\CMake ^
    -DOPENSSL_ROOT_DIR:Path="c:\Program Files\OpenSSL-Win64"
```

# Building with CMake

Some portions of this repository are portable beyond iOS and can be built using
CMake.

## Dependencies

You need:
  * `cmake`
  * `ninja` (optional)

Install with your favorite package manager for your platform, e.g. homebrew on
macOS, chocolatey on Windows, apt-get on Ubuntu, etc.

## Setup

Prepare a working directory
```
mkdir build
cd build
```

Configure the build
```
cmake -G Ninja ..
```

## Testing
```
ninja test
```

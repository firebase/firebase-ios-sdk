# Build Firebase static frameworks

[build.swift](build.swift) is a script that will build a static framework for
one or more of FirebaseAuth, FirebaseCore, FirebaseDatabase, FirebaseMessaging,
and FirebaseStorage.

Frameworks built with this script can be used alongside the official [Firebase
CocoaPods](https://cocoapods.org/pods/Firebase) and
[zip](https://firebase.google.com/docs/ios/setup#frameworks) distributions.


## Usage

The CocoaPods version must be at least 1.3.1.

```
$ pod --version
```

```
$ ./build.swift -f FirebaseAuth -f FirebaseMessaging ....
```
or
```
$ ./build.swift -all
```

The script will output the location of the new frameworks when it finishes
the build.


## Issues

* Xcode's module cache may not properly update after a framework is replaced.
The workaround is `rm -rf ~/Library/Developer/Xcode/DerivedData/ModuleCache/`

* To replace the 4.0.0 version of FirebaseDatabase, the leveldb-library pod
will need to be linked in. Add `pod 'leveldb-library'` to your Podfile.

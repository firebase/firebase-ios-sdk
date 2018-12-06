# Symbol Collision Tests

## Introductions

This directory provides a project that is used to test a set of CocoaPods for symbol
collisions daily.  It's controlled by the cron functionality in
[.travis.ml](../.travis.yml).

### Contributing

If you'd like to add a CocoaPod to the tests, add it to the
[Podfile](Podfile), test that it builds locally and then send a PR.

### Future

Currently the tests primarily test static libraries and static frameworks.
`use_frameworks!` and 
[`use_module_headers!`](http://blog.cocoapods.org/CocoaPods-1.5.0/) can be
added for better dynamic library and Swift pod testing.

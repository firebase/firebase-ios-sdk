# Temporary podspec for Firebase tvOS porting. This should be merged to
# https://github.com/firebase/leveldb-library-podspec before Firebase tvOS
# goes live.

Pod::Spec.new do |s|
  s.name         =  'leveldb-library'
  s.version      =  '1.20'
  s.license      =  'New BSD'
  s.summary      =  'A fast key-value storage library '
  s.description  =  'LevelDB is a fast key-value storage library written at Google that provides ' +
                    'an ordered mapping from string keys to string values.'
  s.homepage     =  'https://github.com/google/leveldb'
  s.authors      =  'The LevelDB Authors'

  s.ios.deployment_target = '5.0'
  s.osx.deployment_target = '10.7'
  s.tvos.deployment_target = '10.0'

  s.source       =  { 
    :git => 'https://github.com/google/leveldb.git',
    :tag => 'v' + s.version.to_s
  }

  s.requires_arc = false

  s.compiler_flags = '-DOS_MACOSX', '-DLEVELDB_PLATFORM_POSIX'

  s.xcconfig = {
    'HEADER_SEARCH_PATHS' => '"${PODS_ROOT}/leveldb-library" ' +
                             '"${PODS_ROOT}/leveldb-library/include"',

    # Disable warnings introduced by Xcode 8.3 and Xcode 9
    'WARNING_CFLAGS' => '-Wno-shorten-64-to-32 -Wno-comma -Wno-unreachable-code ' +
                        '-Wno-conditional-uninitialized',

    # Prevent naming conflicts between leveldb headers and system headers
    'USE_HEADERMAP' => 'No',
  }

  s.header_dir = "leveldb"
  s.source_files = [
    "db/*.{cc,h}",
    "port/*.{cc,h}",
    "table/*.{cc,h}",
    "util/*.{cc,h}",
    "include/leveldb/*.h"
  ]

  s.public_header_files = [
    "include/leveldb/*.h"
  ]

  s.exclude_files = [
    "**/*_test.cc",
    "**/*_bench.cc",
    "db/leveldbutil.cc",
    "port/win"
  ]

  s.library = 'c++'
end

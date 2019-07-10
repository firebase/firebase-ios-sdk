Pod::Spec.new do |s|
  s.name             = 'FirebaseFirestore'
  s.version          = '1.4.0'
  s.summary          = 'Google Cloud Firestore for iOS'

  s.description      = <<-DESC
Google Cloud Firestore is a NoSQL document database built for automatic scaling, high performance, and ease of application development.
                       DESC

  s.homepage         = 'https://developers.google.com/'
  s.license          = { :type => 'Apache', :file => 'LICENSE' }
  s.authors          = 'Google, Inc.'

  s.source           = {
    :git => 'https://github.com/firebase/firebase-ios-sdk.git',
    :tag => 'Firestore-' + s.version.to_s
  }

  s.ios.deployment_target = '8.0'
  s.osx.deployment_target = '10.11'
  s.tvos.deployment_target = '10.0'

  s.cocoapods_version = '>= 1.4.0'
  s.static_framework = true
  s.prefix_header_file = false

  s.source_files = [
    'Firestore/Source/**/*.{h,m,mm}',
    'Firestore/Protos/nanopb/**/*.{h,cc}',
    'Firestore/Protos/objc/**/*.[hm]',
    'Firestore/core/include/**/*.{h,cc,mm}',
    'Firestore/core/src/**/*.{h,cc,mm}',
    'Firestore/third_party/Immutable/*.[mh]',
  ]
  s.requires_arc = [
    'Firestore/Source/**/*',
    'Firestore/core/src/**/*.mm',
    'Firestore/third_party/Immutable/*.[mh]'
  ]
  s.exclude_files = [
    'Firestore/third_party/Immutable/Tests/**',

    # Exclude alternate implementations for other platforms
    'Firestore/core/src/firebase/firestore/api/input_validation_std.cc',
    'Firestore/core/src/firebase/firestore/remote/connectivity_monitor_noop.cc',
    'Firestore/core/src/firebase/firestore/remote/grpc_root_certificate_finder_generated.cc',
    'Firestore/core/src/firebase/firestore/util/filesystem_win.cc',
    'Firestore/core/src/firebase/firestore/util/hard_assert_stdio.cc',
    'Firestore/core/src/firebase/firestore/util/log_stdio.cc',
    'Firestore/core/src/firebase/firestore/util/secure_random_openssl.cc'
  ]
  s.public_header_files = 'Firestore/Source/Public/*.h'

  s.dependency 'FirebaseAuthInterop', '~> 1.0'
  s.dependency 'FirebaseCore', '~> 6.0'
  s.dependency 'gRPC-C++', '0.0.9'
  s.dependency 'leveldb-library', '~> 1.20'
  s.dependency 'Protobuf', '~> 3.1'
  s.dependency 'nanopb', '~> 0.3.901'

  s.ios.frameworks = 'MobileCoreServices', 'SystemConfiguration'
  s.osx.frameworks = 'SystemConfiguration'
  s.tvos.frameworks = 'SystemConfiguration'

  s.library = 'c++'
  s.pod_target_xcconfig = {
    'CLANG_CXX_LANGUAGE_STANDARD' => 'c++0x',
    'GCC_C_LANGUAGE_STANDARD' => 'c99',
    'GCC_PREPROCESSOR_DEFINITIONS' =>
      "FIRFirestore_VERSION=#{s.version} " +
      'GPB_USE_PROTOBUF_FRAMEWORK_IMPORTS=1 ' +
      # The nanopb pod sets these defs, so we must too. (We *do* require 16bit
      # (or larger) fields, so we'd have to set at least PB_FIELD_16BIT
      # anyways.)
      'PB_FIELD_32BIT=1 PB_NO_PACKED_STRUCTS=1 PB_ENABLE_MALLOC=1',
    'HEADER_SEARCH_PATHS' =>
      '"${PODS_TARGET_SRCROOT}" ' +
      '"${PODS_TARGET_SRCROOT}/Firestore/Source/Public" ' +
      '"${PODS_TARGET_SRCROOT}/Firestore/third_party/abseil-cpp" ' +
      '"${PODS_ROOT}/nanopb" ' +
      '"${PODS_TARGET_SRCROOT}/Firestore/Protos/nanopb"',
  }

  # Generate a version of the config.h header suitable for building with
  # CocoaPods.
  s.prepare_command = <<-CMD
    sed '/^#cmakedefine/ d' \
        Firestore/core/src/firebase/firestore/util/config.h.in > \
        Firestore/core/src/firebase/firestore/util/config.h
  CMD

  s.compiler_flags = '$(inherited) -Wreorder -Werror=reorder'

  s.subspec 'abseil-cpp' do |ss|
    ss.preserve_path = [
      'Firestore/third_party/abseil-cpp/absl'
    ]
    ss.source_files = [
      'Firestore/third_party/abseil-cpp/**/*.cc'
    ]
    ss.exclude_files = [
      # Exclude tests and benchmarks from the framework.
      'Firestore/third_party/abseil-cpp/**/*_benchmark.cc',
      'Firestore/third_party/abseil-cpp/**/*test*.cc',
      'Firestore/third_party/abseil-cpp/absl/hash/internal/print_hash_of.cc',

      # Exclude CMake-related everything, including tests
      'Firestore/third_party/abseil-cpp/CMake/**/*.cc',

      # Avoid the debugging package which uses code that isn't portable to
      # ARM (see stack_consumption.cc) and uses syscalls not available on
      # tvOS (e.g. sigaltstack).
      'Firestore/third_party/abseil-cpp/absl/debugging/**/*.cc',

      # Dropping the debugging package prevents downstream usage of this in the
      # abseil sources.
      'Firestore/third_party/abseil-cpp/absl/container/internal/hashtable_debug*',
      'Firestore/third_party/abseil-cpp/absl/container/internal/hashtablez_sampler*',

      # Exclude the synchronization package because it's dead weight: we don't
      # write the kind of heavily threaded code that might benefit from it.
      'Firestore/third_party/abseil-cpp/absl/synchronization/**/*.cc',
    ]

    ss.library = 'c++'
    ss.compiler_flags = '$(inherited) ' +
      '-Wno-comma ' +
      '-Wno-range-loop-analysis ' +
      '-Wno-shorten-64-to-32'
  end
end

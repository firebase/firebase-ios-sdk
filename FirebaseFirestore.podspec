Pod::Spec.new do |s|
  s.name             = 'FirebaseFirestore'
  s.version          = '0.12.5'
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

  s.cocoapods_version = '>= 1.4.0'
  s.static_framework = true
  s.prefix_header_file = false

  s.source_files = [
    'Firestore/Source/**/*',
    'Firestore/Port/**/*',
    'Firestore/Protos/nanopb/**/*.[hc]',
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
    'Firestore/Port/*test.cc',
    'Firestore/third_party/Immutable/Tests/**',

    # Exclude alternate implementations for other platforms
    'Firestore/core/src/firebase/firestore/util/hard_assert_stdio.cc',
    'Firestore/core/src/firebase/firestore/util/log_stdio.cc',
    'Firestore/core/src/firebase/firestore/util/secure_random_openssl.cc'
  ]
  s.public_header_files = 'Firestore/Source/Public/*.h'

  s.dependency 'FirebaseCore', '~> 5.0'
  s.dependency 'gRPC-ProtoRPC', '~> 1.0'
  s.dependency 'leveldb-library', '~> 1.18'
  s.dependency 'Protobuf', '~> 3.1'
  s.dependency 'nanopb', '~> 0.3.8'

  s.frameworks = 'MobileCoreServices'
  s.library = 'c++'
  s.pod_target_xcconfig = {
    'GCC_PREPROCESSOR_DEFINITIONS' =>
      "FIRFirestore_VERSION=#{s.version} " +
      'GPB_USE_PROTOBUF_FRAMEWORK_IMPORTS=1 ' +
      # The nanopb pod sets these defs, so we must too. (We *do* require 16bit
      # (or larger) fields, so we'd have to set at least PB_FIELD_16BIT
      # anyways.)
      'PB_FIELD_32BIT=1 PB_NO_PACKED_STRUCTS=1',
    'HEADER_SEARCH_PATHS' =>
      '"${PODS_TARGET_SRCROOT}" ' +
      '"${PODS_TARGET_SRCROOT}/Firestore/third_party/abseil-cpp" ' +
      '"${PODS_ROOT}/nanopb" ' +
      '"${PODS_TARGET_SRCROOT}/Firestore/Protos/nanopb"',
  }

  s.prepare_command = <<-CMD
    # Generate a version of the config.h header suitable for building with
    # CocoaPods.
    sed '/^#cmakedefine/ d' \
        Firestore/core/src/firebase/firestore/util/config.h.in > \
        Firestore/core/src/firebase/firestore/util/config.h
  CMD

  s.subspec 'abseil-cpp' do |ss|
    ss.preserve_path = [
      'Firestore/third_party/abseil-cpp/absl'
    ]
    ss.source_files = [
      'Firestore/third_party/abseil-cpp/**/*.cc'
    ]
    ss.exclude_files = [
      'Firestore/third_party/abseil-cpp/**/*_test.cc',
    ]

    ss.library = 'c++'
    ss.compiler_flags = '$(inherited) ' + '-Wno-comma -Wno-range-loop-analysis'
  end
end

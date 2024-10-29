Pod::Spec.new do |s|
  s.name             = 'FirebaseFirestoreCpp'
  s.version          = '11.5.0'
  s.summary          = 'Google Cloud Firestore'

  s.description      = <<-DESC
Google Cloud Firestore is a NoSQL document database built for automatic scaling, high performance, and ease of application development.
                       DESC

  s.homepage         = 'https://developers.google.com/'
  s.license          = { :type => 'Apache-2.0', :file => 'Firestore/LICENSE' }
  s.authors          = 'Google, Inc.'

  s.source           = {
    :git => 'https://github.com/firebase/firebase-ios-sdk.git',
    :tag => 'CocoaPods-' + s.version.to_s
  }

  s.ios.deployment_target = '13.0'
  s.osx.deployment_target = '10.15'
  s.tvos.deployment_target = '13.0'

  s.swift_version = '5.9'

  s.cocoapods_version = '>= 1.12.0'
  s.prefix_header_file = false

  s.public_header_files = 'Firestore/core/swift/umbrella/*.h'

  s.source_files = [
    'Firestore/core/swift/**/*.{cc,h}'
  ]

  abseil_version = '~> 1.20240116.1'
  s.dependency 'abseil/algorithm', abseil_version
  s.dependency 'abseil/base', abseil_version
  s.dependency 'abseil/container/flat_hash_map', abseil_version
  s.dependency 'abseil/memory', abseil_version
  s.dependency 'abseil/meta', abseil_version
  s.dependency 'abseil/strings/strings', abseil_version
  s.dependency 'abseil/time', abseil_version
  s.dependency 'abseil/types', abseil_version

  s.ios.frameworks = 'SystemConfiguration', 'UIKit'
  s.osx.frameworks = 'SystemConfiguration'
  s.tvos.frameworks = 'SystemConfiguration', 'UIKit'

  s.library = 'c++'
  s.pod_target_xcconfig = {
    'CLANG_CXX_LANGUAGE_STANDARD' => 'c++14',
    'CLANG_CXX_LIBRARY' => 'libc++',
    'GCC_C_LANGUAGE_STANDARD' => 'c99',
    'GCC_PREPROCESSOR_DEFINITIONS' =>
      "FIRFirestore_VERSION=#{s.version} " +
      # The nanopb pod sets these defs, so we must too. (We *do* require 16bit
      # (or larger) fields, so we'd have to set at least PB_FIELD_16BIT
      # anyways.)
      'PB_FIELD_32BIT=1 PB_NO_PACKED_STRUCTS=1 PB_ENABLE_MALLOC=1',
    'HEADER_SEARCH_PATHS' =>
      '"${PODS_TARGET_SRCROOT}" ' +
      '"${PODS_TARGET_SRCROOT}/Firestore/core/swift" '
  }

  s.compiler_flags = '$(inherited) -Wreorder -Werror=reorder -Wno-comma'
end

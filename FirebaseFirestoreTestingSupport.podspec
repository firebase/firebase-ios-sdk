Pod::Spec.new do |s|
  s.name                    = 'FirebaseFirestoreTestingSupport'
  s.version                 = '1.0.0'
  s.summary                 = 'Firebase SDKs testing support types and utilities.'

  s.description      = <<-DESC
  Type declarations and utilities needed for unit testing of the code dependent on Firebase SDKs.
  This podspec is for internal testing only and should not be published.
                       DESC

  s.homepage                = 'https://developers.google.com/'
  s.license                 = { :type => 'Apache-2.0', :file => 'LICENSE' }
  s.authors                 = 'Google, Inc.'

  s.source                  = {
    :git => 'https://github.com/Firebase/firebase-ios-sdk.git',
    :tag => 'CocoaPods-' + s.version.to_s
  }

  ios_deployment_target = '13.0'
  osx_deployment_target = '10.15'
  tvos_deployment_target = '13.0'
  watchos_deployment_target = '7.0'

  s.swift_version = '5.9'

  s.ios.deployment_target = ios_deployment_target
  s.osx.deployment_target = osx_deployment_target
  s.tvos.deployment_target = tvos_deployment_target
  s.watchos.deployment_target = watchos_deployment_target

  s.cocoapods_version       = '>= 1.12.0'
  s.prefix_header_file      = false
  s.requires_arc            = true

  base_dir = 'FirebaseTestingSupport/Firestore/'

  s.source_files = [
    base_dir + 'Sources/**/*.{m,mm,h}',
    'Firestore/Source/API/*\+Internal.h'
  ]

  s.public_header_files = base_dir + '**/*.h'

  s.dependency 'FirebaseFirestore', '~> 11.0'

  s.pod_target_xcconfig = {
    'GCC_C_LANGUAGE_STANDARD' => 'c99',
    'OTHER_CFLAGS' => '-fno-autolink',
    'HEADER_SEARCH_PATHS' =>
      '"${PODS_TARGET_SRCROOT}" '
  }

  s.test_spec 'unit' do |unit_tests|
    unit_tests.scheme = { :code_coverage => true }
    unit_tests.platforms = {:ios => ios_deployment_target, :osx => osx_deployment_target, :tvos => tvos_deployment_target}
    unit_tests.source_files = [
      base_dir + 'Tests/**/*.swift'
    ]
  end
end

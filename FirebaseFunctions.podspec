Pod::Spec.new do |s|
  s.name             = 'FirebaseFunctions'
  s.version          = '8.10.0'
  s.summary          = 'Cloud Functions for Firebase'

  s.description      = <<-DESC
Cloud Functions for Firebase.
                       DESC

  s.homepage         = 'https://developers.google.com/'
  s.license          = { :type => 'Apache', :file => 'LICENSE' }
  s.authors          = 'Google, Inc.'
  s.source           = {
    :git => 'https://github.com/firebase/firebase-ios-sdk.git',
    :tag => 'CocoaPods-' + s.version.to_s
  }

  s.ios.deployment_target = '10.0'
  s.osx.deployment_target = '10.12'
  s.tvos.deployment_target = '10.0'
  s.watchos.deployment_target = '6.0'

  s.cocoapods_version = '>= 1.4.0'
  s.prefix_header_file = false

  s.source_files = [
    'FirebaseFunctions/Sources/**/*',
    'Interop/Auth/Public/*.h',
    'FirebaseAppCheck/Sources/Interop/*.h',
    'FirebaseCore/Sources/Private/*.h',
    'FirebaseMessaging/Sources/Interop/FIRMessagingInterop.h',
  ]
  s.public_header_files = 'FirebaseFunctions/Sources/Public/FirebaseFunctions/*.h'

  s.dependency 'FirebaseCore', '~> 8.0'
  s.dependency 'GTMSessionFetcher/Core', '~> 1.5'

  s.pod_target_xcconfig = {
    'GCC_C_LANGUAGE_STANDARD' => 'c99',
    'HEADER_SEARCH_PATHS' => '"${PODS_TARGET_SRCROOT}"'
  }

  s.test_spec 'unit' do |unit_tests|
    unit_tests.scheme = { :code_coverage => true }
    unit_tests.source_files = [
      'FirebaseFunctions/Tests/Unit/*.[mh]',
      'FirebaseFunctions/Tests/SwiftUnit/**/*',
      'SharedTestUtilities/FIRAuthInteropFake*',
      'SharedTestUtilities/FIRMessagingInteropFake*',
      'SharedTestUtilities/AppCheckFake/*.[mh]',
  ]
  end

  s.test_spec 'integration' do |int_tests|
    int_tests.scheme = { :code_coverage => true }
    int_tests.source_files = 'FirebaseFunctions/Tests/Integration/*.[mh]',
                             'SharedTestUtilities/FIRAuthInteropFake*',
                             'SharedTestUtilities/FIRMessagingInteropFake*'
  end

  #  Uncomment to use pod gen to run the Swift Integration tests. This can't be
  #  committed because of the dependency on the unpublished FirebaseFunctionsTestingSupport.
  #  Alternatively, use Swift Package Manager to run the swift integration tests locally.
  #
  #   s.test_spec 'swift-integration' do |swift_int|
  #   swift_int.platforms = {:ios => '15.0', :osx => '12.0', :tvos => '15.0', :watchos => '8.0'}
  #   swift_int.scheme = { :code_coverage => true }
  #   swift_int.dependency 'FirebaseFunctionsTestingSupport'
  #   swift_int.source_files = 'FirebaseFunctions/Tests/SwiftIntegration/*',
  #                            'FirebaseTestingSupport/Functions/Sources/*'
  # end
end

#
# Be sure to run `pod lib lint FirebaseAppDistributionInternal.podspec' to ensure this is a
# valid spec before submitting.
#

Pod::Spec.new do |s|
    s.name             = 'FirebaseAppDistributionInternal'
    s.version          = '10.5.0-beta'
    s.summary          = 'Firebase App Distribution Internal for Swift implementations'

    s.description      = <<-DESC
    Not for public use.
    SDK for Swift code in Firebase App Distribution.
                         DESC

    s.homepage         = 'https://firebase.google.com'
    s.license          = { :type => 'Apache-2.0', :file => 'LICENSE' }
    s.authors          = 'Google, Inc.'

    s.source           = {
      :git => 'https://github.com/firebase/firebase-ios-sdk.git',
      :tag => 'CocoaPods-' + s.version.to_s
    }
    s.social_media_url = 'https://twitter.com/Firebase'

    ios_deployment_target = '11.0'

    s.swift_version = '5.3'

    s.ios.deployment_target = '11.0'

    s.cocoapods_version = '>= 1.4.0'
    s.prefix_header_file = false

    s.framework = 'Foundation'
    s.ios.framework = 'UIKit'

    base_dir = "FirebaseAppDistributionInternal/"
    s.source_files = [
      base_dir + 'Sources/**/*.{swift,h,m}',
    ]

    s.ios.resource_bundles = {
        'AppDistributionInternalResources' => [
           base_dir + 'Resources/FIRAppDistributionInternalStoryboard.storyboard',
         ]
      }

    s.dependency 'FirebaseCore', '~> 10.0'
    s.dependency 'FirebaseCoreExtension', '~> 10.0'
    s.dependency 'FirebaseInstallations', '~> 10.0'

    s.pod_target_xcconfig = {
      'GCC_C_LANGUAGE_STANDARD' => 'c99',
      'HEADER_SEARCH_PATHS' => '"${PODS_TARGET_SRCROOT}"',
    }

    s.test_spec 'unit' do |unit_tests|
      unit_tests.scheme = { :code_coverage => true }
      unit_tests.source_files = [
        'FirebaseAppDistributionInternal/Tests/Unit/*.swift',
        'FirebaseAppDistributionInternal/Tests/Unit/*.h',
      ]
     end
  end

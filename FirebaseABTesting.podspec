Pod::Spec.new do |s|
  s.name             = 'FirebaseABTesting'
  s.version          = '11.7.0'
  s.summary          = 'Firebase ABTesting'

  s.description      = <<-DESC
A/B testing is a Firebase service that lets you run experiments across users of
your mobile apps. It lets you learn how well one or more changes to
your app work with a smaller set of users before you roll out changes to all
users. You can run experiments to find the most effective ways to use
Firebase Cloud Messaging and Firebase Remote Config in your app.
                       DESC

  s.homepage         = 'https://firebase.google.com'
  s.license          = { :type => 'Apache-2.0', :file => 'LICENSE' }
  s.authors          = 'Google, Inc.'

  s.source           = {
    :git => 'https://github.com/firebase/firebase-ios-sdk.git',
    :tag => 'CocoaPods-' + s.version.to_s
  }

  s.social_media_url = 'https://twitter.com/Firebase'

  ios_deployment_target = '13.0'
  osx_deployment_target = '10.15'
  tvos_deployment_target = '13.0'
  watchos_deployment_target = '7.0'

  s.ios.deployment_target = ios_deployment_target
  s.osx.deployment_target = osx_deployment_target
  s.tvos.deployment_target = tvos_deployment_target
  s.watchos.deployment_target = watchos_deployment_target

  s.cocoapods_version = '>= 1.12.0'
  s.prefix_header_file = false

  s.swift_version = '5.9'

  base_dir = "FirebaseABTesting/Sources/"
  s.source_files = [
    base_dir + '**/*.[mh]',
   'Interop/Analytics/Public/*.h',
   'FirebaseCore/Extension/*.h',
  ]
  s.resource_bundles = {
    "#{s.module_name}_Privacy" => 'FirebaseABTesting/Sources/Resources/PrivacyInfo.xcprivacy'
  }
  s.requires_arc = base_dir + '*.m'
  s.public_header_files = base_dir + 'Public/FirebaseABTesting/*.h'
  s.pod_target_xcconfig = {
    'GCC_C_LANGUAGE_STANDARD' => 'c99',
    'HEADER_SEARCH_PATHS' => '"${PODS_TARGET_SRCROOT}"'
  }
  s.dependency 'FirebaseCore', '~> 11.7.0'

  s.test_spec 'unit' do |unit_tests|
    unit_tests.scheme = { :code_coverage => true }
    unit_tests.platforms = {
      :ios => ios_deployment_target,
      :osx => '10.15',
      :tvos => tvos_deployment_target
    }
    unit_tests.source_files = 'FirebaseABTesting/Tests/Unit/**/*.[mh]'
    unit_tests.resources = 'FirebaseABTesting/Tests/Unit/Resources/*.txt'
    unit_tests.requires_app_host = true
    unit_tests.dependency 'OCMock'
  end
end

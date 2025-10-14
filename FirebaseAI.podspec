Pod::Spec.new do |s|
  s.name             = 'FirebaseAI'
  s.version          = '12.5.0'
  s.summary          = 'Firebase AI SDK'

  s.description      = <<-DESC
Build AI-powered apps and features with the Gemini API using the Firebase AI SDK.
                       DESC

  s.homepage         = 'https://firebase.google.com'
  s.license          = { :type => 'Apache-2.0', :file => 'LICENSE' }
  s.authors          = 'Google, Inc.'

  s.source           = {
    :git => 'https://github.com/firebase/firebase-ios-sdk.git',
    :tag => 'CocoaPods-' + s.version.to_s
  }

  s.social_media_url = 'https://twitter.com/Firebase'

  ios_deployment_target = '15.0'
  osx_deployment_target = '12.0'
  tvos_deployment_target = '15.0'
  watchos_deployment_target = '8.0'

  s.ios.deployment_target = ios_deployment_target
  s.osx.deployment_target = osx_deployment_target
  s.tvos.deployment_target = tvos_deployment_target
  s.watchos.deployment_target = watchos_deployment_target

  s.cocoapods_version = '>= 1.12.0'
  s.prefix_header_file = false

  s.source_files = [
    'FirebaseAI/Wrapper/Sources/**/*.swift',
  ]

  s.swift_version = '5.9'

  s.framework = 'Foundation'
  s.ios.framework = 'UIKit'
  s.osx.framework = 'AppKit'
  s.tvos.framework = 'UIKit'
  s.watchos.framework = 'WatchKit'

  s.dependency 'FirebaseAILogic', '12.5.0'
  s.dependency 'FirebaseCore', '~> 12.5.0'

  s.test_spec 'unit' do |unit_tests|
    unit_tests_dir = 'FirebaseAI/Wrapper/Tests/'
    unit_tests.scheme = { :code_coverage => true }
    unit_tests.platforms = {
      :ios => ios_deployment_target,
      :osx => osx_deployment_target,
      :tvos => tvos_deployment_target
    }
    unit_tests.source_files = [
      unit_tests_dir + '**/*.swift',
    ]
  end
end

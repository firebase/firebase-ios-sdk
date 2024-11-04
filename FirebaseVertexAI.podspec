Pod::Spec.new do |s|
  s.name             = 'FirebaseVertexAI'
  s.version          = '11.5.0'
  s.summary          = 'Vertex AI in Firebase SDK'

  s.description      = <<-DESC
Build AI-powered apps and features with the Gemini API using the Vertex AI in
Firebase SDK.
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
    'FirebaseVertexAI/Sources/**/*.swift',
  ]

  s.swift_version = '5.9'

  s.framework = 'Foundation'
  s.ios.framework = 'UIKit'
  s.osx.framework = 'AppKit'
  s.tvos.framework = 'UIKit'
  s.watchos.framework = 'WatchKit'

  s.dependency 'FirebaseAppCheckInterop', '~> 11.4'
  s.dependency 'FirebaseAuthInterop', '~> 11.4'
  s.dependency 'FirebaseCore', '11.5'
  s.dependency 'FirebaseCoreExtension', '11.5'

  s.test_spec 'unit' do |unit_tests|
    unit_tests_dir = 'FirebaseVertexAI/Tests/Unit/'
    unit_tests.scheme = { :code_coverage => true }
    unit_tests.platforms = {
      :ios => ios_deployment_target,
      :osx => osx_deployment_target,
      :tvos => tvos_deployment_target
    }
    unit_tests.source_files = [
      unit_tests_dir + '**/*.swift',
    ]
    unit_tests.resources = [
      unit_tests_dir + 'vertexai-sdk-test-data/mock-responses/**/*.{txt,json}',
      unit_tests_dir + 'Resources/**/*',
    ]
  end
end

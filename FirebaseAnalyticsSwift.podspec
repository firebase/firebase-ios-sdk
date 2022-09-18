Pod::Spec.new do |s|
  s.name                    = 'FirebaseAnalyticsSwift'
  s.version                 = '9.6.0'
  s.summary                 = 'Swift Extensions for Firebase Analytics'

  s.description      = <<-DESC
Firebase Analytics is a free, out-of-the-box analytics solution that inspires actionable insights based on app usage and user engagement.
                       DESC

  s.homepage                = 'https://firebase.google.com/features/analytics/'
  s.license                 = { :type => 'Apache-2.0', :file => 'LICENSE' }
  s.authors                 = 'Google, Inc.'

  s.source                  = {
    :git => 'https://github.com/Firebase/firebase-ios-sdk.git',
    :tag => 'CocoaPods-' + s.version.to_s
  }

  s.static_framework        = true
  s.swift_version           = '5.3'

  ios_deployment_target = '13.0'
  osx_deployment_target = '10.15'
  tvos_deployment_target = '13.0'

  s.ios.deployment_target   = ios_deployment_target
  s.osx.deployment_target   = osx_deployment_target
  s.tvos.deployment_target  = tvos_deployment_target

  s.cocoapods_version       = '>= 1.10.0'
  s.prefix_header_file      = false

  s.source_files = [
    'FirebaseAnalyticsSwift/Sources/*.swift',
  ]

  s.dependency 'FirebaseAnalytics', '~> 9.0'

  s.test_spec 'swift-unit' do |swift_unit_tests|
    swift_unit_tests.platforms = {
      :ios => ios_deployment_target,
      :osx => osx_deployment_target,
      :tvos => tvos_deployment_target
    }
    swift_unit_tests.source_files = [
      'FirebaseAnalyticsSwift/Tests/SwiftUnit/**/*.swift',
    ]
  end
end

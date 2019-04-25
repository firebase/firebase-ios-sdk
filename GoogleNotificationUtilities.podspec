Pod::Spec.new do |s|
  s.name             = 'GoogleNotificationUtilities'
  s.version          = '7.0.0'
  s.summary          = 'Google Utilities for iOS Push Notifications'

  s.description      = <<-DESC
  Internal Google Utilities for iOS Remote Notifications. The part of code from GoogleUtilities
  requiring specific Push Notifications entitlements.
                       DESC

  s.homepage         = 'https://github.com/firebase/firebase-ios-sdk/tree/master/GoogleNotificationUtilities'
  s.license          = { :type => 'Apache', :file => 'LICENSE' }
  s.authors          = 'Google, Inc.'

  s.source           = {
    :git => 'https://github.com/firebase/firebase-ios-sdk.git',
    :tag => 'NotificationUtilities-' + s.version.to_s
  }

  s.ios.deployment_target = '8.0'
  s.osx.deployment_target = '10.11'
  s.tvos.deployment_target = '10.0'

  s.cocoapods_version = '>= 1.4.0'
  s.prefix_header_file = false

  s.source_files = 'GoogleNotificationUtilities/AppDelegateSwizzler_Notifications/**/*.[mh]'
  s.public_header_files = 'GoogleNotificationUtilities/AppDelegateSwizzler_Notifications/*.h'
  s.dependency 'GoogleUtilities/AppDelegateSwizzler', '~> 7.0'

end

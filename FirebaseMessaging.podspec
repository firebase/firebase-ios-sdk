Pod::Spec.new do |s|
  s.name             = 'FirebaseMessaging'
  s.version          = '3.0.0'
  s.summary          = 'Firebase Messaging for iOS'

  s.description      = <<-DESC
Firebase Messaging for iOS is a service that allows you to send data from your server to your users'
iOS device, and also to receive messages from devices on the same connection. The service handles
all aspects of queueing of messages and delivery to the target iOS application running on the target
device, and it is completely free.
                       DESC

  s.homepage         = 'https://firebase.google.com'
  s.license          = { :type => 'Apache', :file => 'LICENSE' }
  s.authors          = 'Google, Inc.'

  s.source           = {
    :git => 'https://github.com/firebase/firebase-ios-sdk.git',
    :tag => 'Messaging-' + s.version.to_s
  }
  s.social_media_url = 'https://twitter.com/Firebase'
  s.ios.deployment_target = '8.0'

  s.cocoapods_version = '>= 1.4.0'
  s.static_framework = true
  s.prefix_header_file = false

  base_dir = "Firebase/Messaging/"
  s.source_files = base_dir + '**/*.[mh]'
  s.requires_arc = base_dir + '*.m'
  s.public_header_files = base_dir + 'Public/*.h'
  s.library = 'sqlite3'
  s.pod_target_xcconfig = {
    'GCC_PREPROCESSOR_DEFINITIONS' =>
      'GPB_USE_PROTOBUF_FRAMEWORK_IMPORTS=1 ' +
      'FIRMessaging_LIB_VERSION=' + String(s.version)
  }
  s.framework = 'AddressBook'
  s.framework = 'SystemConfiguration'
  s.dependency 'FirebaseCore', '~> 5.0'
  s.ios.dependency 'FirebaseAnalytics', '~> 5.0'
  s.dependency 'FirebaseInstanceID', '~> 3.0'
  s.dependency 'GoogleToolboxForMac/Logger', '~> 2.1'
  s.dependency 'Protobuf', '~> 3.1'
end

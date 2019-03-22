Pod::Spec.new do |s|
  s.name             = 'GoogleUtilities'
  s.version          = '5.5.0'
  s.summary          = 'Google Utilities for iOS (plus community support for macOS and tvOS)'

  s.description      = <<-DESC
Internal Google Utilities including Network, Reachability Environment, Logger, and Swizzling for
other Google CocoaPods. They're not intended for direct public usage.
                       DESC

  s.homepage         = 'https://github.com/firebase/firebase-ios-sdk/tree/master/GoogleUtilities'
  s.license          = { :type => 'Apache', :file => 'LICENSE' }
  s.authors          = 'Google, Inc.'

  s.source           = {
    :git => 'https://github.com/firebase/firebase-ios-sdk.git',
    :tag => 'Utilities-' + s.version.to_s
  }
  # Technically GoogleUtilites requires iOS 7, but it supports a dependency pod with a minimum
  # iOS 6, that will do runtime checking to avoid calling into GoogleUtilities.
  s.ios.deployment_target = '6.0'
  s.osx.deployment_target = '10.10'
  s.tvos.deployment_target = '10.0'

  s.cocoapods_version = '>= 1.4.0'
  s.prefix_header_file = false

  s.subspec 'Environment' do |es|
    es.source_files = 'GoogleUtilities/Environment/third_party/*.[mh]'
    es.public_header_files = 'GoogleUtilities/Environment/third_party/*.h'
    es.private_header_files = 'GoogleUtilities/Environment/third_party/*.h'
  end

  s.subspec 'Logger' do |ls|
    ls.source_files = 'GoogleUtilities/Logger/**/*.[mh]'
    ls.public_header_files = 'GoogleUtilities/Logger/Private/*.h', 'GoogleUtilities/Logger/Public/*.h'
    ls.private_header_files = 'GoogleUtilities/Logger/Private/*.h'
    ls.dependency 'GoogleUtilities/Environment'
  end

  s.subspec 'Network' do |ns|
    ns.source_files = 'GoogleUtilities/Network/**/*.[mh]'
    ns.public_header_files = 'GoogleUtilities/Network/Private/*.h'
    ns.private_header_files = 'GoogleUtilities/Network/Private/*.h'
    ns.dependency 'GoogleUtilities/NSData+zlib'
    ns.dependency 'GoogleUtilities/Logger'
    ns.dependency 'GoogleUtilities/Reachability'
    ns.frameworks = [
      'Security'
    ]
  end

  s.subspec 'NSData+zlib' do |ns|
    ns.source_files = 'GoogleUtilities/NSData+zlib/*.[mh]'
    ns.public_header_files = 'GoogleUtilities/NSData+zlib/GULNSData+zlib.h'
    ns.libraries = [
      'z'
    ]
  end

  s.subspec 'Reachability' do |rs|
    rs.source_files = 'GoogleUtilities/Reachability/**/*.[mh]'
    rs.public_header_files = 'GoogleUtilities/Reachability/Private/*.h'
    rs.private_header_files = 'GoogleUtilities/Reachability/Private/*.h'
    rs.frameworks = [
      'SystemConfiguration'
    ]
    rs.dependency 'GoogleUtilities/Logger'
  end

  s.subspec 'AppDelegateSwizzler' do |adss|
    adss.source_files = 'GoogleUtilities/AppDelegateSwizzler/**/*.[mh]', 'GoogleUtilities/Common/*.h'
    adss.public_header_files = 'GoogleUtilities/AppDelegateSwizzler/Private/*.h'
    adss.private_header_files = 'GoogleUtilities/AppDelegateSwizzler/Private/*.h'
    adss.dependency 'GoogleUtilities/Logger'
    adss.dependency 'GoogleUtilities/Network'
    adss.dependency 'GoogleUtilities/Environment'
  end

  s.subspec 'ISASwizzler' do |iss|
    iss.source_files = 'GoogleUtilities/ISASwizzler/**/*.[mh]', 'GoogleUtilities/Common/*.h'
    iss.private_header_files = 'GoogleUtilities/ISASwizzler/Private/*.h'
  end

  s.subspec 'MethodSwizzler' do |mss|
    mss.source_files = 'GoogleUtilities/MethodSwizzler/**/*.[mh]', 'GoogleUtilities/Common/*.h'
    mss.private_header_files = 'GoogleUtilities/MethodSwizzler/Private/*.h'
    mss.dependency 'GoogleUtilities/Logger'
  end

  s.subspec 'SwizzlerTestHelpers' do |sths|
    sths.source_files = 'GoogleUtilities/SwizzlerTestHelpers/*.[hm]'
    sths.private_header_files = 'GoogleUtilities/SwizzlerTestHelpers/*.h'
  end

  s.subspec 'UserDefaults' do |ud|
    ud.source_files = 'GoogleUtilities/UserDefaults/**/*.[hm]'
    ud.public_header_files = 'GoogleUtilities/UserDefaults/Private/*.h'
    ud.private_header_files = 'GoogleUtilities/UserDefaults/Private/*.h'
    ud.dependency 'GoogleUtilities/Logger'
  end
end

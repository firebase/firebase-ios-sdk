Pod::Spec.new do |s|
  s.name             = 'GoogleUtilities'
  s.version          = '6.6.0-paul-test'
  s.summary          = 'Google Utilities for iOS (plus community support for macOS and tvOS)'

  s.description      = <<-DESC
Internal Google Utilities including Network, Reachability Environment, Logger and Swizzling for
other Google CocoaPods. They're not intended for direct public usage.
                       DESC

  s.homepage         = 'https://github.com/firebase/firebase-ios-sdk/tree/master/GoogleUtilities'
  s.license          = { :type => 'Apache', :file => 'GoogleUtilities/LICENSE' }
  s.authors          = 'Google, Inc.'

  s.source           = {
    :git => 'https://github.com/firebase/firebase-ios-sdk.git',
    :tag => 'Utilities-' + s.version.to_s
  }

  s.ios.deployment_target = '8.0'
  s.osx.deployment_target = '10.11'
  s.tvos.deployment_target = '10.0'
  s.watchos.deployment_target = '6.0'

  s.cocoapods_version = '>= 1.4.0'
  s.prefix_header_file = false

  s.pod_target_xcconfig = {
    'GCC_C_LANGUAGE_STANDARD' => 'c99',
    'HEADER_SEARCH_PATHS' => '"${PODS_TARGET_SRCROOT}"',
  }

  s.subspec 'Environment' do |es|
    es.source_files = 'GoogleUtilities/Environment/**/*.[mh]'
    es.public_header_files = 'GoogleUtilities/Environment/Private/*.h'
    es.private_header_files = 'GoogleUtilities/Environment/Private/*.h'

    es.dependency 'PromisesObjC', '~> 1.2'
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
    ns.source_files = 'GoogleUtilities/NSData+zlib/**/*.[mh]'
    ns.public_header_files = 'GoogleUtilities/NSData+zlib/Public/*.h', 'GoogleUtilities/NSData+zlib/Private/*.h'
    ns.private_header_files = 'GoogleUtilities/NSData+zlib/Private/*.h'
    ns.libraries = [
      'z'
    ]
  end

  s.subspec 'Reachability' do |rs|
    rs.source_files = 'GoogleUtilities/Reachability/**/*.[mh]'
    rs.public_header_files = 'GoogleUtilities/Reachability/Private/*.h'
    rs.private_header_files = 'GoogleUtilities/Reachability/Private/*.h'
    rs.ios.frameworks = [
      'SystemConfiguration'
    ]
    rs.osx.frameworks = [
      'SystemConfiguration'
    ]
    rs.tvos.frameworks = [
      'SystemConfiguration'
    ]
    rs.dependency 'GoogleUtilities/Logger'
  end

  s.subspec 'AppDelegateSwizzler' do |adss|
    adss.source_files = 'GoogleUtilities/AppDelegateSwizzler/**/*.[mh]', 'GoogleUtilities/SceneDelegateSwizzler/**/*.[mh]', 'GoogleUtilities/Common/*.h'
    adss.public_header_files = 'GoogleUtilities/AppDelegateSwizzler/Private/*.h', 'GoogleUtilities/SceneDelegateSwizzler/Private/*.h'
    adss.private_header_files = 'GoogleUtilities/AppDelegateSwizzler/Private/*.h', 'GoogleUtilities/SceneDelegateSwizzler/Private/*.h'
    adss.dependency 'GoogleUtilities/Logger'
    adss.dependency 'GoogleUtilities/Network'
    adss.dependency 'GoogleUtilities/Environment'
  end

  s.subspec 'ISASwizzler' do |iss|
    iss.source_files = 'GoogleUtilities/ISASwizzler/**/*.[mh]', 'GoogleUtilities/Common/*.h'
    iss.public_header_files = 'GoogleUtilities/ISASwizzler/Private/*.h'
    iss.private_header_files = 'GoogleUtilities/ISASwizzler/Private/*.h'

    # Disable ARC for GULSwizzledObject.
    iss.requires_arc = ['GoogleUtilities/Common/*.h', 'GoogleUtilities/ISASwizzler/GULObjectSwizzler*.[mh]']
  end

  s.subspec 'MethodSwizzler' do |mss|
    mss.source_files = 'GoogleUtilities/MethodSwizzler/**/*.[mh]', 'GoogleUtilities/Common/*.h'
    mss.private_header_files = 'GoogleUtilities/MethodSwizzler/Private/*.h'
    mss.dependency 'GoogleUtilities/Logger'
  end

  s.subspec 'SwizzlerTestHelpers' do |sths|
    sths.source_files = 'GoogleUtilities/SwizzlerTestHelpers/*.[hm]'
    sths.private_header_files = 'GoogleUtilities/SwizzlerTestHelpers/*.h'
    sths.dependency 'GoogleUtilities/MethodSwizzler'
  end

  s.subspec 'UserDefaults' do |ud|
    ud.source_files = 'GoogleUtilities/UserDefaults/**/*.[hm]'
    ud.public_header_files = 'GoogleUtilities/UserDefaults/Private/*.h'
    ud.private_header_files = 'GoogleUtilities/UserDefaults/Private/*.h'
    ud.dependency 'GoogleUtilities/Logger'
  end

  s.test_spec 'unit' do |unit_tests|
    # All tests require arc except Tests/Network/third_party/GTMHTTPServer.m
    unit_tests.platforms = {:ios => '8.0', :osx => '10.11', :tvos => '10.0'}
    unit_tests.source_files = 'GoogleUtilities/Example/Tests/**/*.[mh]'
    unit_tests.requires_arc = 'GoogleUtilities/Example/Tests/*/*.[mh]'
    unit_tests.requires_app_host = true
    unit_tests.dependency 'OCMock'
  end
end

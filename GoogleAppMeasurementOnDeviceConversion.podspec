Pod::Spec.new do |s|
    s.name             = 'GoogleAppMeasurementOnDeviceConversion'
    s.version          = '10.21.0'
    s.summary          = <<-SUMMARY
    On device conversion measurement plugin for Google App Measurement. Not
    intended for direct use.
    SUMMARY

    s.description      = <<-DESC
    On device conversion measurement plugin for Google App Measurement. This
    pod does not expose any headers and isn't intended for direct use, but
    rather as a plugin of Google App Measurement.
    DESC

    s.homepage         = 'https://developers.google.com/ios'
    s.license          = { :type => 'Copyright', :text => 'Copyright 2022 Google' }
    s.authors          = 'Google, Inc.'

    s.source           = {
        :http => 'https://dl.google.com/firebase/ios/analytics/4ab453c686c6aac4/GoogleAppMeasurementOnDeviceConversion-10.20.0.tar.gz'
    }

    s.cocoapods_version = '>= 1.12.0'

    s.ios.deployment_target  = '10.0'

    s.libraries  = 'c++'

    s.vendored_frameworks = 'Frameworks/GoogleAppMeasurementOnDeviceConversion.xcframework'
end


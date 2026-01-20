platform :ios, '15.0'
source 'https://cdn.cocoapods.org/'
project 'chery_ios.xcodeproj'
target 'chery_ios' do
  use_frameworks!
  pod 'SnapKit'
  pod 'SDWebImage'
  pod 'MJExtension'
  # 离线包方案
  pod 'TheRouter', '1.1.8'
  
  pod 'QXWebView', :path=>'./QXWebView'
  #  pod 'QXWebView', '~> 0.1.1'
end

post_install do
  |installer| installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
      config.build_settings['EXPANDED_CODE_SIGN_IDENTITY'] = ""
      config.build_settings['CODE_SIGNING_REQUIRED'] = "NO"
      config.build_settings['CODE_SIGNING_ALLOWED'] = "NO"
    end
  end
end

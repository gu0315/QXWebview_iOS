#
# Be sure to run `pod lib lint QXWebView.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'QXWebView'
  s.version          = '0.1.0'
  s.summary          = 'A short description of QXWebView.'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      =  'Add long description of the pod here'

  s.homepage         = 'https://github.com/gu0315/QXWebview'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license      = { :type => 'Apache License, Version 2.0', :text => <<-LICENSE
    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.
    LICENSE
  }
  s.author             = { "顾钱想" => "228383741@qq.com" }
  s.source           = { :git => 'https://github.com/gu0315/QXWebview.git', :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.ios.deployment_target = '10.0'

  s.source_files = 'QXWebView/Classes/**/*.{h,m,mm,swift,js}'
  
  # 可选：如果需要排除某些文件/文件夹，可补充
  # s.exclude_files = 'QXWebView/Classes/JDBridge/UnusedFile.swift'
  
   s.resource_bundles = {
     'QXWebView' => ['QXWebView/Resources/*']
   }

  s.public_header_files = 'QXWebView/Classes/QXWebView.h', 'QXWebView/Classes/JDBridge/*.h', 'QXWebView/Classes/JDWebView/*.h'
  s.frameworks = 'UIKit', 'CoreLocation', 'Foundation'
  s.libraries = 'z', 'c++'
  
  s.static_framework = true
  # 添加高德定位 SDK 依赖（复用主工程的 AMapLocation-NO-IDFA）
  #s.dependency 'AMapLocation-NO-IDFA'

  s.xcconfig = {
      'OTHER_LDFLAGS' => '-ObjC -all_load',
      'CLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES' => 'YES',
      'ENABLE_BITCODE' => 'NO',
    }
end

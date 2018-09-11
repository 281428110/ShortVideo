
Pod::Spec.new do |s|

s.name         = "DQTes"
s.version      = "0.0.1"
s.summary      = "A short description of DQTools."
s.homepage     = "https://github.com/281428110/ShortVideo"
s.license      = "MIT"
s.author             = { "周明亮" => "281428110@qq.com" }
s.platform     = :ios
s.source       = { :git => "https://github.com/281428110/ShortVideo.git" }
s.source_files  = "DQTes/**/*.{h,m}"
s.public_header_files = "DQTes/**/*.h"
s.resources = "DQTes/**/*.{png,xib,storyboard}"
end

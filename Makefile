.PHONY: help web-dev web-build web-test macos-build macos-test ios-build android-build android-test

help:
	@echo "web-dev        启动 Web 开发服务"
	@echo "web-build      构建 Web"
	@echo "web-test       运行 Web 测试"
	@echo "macos-build    构建 macOS 开发版本"
	@echo "macos-test     运行 macOS 测试"
	@echo "ios-build      构建 iOS 模拟器版本"
	@echo "android-build  构建 Android Debug 安装包"
	@echo "android-test   运行 Android 单元测试"

web-dev:
	pnpm --dir apps/web dev

web-build:
	pnpm --dir apps/web build

web-test:
	pnpm --dir apps/web test:run

macos-build:
	cd apps/macos && xcodebuild -project CreditCardMac.xcodeproj -scheme CreditCardMac -configuration Debug -destination 'platform=macOS' -derivedDataPath build/DerivedData build CODE_SIGNING_ALLOWED=NO

macos-test:
	cd apps/macos && xcodebuild -project CreditCardMac.xcodeproj -scheme CreditCardMac -configuration Release ENABLE_TESTABILITY=YES -destination 'platform=macOS' -derivedDataPath build/DerivedData -parallel-testing-enabled NO test CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_ENTITLEMENTS=''

ios-build:
	cd apps/ios && xcodebuild -project CreditCardIOS.xcodeproj -scheme CreditCardIOS -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath build/DerivedData build CODE_SIGNING_ALLOWED=NO

android-build:
	cd apps/android && ./gradlew assembleDebug

android-test:
	cd apps/android && ./gradlew testDebugUnitTest

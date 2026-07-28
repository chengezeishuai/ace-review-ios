# ACE Review iOS

原生 SwiftUI 测试客户端，面向 iPhone 相册中的大体积训练录像。

核心链路：

1. 通过 PhotoKit 读取视频当前原始表示，尽量避免转码。
2. 每读取 8 MB 就落为独立临时分片。
3. 分片立即交给后台 `URLSession` 上传，读取和上传并行。
4. App 切入后台或锁屏后，已经生成的分片继续由 iOS 传输。
5. 所有分片完成后自动通知 ACE 后端合并并进入分析队列。

工程最低支持 iOS 17，使用 Xcode 16 或更新版本打开
`ACEReview.xcodeproj`。

测试阶段默认服务器为 `http://36.140.125.194:19999/`，并仅为测试加入
ATS 明文网络例外。提交 App Store 前应切换为 HTTPS 域名并删除该例外。


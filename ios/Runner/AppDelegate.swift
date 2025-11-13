import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  // 保存 APNs device token
  private var apnsToken: String?
  
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    
    // 使用 FlutterPluginRegistry 设置 MethodChannel
    if let registrar = self.registrar(forPlugin: "ApnsPlugin") {
      let apnsChannel = FlutterMethodChannel(
        name: "com.sureup.app/apns",
        binaryMessenger: registrar.messenger()
      )
      
      apnsChannel.setMethodCallHandler { [weak self] (call, result) in
        if call.method == "getApnsToken" {
          result(self?.apnsToken)
        } else {
          result(FlutterMethodNotImplemented)
        }
      }
    }
    
    // 注册远程通知
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
        if granted {
          DispatchQueue.main.async {
            UIApplication.shared.registerForRemoteNotifications()
          }
        }
      }
    } else {
      let settings = UIUserNotificationSettings(types: [.alert, .badge, .sound], categories: nil)
      application.registerUserNotificationSettings(settings)
      application.registerForRemoteNotifications()
    }
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  // APNs 注册成功回调
  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    // 将 device token 转换为字符串（十六进制格式）
    let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
    self.apnsToken = tokenString
    print("✅ APNs device token: \(tokenString)")
  }
  
  // APNs 注册失败回调
  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    print("❌ APNs 注册失败: \(error.localizedDescription)")
  }
}

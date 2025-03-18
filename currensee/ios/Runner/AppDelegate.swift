import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    
    // Setup method channel for keyboard control
    let controller = window?.rootViewController as! FlutterViewController
    let keyboardChannel = FlutterMethodChannel(
        name: "com.currensee.app/keyboard", 
        binaryMessenger: controller.binaryMessenger)
    
    keyboardChannel.setMethodCallHandler { [weak self] (call, result) in
        switch call.method {
        case "forceKeyboardVisible":
            self?.forceKeyboardVisible()
            result(true)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  // Method to force keyboard visibility on iOS
  private func forceKeyboardVisible() {
    // Ensure we're on the main thread
    DispatchQueue.main.async {
        // This forces the keyboard to remain visible
        if let keyWindow = UIApplication.shared.windows.first(where: { $0.isKeyWindow }),
           let rootViewController = keyWindow.rootViewController {
            // Find the active text field
            let textFields = self.findTextFields(in: rootViewController.view)
            if let textField = textFields.first {
                // Force become first responder
                textField.becomeFirstResponder()
                
                // Hack to force keyboard visibility in simulator
                let originalText = textField.text ?? ""
                textField.text = originalText + " "
                textField.text = originalText
                
                // Move cursor to end
                if let position = textField.position(from: textField.beginningOfDocument, offset: originalText.count) {
                    textField.selectedTextRange = textField.textRange(from: position, to: position)
                }
            }
        }
    }
  }
  
  // Helper to find all text fields recursively
  private func findTextFields(in view: UIView) -> [UITextField] {
    var textFields = [UITextField]()
    
    if let textField = view as? UITextField {
        textFields.append(textField)
    }
    
    for subview in view.subviews {
        textFields.append(contentsOf: findTextFields(in: subview))
    }
    
    return textFields
  }
}

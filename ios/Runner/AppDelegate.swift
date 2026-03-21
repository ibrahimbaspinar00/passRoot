import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var privacyOverlayView: UIView?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleWillResignActive),
      name: UIApplication.willResignActiveNotification,
      object: nil
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleDidBecomeActive),
      name: UIApplication.didBecomeActiveNotification,
      object: nil
    )
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
  }

  @objc private func handleWillResignActive() {
    showPrivacyOverlay()
  }

  @objc private func handleDidBecomeActive() {
    hidePrivacyOverlay()
  }

  private func showPrivacyOverlay() {
    guard privacyOverlayView == nil, let hostView = currentHostView() else {
      return
    }

    let blurEffect = UIBlurEffect(style: .systemUltraThinMaterialDark)
    let blurView = UIVisualEffectView(effect: blurEffect)
    blurView.frame = hostView.bounds
    blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

    let shield = UIImageView(image: UIImage(systemName: "lock.shield.fill"))
    shield.tintColor = .white
    shield.contentMode = .scaleAspectFit
    shield.translatesAutoresizingMaskIntoConstraints = false
    blurView.contentView.addSubview(shield)

    let titleLabel = UILabel()
    titleLabel.text = "PassRoot Vault"
    titleLabel.textColor = .white
    titleLabel.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
    titleLabel.translatesAutoresizingMaskIntoConstraints = false
    blurView.contentView.addSubview(titleLabel)

    NSLayoutConstraint.activate([
      shield.centerXAnchor.constraint(equalTo: blurView.contentView.centerXAnchor),
      shield.centerYAnchor.constraint(equalTo: blurView.contentView.centerYAnchor, constant: -14),
      shield.widthAnchor.constraint(equalToConstant: 44),
      shield.heightAnchor.constraint(equalToConstant: 44),
      titleLabel.topAnchor.constraint(equalTo: shield.bottomAnchor, constant: 10),
      titleLabel.centerXAnchor.constraint(equalTo: blurView.contentView.centerXAnchor)
    ])

    hostView.addSubview(blurView)
    privacyOverlayView = blurView
  }

  private func hidePrivacyOverlay() {
    privacyOverlayView?.removeFromSuperview()
    privacyOverlayView = nil
  }

  private func currentHostView() -> UIView? {
    if let window = window {
      return window
    }

    let activeScene = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .first { $0.activationState == .foregroundActive || $0.activationState == .foregroundInactive }

    return activeScene?.windows.first(where: { $0.isKeyWindow })
  }
}

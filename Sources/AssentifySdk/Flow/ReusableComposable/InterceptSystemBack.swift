import SwiftUI
import UIKit

public struct InterceptSystemBack: ViewModifier {
    let action: () -> Void

    public func body(content: Content) -> some View {
        content
            .background {
                BackInterceptController(action: action)
                    .frame(width: 0, height: 0)
            }
    }
}

private struct BackInterceptController: UIViewControllerRepresentable {
    let action: () -> Void

    func makeUIViewController(context: Context) -> UIViewController {
        let vc = UIViewController()
        vc.view.backgroundColor = .clear
        context.coordinator.attach(to: vc)
        return vc
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        context.coordinator.attach(to: uiViewController)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(action: action)
    }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIGestureRecognizerDelegate {
        let action: () -> Void
        weak var nav: UINavigationController?
        weak var vc: UIViewController?

        init(action: @escaping () -> Void) {
            self.action = action
        }

        func attach(to vc: UIViewController) {
            guard self.vc !== vc else { return }
            self.vc = vc

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                guard let nav = vc.navigationController else { return }

                // 1) Disable swipe-back
                nav.interactivePopGestureRecognizer?.isEnabled = true
                nav.interactivePopGestureRecognizer?.delegate = self

                // 2) Replace system back button with identical-looking custom one
                //    (Same chevron style; action calls only `action()`)
                vc.navigationItem.hidesBackButton = true
                vc.navigationItem.leftBarButtonItem = UIBarButtonItem(
                    image: UIImage(systemName: "chevron.backward"),
                    style: .plain,
                    target: self,
                    action: #selector(didTapBack)
                )

                self.nav = nav
            }
        }

        @objc private func didTapBack() {
            action() // ✅ call your custom back only
        }

        // Block swipe-back gesture
        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            action() // ✅ call your custom back
            return false // ✅ prevent navigation pop
        }
    }
}

import UIKit

func forceSyncMainViewControllerPreset(volumes: [Float], versions: [Int], name: String) {
    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
       let window = windowScene.windows.first,
       let rootVC = window.rootViewController {
        var mainVC: MainViewController?
        if let tabBar = rootVC as? UITabBarController {
            for vc in tabBar.viewControllers ?? [] {
                if let nav = vc as? UINavigationController,
                   let vc = nav.viewControllers.first as? MainViewController {
                    mainVC = vc
                    break
                } else if let vc = vc as? MainViewController {
                    mainVC = vc
                    break
                }
            }
        } else if let nav = rootVC as? UINavigationController,
                  let vc = nav.viewControllers.first as? MainViewController {
            mainVC = vc
        } else if let vc = rootVC as? MainViewController {
            mainVC = vc
        }
        if let mainVC = mainVC {
            print("✅ [forceSyncMainViewControllerPreset] 메인VC 직접 동기화")
            mainVC.applyPreset(
                volumes: volumes,
                versions: versions,
                name: name,
                presetId: nil,
                saveAsNew: true
            )
            mainVC.updatePresetBlocks()
        } else {
            print("❌ [forceSyncMainViewControllerPreset] 메인VC를 찾을 수 없음")
        }
    }
} 
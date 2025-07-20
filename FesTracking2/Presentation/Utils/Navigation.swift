//
//  Navigation.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/07/19.
//
//import SwiftUI
//import UIKit
//
//extension ViewController {
//    func isSwipeBackEnabled() -> Bool {
//        return false
//    }
//}
//
//class SwipeableViewController: UIViewController {
//    override func isSwipeBackEnabled() -> Bool {
//        return true
//    }
//}
//
//struct SwipeableBackView: UIViewControllerRepresentable{
//    typealias UIViewControllerType = SwipeableViewController
//    func makeUIViewController(context: Context) -> UIViewControllerType {
//        UIViewControllerType()
//    }
//    func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) {}
//}
//
//extension UINavigationController: UIGestureRecognizerDelegate {
//    override open func viewDidLoad() {
//        super.viewDidLoad()
//        interactivePopGestureRecognizer?.delegate = self
//    }
//
//    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
//        guard viewControllers.count > 1 else { return false }
//        return topViewController?.isSwipeBackEnabled() ?? false
//    }
//}
//
//
//
//extension View {
//    @ViewBuilder
//    public func regainSwipeBack(_ enabled: Bool) -> some View {
//        self.background(
//            enabled ? RegainSwipeBackView() : EmptyView()
//        )
//    }
//}
//
//struct RegainSwipeBackView: UIViewControllerRepresentable {
//    
//    typealias UIViewControllerType = RegainSwipeBackViewController
//    
//    
//    func makeUIViewController(context: Context) -> UIViewControllerType {
//        UIViewControllerType()
//    }
//    
//    func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) {
//        
//    }
//}
//
//class RegainSwipeBackViewController: UIViewController {
//    
//    override func didMove(toParent parent: UIViewController?) {
//        super.didMove(toParent: parent)
//        print("Regain1 \(parent)")
//        print("Regain2 \(parent?.navigationController)")
//        print("Regain2 \(parent?.navigationController?.interactivePopGestureRecognizer?.isEnabled)")
//        if let navigationController = parent?.navigationController {
//            navigationController.interactivePopGestureRecognizer?.isEnabled = true
//        }
//    }
//}
//extension View {
//    @ViewBuilder
//    func dismissable(swipeEnabled: Bool = true, backButtonShown: Bool = true) -> some View {
//        self
//            .navigationBarBackButtonHidden(backButtonShown)
//            .regainSwipeBack(swipeEnabled)
//    }
//}
//

//
//  MediaPlugin.swift
//  chery_ios
//
//  Created by AI Assistant on 2025/01/27.
//

import Foundation
import UIKit
import Photos
import AVFoundation

/// 媒体插件 - 处理图片、视频等媒体功能
@objc class MediaPlugin: JDBridgeBasePlugin {
    
    override func excute(_ action: String, params: [AnyHashable : Any], callback: JDBridgeCallBack) -> Bool {
        switch action {
        case "chooseImage":
            handleChooseImage(params: params, callback: callback)
            return true
        case "chooseVideo":
            handleChooseVideo(params: params, callback: callback)
            return true
        case "takePhoto":
            handleTakePhoto(params: params, callback: callback)
            return true
        case "recordVideo":
            handleRecordVideo(params: params, callback: callback)
            return true
        case "saveImageToAlbum":
            handleSaveImageToAlbum(params: params, callback: callback)
            return true
        case "saveVideoToAlbum":
            handleSaveVideoToAlbum(params: params, callback: callback)
            return true
        default:
            callback.onFail(NSError(domain: "MediaPlugin", code: 1001, userInfo: [NSLocalizedDescriptionKey: "未知操作"]))
            return false
        }
    }
    
    // MARK: - 私有方法
    
    /// 选择图片
    private func handleChooseImage(params: [AnyHashable : Any], callback: JDBridgeCallBack) {
        let maxCount = params["maxCount"] as? Int ?? 1
        let allowCamera = params["allowCamera"] as? Bool ?? true
        
        DispatchQueue.main.async {
            let imagePicker = UIImagePickerController()
            imagePicker.delegate = MediaPickerDelegate(callback: callback)
            imagePicker.sourceType = allowCamera ? .photoLibrary : .savedPhotosAlbum
            imagePicker.allowsEditing = true
            
            if let topVC = UIApplication.shared.keyWindow?.rootViewController {
                topVC.present(imagePicker, animated: true)
            }
        }
    }
    
    /// 选择视频
    private func handleChooseVideo(params: [AnyHashable : Any], callback: JDBridgeCallBack) {
        let maxDuration = params["maxDuration"] as? Double ?? 60.0
        
        DispatchQueue.main.async {
            let imagePicker = UIImagePickerController()
            imagePicker.delegate = MediaPickerDelegate(callback: callback)
            imagePicker.sourceType = .photoLibrary
            imagePicker.mediaTypes = ["public.movie"]
            imagePicker.videoMaximumDuration = maxDuration
            
            if let topVC = UIApplication.shared.keyWindow?.rootViewController {
                topVC.present(imagePicker, animated: true)
            }
        }
    }
    
    /// 拍照
    private func handleTakePhoto(params: [AnyHashable : Any], callback: JDBridgeCallBack) {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            callback.onFail(NSError(domain: "MediaPlugin", code: 1002, userInfo: [NSLocalizedDescriptionKey: "设备不支持拍照"]))
            return
        }
        
        DispatchQueue.main.async {
            let imagePicker = UIImagePickerController()
            imagePicker.delegate = MediaPickerDelegate(callback: callback)
            imagePicker.sourceType = .camera
            imagePicker.allowsEditing = true
            
            if let topVC = UIApplication.shared.keyWindow?.rootViewController {
                topVC.present(imagePicker, animated: true)
            }
        }
    }
    
    /// 录制视频
    private func handleRecordVideo(params: [AnyHashable : Any], callback: JDBridgeCallBack) {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            callback.onFail(NSError(domain: "MediaPlugin", code: 1003, userInfo: [NSLocalizedDescriptionKey: "设备不支持录制视频"]))
            return
        }
        
        let maxDuration = params["maxDuration"] as? Double ?? 60.0
        
        DispatchQueue.main.async {
            let imagePicker = UIImagePickerController()
            imagePicker.delegate = MediaPickerDelegate(callback: callback)
            imagePicker.sourceType = .camera
            imagePicker.mediaTypes = ["public.movie"]
            imagePicker.videoMaximumDuration = maxDuration
            
            if let topVC = UIApplication.shared.keyWindow?.rootViewController {
                topVC.present(imagePicker, animated: true)
            }
        }
    }
    
    /// 保存图片到相册
    private func handleSaveImageToAlbum(params: [AnyHashable : Any], callback: JDBridgeCallBack) {
        guard let imageData = params["imageData"] as? String,
              let data = Data(base64Encoded: imageData),
              let image = UIImage(data: data) else {
            callback.onFail(NSError(domain: "MediaPlugin", code: 1004, userInfo: [NSLocalizedDescriptionKey: "无效的图片数据"]))
            return
        }
        
        PHPhotoLibrary.requestAuthorization { status in
            if status == .authorized {
                PHPhotoLibrary.shared().performChanges({
                    PHAssetChangeRequest.creationRequestForAsset(from: image)
                }) { success, error in
                    DispatchQueue.main.async {
                        if success {
                            callback.onSuccess(["success": true])
                        } else {
                            callback.onFail(error ?? NSError(domain: "MediaPlugin", code: 1005, userInfo: [NSLocalizedDescriptionKey: "保存失败"]))
                        }
                    }
                }
            } else {
                callback.onFail(NSError(domain: "MediaPlugin", code: 1006, userInfo: [NSLocalizedDescriptionKey: "没有相册权限"]))
            }
        }
    }
    
    /// 保存视频到相册
    private func handleSaveVideoToAlbum(params: [AnyHashable : Any], callback: JDBridgeCallBack) {
        guard let videoPath = params["videoPath"] as? String,
              let videoURL = URL(string: videoPath) else {
            callback.onFail(NSError(domain: "MediaPlugin", code: 1007, userInfo: [NSLocalizedDescriptionKey: "无效的视频路径"]))
            return
        }
        
        PHPhotoLibrary.requestAuthorization { status in
            if status == .authorized {
                PHPhotoLibrary.shared().performChanges({
                    PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: videoURL)
                }) { success, error in
                    DispatchQueue.main.async {
                        if success {
                            callback.onSuccess(["success": true])
                        } else {
                            callback.onFail(error ?? NSError(domain: "MediaPlugin", code: 1008, userInfo: [NSLocalizedDescriptionKey: "保存失败"]))
                        }
                    }
                }
            } else {
                callback.onFail(NSError(domain: "MediaPlugin", code: 1009, userInfo: [NSLocalizedDescriptionKey: "没有相册权限"]))
            }
        }
    }
}

/// 媒体选择器代理
class MediaPickerDelegate: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    private let callback: JDBridgeCallBack
    
    init(callback: JDBridgeCallBack) {
        self.callback = callback
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true)
        
        if let image = info[.editedImage] as? UIImage ?? info[.originalImage] as? UIImage {
            // 处理图片
            if let imageData = image.jpegData(compressionQuality: 0.8) {
                let base64String = imageData.base64EncodedString()
                callback.onSuccess([
                    "type": "image",
                    "data": base64String,
                    "width": image.size.width,
                    "height": image.size.height
                ])
            }
        } else if let videoURL = info[.mediaURL] as? URL {
            // 处理视频
            callback.onSuccess([
                "type": "video",
                "path": videoURL.absoluteString
            ])
        }
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
        callback.onFail(NSError(domain: "MediaPlugin", code: 1010, userInfo: [NSLocalizedDescriptionKey: "用户取消选择"]))
    }
}

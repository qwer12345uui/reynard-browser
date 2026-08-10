//
//  FilePickerDelegateCallbacks.swift
//  Reynard
//
//  Created by Minh Ton on 17/6/26.
//

@preconcurrency import PhotosUI
import UIKit

// Fork fix: the photo and document pickers have already dismissed themselves
// (or are mid-dismissal) when these delegate callbacks fire, so staging the
// selection inside a dismiss(animated:completion:) completion never runs and
// the picked file is never added. Stage immediately and dismiss the picker
// fire-and-forget, matching the behavior of the released 0.9.0 build.

extension FilePicker: UIDocumentPickerDelegate {
    nonisolated func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            presentedController = nil
            isCompletingPicker = true
            controller.dismiss(animated: true)
            let result = await prepareDocumentResult(from: urls)
            finish(with: result?.promptResult)
        }
    }
    
    nonisolated func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            presentedController = nil
            isCompletingPicker = true
            controller.dismiss(animated: true)
            finish(with: nil)
        }
    }
}

@available(iOS 14.0, *)
extension FilePicker: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            presentedController = nil
            isCompletingPicker = true
            picker.dismiss(animated: true)
            let result = await preparePhotoLibraryResult(from: results)
            finish(with: result?.promptResult)
        }
    }
}

extension FilePicker: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    nonisolated func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            presentedController = nil
            isCompletingPicker = true
            picker.dismiss(animated: true)
            finish(with: nil)
        }
    }
    
    nonisolated func imagePickerController(
        _ picker: UIImagePickerController,
        didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
    ) {
        let mediaURL = info[.mediaURL] as? URL
        let imageURL = info[.imageURL] as? URL
        let imageData = (info[.originalImage] as? UIImage)?.jpegData(compressionQuality: UX.imageCompressionQuality)
        
        Task { @MainActor [weak self] in
            guard let self else { return }
            presentedController = nil
            isCompletingPicker = true
            picker.dismiss(animated: true)
            let result = await prepareMediaResult(mediaURL: mediaURL, imageURL: imageURL, imageData: imageData)
            finish(with: result?.promptResult)
        }
    }
}

extension FilePicker: UIAdaptivePresentationControllerDelegate {
    nonisolated func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            guard !isCompletingPicker else { return }
            presentedController = nil
            finish(with: nil)
        }
    }
}

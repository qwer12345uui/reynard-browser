//
//  FilePickerDelegateCallbacks.swift
//  Reynard
//
//  Created by Minh Ton on 17/6/26.
//

@preconcurrency import PhotosUI
import UIKit

extension FilePicker: UIDocumentPickerDelegate {
    nonisolated func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            dismissPicker(controller) { picker in
                let result = await picker.prepareDocumentResult(from: urls)
                picker.finish(with: result?.promptResult)
            }
        }
    }
    
    nonisolated func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        Task { @MainActor [weak self] in
            self?.dismissPicker(controller) { picker in
                picker.finish(with: nil)
            }
        }
    }
}

@available(iOS 14.0, *)
extension FilePicker: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            dismissPicker(picker) { filePicker in
                let result = await filePicker.preparePhotoLibraryResult(from: results)
                filePicker.finish(with: result?.promptResult)
            }
        }
    }
}

extension FilePicker: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    nonisolated func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        Task { @MainActor [weak self] in
            self?.dismissPicker(picker) { filePicker in
                filePicker.finish(with: nil)
            }
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
            dismissPicker(picker) { filePicker in
                let result = await filePicker.prepareMediaResult(mediaURL: mediaURL, imageURL: imageURL, imageData: imageData)
                filePicker.finish(with: result?.promptResult)
            }
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

import Photos
import PhotosUI
import SwiftUI

struct PhotoAssetPicker: UIViewControllerRepresentable {
    let onSelect: (PHAsset) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration(
            photoLibrary: PHPhotoLibrary.shared()
        )
        configuration.filter = .videos
        configuration.selectionLimit = 1
        configuration.preferredAssetRepresentationMode = .current
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(
        _ uiViewController: PHPickerViewController,
        context: Context
    ) {}

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        private let parent: PhotoAssetPicker

        init(parent: PhotoAssetPicker) {
            self.parent = parent
        }

        func picker(
            _ picker: PHPickerViewController,
            didFinishPicking results: [PHPickerResult]
        ) {
            picker.dismiss(animated: true)
            guard let identifier = results.first?.assetIdentifier else { return }
            let fetch = PHAsset.fetchAssets(
                withLocalIdentifiers: [identifier],
                options: nil
            )
            if let asset = fetch.firstObject {
                parent.onSelect(asset)
            }
        }
    }
}


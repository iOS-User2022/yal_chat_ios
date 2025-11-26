//
//  ImagePicker.swift
//  YAL
//
//  Created by Vishal Bhadade on 26/04/25.
//
import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

enum ImagePickerSource {
    case photoLibrary
    case camera
}

struct ImagePicker: UIViewControllerRepresentable {
    var source: ImagePickerSource = .photoLibrary
    var filter: [UTType] = [.image, .movie, .gif] // default filter
    var onPicked: (_ url: URL?, _ fileName: String?, _ mimeType: String?, _ fileSize: Int?) -> Void

    func makeUIViewController(context: Context) -> UIViewController {
        switch source {
        case .photoLibrary:
            var config = PHPickerConfiguration()
            let pickerFilters = filter.compactMap { utType -> PHPickerFilter? in
                if utType == .image { return .images }
                if utType == .movie { return .videos }
                return nil
            }
            config.filter = pickerFilters.isEmpty ? nil : .any(of: pickerFilters)
            config.selectionLimit = 1

            let picker = PHPickerViewController(configuration: config)
            picker.delegate = context.coordinator
            return picker

        case .camera:
            let picker = UIImagePickerController()
            picker.delegate = context.coordinator
            picker.sourceType = .camera
            picker.mediaTypes = filter.map { $0.identifier } // ["public.image", "public.movie"]
            picker.videoQuality = .typeHigh
            picker.videoMaximumDuration = 60
            return picker
        }
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, PHPickerViewControllerDelegate, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        // MARK: - PHPicker delegate
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard let provider = results.first?.itemProvider else {
                parent.onPicked(nil, nil, nil, nil)
                return
            }
            handleItemProvider(provider)
        }

        // MARK: - UIImagePickerController delegate
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            picker.dismiss(animated: true)

            if let image = info[.originalImage] as? UIImage {
                saveImageToTemp(image: image)
            } else if let videoURL = info[.mediaURL] as? URL {
                saveVideoToTemp(videoURL: videoURL)
            } else if let gifURL = info[.imageURL] as? URL {
                saveGifToTemp(gifURL: gifURL)
            } else {
                parent.onPicked(nil, nil, nil, nil)
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }

        // MARK: - Helpers
        private func handleItemProvider(_ provider: NSItemProvider) {
            let formats: [(String, String)] = [
                (UTType.gif.identifier, "gif"),
                (UTType.image.identifier, "jpg"),
                (UTType.movie.identifier, "mp4")
            ]

            for (type, ext) in formats {
                if provider.hasItemConformingToTypeIdentifier(type) {
                    provider.loadFileRepresentation(forTypeIdentifier: type) { tempURL, error in
                        guard let tempURL = tempURL else {
                            DispatchQueue.main.async { self.parent.onPicked(nil, nil, nil, nil) }
                            return
                        }

                        let fileName = UUID().uuidString + "." + ext
                        let destURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
                        do {
                            try FileManager.default.copyItem(at: tempURL, to: destURL)
                            let fileSize = (try? FileManager.default.attributesOfItem(atPath: destURL.path)[.size] as? Int) ?? nil
                            DispatchQueue.main.async {
                                self.parent.onPicked(destURL, fileName, mimeTypeForFileExtension(ext), fileSize)
                            }
                        } catch {
                            DispatchQueue.main.async { self.parent.onPicked(nil, nil, nil, nil) }
                        }
                    }
                    return
                }
            }
            DispatchQueue.main.async { self.parent.onPicked(nil, nil, nil, nil) }
        }

        private func saveImageToTemp(image: UIImage) {
            let fileName = UUID().uuidString + ".jpg"
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            if let data = image.jpegData(compressionQuality: 0.8) {
                do {
                    try data.write(to: url)
                    let fileSize = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? nil
                    parent.onPicked(url, fileName, "image/jpeg", fileSize)
                } catch {
                    parent.onPicked(nil, nil, nil, nil)
                }
            } else {
                parent.onPicked(nil, nil, nil, nil)
            }
        }

        private func saveVideoToTemp(videoURL: URL) {
            let ext = videoURL.pathExtension
            let fileName = UUID().uuidString + "." + ext
            let destURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            do {
                try FileManager.default.copyItem(at: videoURL, to: destURL)
                let fileSize = (try? FileManager.default.attributesOfItem(atPath: destURL.path)[.size] as? Int) ?? nil
                parent.onPicked(destURL, fileName, mimeTypeForFileExtension(ext), fileSize)
            } catch {
                parent.onPicked(nil, nil, nil, nil)
            }
        }
        
        private func saveGifToTemp(gifURL: URL) {
            let ext = gifURL.pathExtension
            let fileName = UUID().uuidString + "." + ext
            let destURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            do {
                try FileManager.default.copyItem(at: gifURL, to: destURL)
                let fileSize = (try? FileManager.default.attributesOfItem(atPath: destURL.path)[.size] as? Int) ?? nil
                DispatchQueue.main.async {
                    self.parent.onPicked(destURL, fileName, "image/gif", fileSize)
                }
            } catch {
                DispatchQueue.main.async { self.parent.onPicked(nil, nil, nil, nil) }
            }
        }
    }
}

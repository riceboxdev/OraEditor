//
//  ImageCropperView.swift
//  OraEditor
//
//  Created by Nick Rogers on 8/18/25.
//


import SwiftUI
import PhotosUI

struct ImageCropperView: View {
    @State private var selectedImage: UIImage?
    @State private var croppedImage: UIImage?
    @State private var showingImagePicker = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var cropRect = CGRect(x: 50, y: 50, width: 200, height: 200)
    @State private var imageSize = CGSize.zero
    @State private var imageOffset = CGPoint.zero
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if let selectedImage = selectedImage {
                    // Image cropping area
                    GeometryReader { geometry in
                        ZStack {
                            // Original image - now using SwiftUI Image
                            Image(uiImage: selectedImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .onAppear {
                                    calculateImageSize(in: geometry.size, for: selectedImage)
                                }
                            
                            // Crop overlay
                            CropOverlay(
                                cropRect: $cropRect,
                                imageSize: imageSize,
                                containerSize: geometry.size
                            )
                        }
                    }
                    .frame(height: 400)
                    .clipped()
                    
                    // Control buttons
                    HStack(spacing: 20) {
                        Button("Reset Crop") {
                            resetCropArea()
                        }
                        .buttonStyle(.bordered)
                        
                        Button("Crop Image") {
                            cropImage()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(selectedImage == nil)
                    }
                    
                    // Show cropped result - SwiftUI Image
                    if let croppedImage = croppedImage {
                        VStack {
                            Text("Cropped Result:")
                                .font(.headline)
                            
                            Image(uiImage: croppedImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxHeight: 200)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.gray, lineWidth: 1)
                                )
                        }
                    }
                } else {
                    // Placeholder when no image is selected
                    VStack(spacing: 20) {
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("Select an image to crop")
                            .font(.title2)
                            .foregroundColor(.gray)
                        
                        Button("Choose Image") {
                            // Modern SwiftUI approach would be to use PhotosPicker
                            // but keeping compatibility with UIImagePickerController
                            showingImagePicker = true
                        }
                        .buttonStyle(.borderedProminent)
                        
                        // Alternative: Modern PhotosPicker approach
                        PhotosPicker("Choose with PhotosPicker", selection: $selectedPhotoItem, matching: .images)
                            .buttonStyle(.bordered)
                            .onChange(of: selectedPhotoItem) { _, newValue in
                                loadPhoto(from: newValue)
                            }
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Image Cropper")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("New Image") {
                        showingImagePicker = true
                    }
                }
            }
            .sheet(isPresented: $showingImagePicker) {
                ImagePicker(selectedImage: $selectedImage) {
                    resetCropArea()
                    croppedImage = nil
                }
            }
        }
    }
    
    // Load photo from PhotosPicker (modern SwiftUI approach)
    private func loadPhoto(from item: PhotosPickerItem?) {
        guard let item = item else { return }
        
        item.loadTransferable(type: Data.self) { result in
            switch result {
            case .success(let data):
                if let data = data, let uiImage = UIImage(data: data) {
                    DispatchQueue.main.async {
                        self.selectedImage = uiImage
                        self.resetCropArea()
                        self.croppedImage = nil
                    }
                }
            case .failure(let error):
                print("Error loading photo: \(error)")
            }
        }
    }
    
    private func calculateImageSize(in containerSize: CGSize, for image: UIImage) {
        let imageAspectRatio = image.size.width / image.size.height
        let containerAspectRatio = containerSize.width / containerSize.height
        
        if imageAspectRatio > containerAspectRatio {
            // Image is wider than container
            imageSize.width = containerSize.width
            imageSize.height = containerSize.width / imageAspectRatio
        } else {
            // Image is taller than container
            imageSize.height = containerSize.height
            imageSize.width = containerSize.height * imageAspectRatio
        }
        
        // Center the image
        imageOffset.x = (containerSize.width - imageSize.width) / 2
        imageOffset.y = (containerSize.height - imageSize.height) / 2
    }
    
    private func resetCropArea() {
        let defaultSize: CGFloat = min(imageSize.width, imageSize.height) * 0.6
        cropRect = CGRect(
            x: imageOffset.x + (imageSize.width - defaultSize) / 2,
            y: imageOffset.y + (imageSize.height - defaultSize) / 2,
            width: defaultSize,
            height: defaultSize
        )
    }
    
    private func cropImage() {
        guard let selectedImage = selectedImage else { return }
        
        // Calculate the crop rect relative to the actual image size
        let scaleX = selectedImage.size.width / imageSize.width
        let scaleY = selectedImage.size.height / imageSize.height
        
        let cropRectInImage = CGRect(
            x: (cropRect.origin.x - imageOffset.x) * scaleX,
            y: (cropRect.origin.y - imageOffset.y) * scaleY,
            width: cropRect.width * scaleX,
            height: cropRect.height * scaleY
        )
        
        // Perform the crop
        if let cgImage = selectedImage.cgImage?.cropping(to: cropRectInImage) {
            croppedImage = UIImage(cgImage: cgImage)
        }
    }
}

struct CropOverlay: View {
    @Binding var cropRect: CGRect
    let imageSize: CGSize
    let containerSize: CGSize
    
    @State private var isDragging = false
    @State private var dragOffset = CGSize.zero
    
    private let handleSize: CGFloat = 20
    private let minCropSize: CGFloat = 50
    
    var body: some View {
        ZStack {
            // Dimmed overlay
            Rectangle()
                .fill(Color.black.opacity(0.5))
                .mask {
                    Rectangle()
                        .fill(Color.black)
                        .overlay {
                            Rectangle()
                                .frame(width: cropRect.width, height: cropRect.height)
                                .position(
                                    x: cropRect.midX,
                                    y: cropRect.midY
                                )
                                .blendMode(.destinationOut)
                        }
                }
            
            // Crop rectangle border
            Rectangle()
                .stroke(Color.white, lineWidth: 2)
                .frame(width: cropRect.width, height: cropRect.height)
                .position(x: cropRect.midX, y: cropRect.midY)
            
           
            
            // Center drag handle for moving
            Rectangle()
                .fill(Color.clear)
                .frame(width: cropRect.width, height: cropRect.height)
                .position(x: cropRect.midX, y: cropRect.midY)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            moveCrop(translation: value.translation)
                        }
                )
        }
    }
    
    private func getCornerPosition(_ index: Int) -> CGPoint {
        switch index {
        case 0: // Top-left
            return CGPoint(x: cropRect.minX, y: cropRect.minY)
        case 1: // Top-right
            return CGPoint(x: cropRect.maxX, y: cropRect.minY)
        case 2: // Bottom-right
            return CGPoint(x: cropRect.maxX, y: cropRect.maxY)
        case 3: // Bottom-left
            return CGPoint(x: cropRect.minX, y: cropRect.maxY)
        default:
            return CGPoint.zero
        }
    }
    
    private func resizeCrop(corner: Int, translation: CGSize) {
        var newRect = cropRect
        
        switch corner {
        case 0: // Top-left
            newRect.origin.x += translation.width
            newRect.origin.y += translation.height
            newRect.size.width -= translation.width
            newRect.size.height -= translation.height
        case 1: // Top-right
            newRect.origin.y += translation.height
            newRect.size.width += translation.width
            newRect.size.height -= translation.height
        case 2: // Bottom-right
            newRect.size.width += translation.width
            newRect.size.height += translation.height
        case 3: // Bottom-left
            newRect.origin.x += translation.width
            newRect.size.width -= translation.width
            newRect.size.height += translation.height
        default:
            break
        }
        
        // Ensure minimum size
        if newRect.width >= minCropSize && newRect.height >= minCropSize {
            // Keep within image bounds
            let imageFrame = CGRect(
                x: (containerSize.width - imageSize.width) / 2,
                y: (containerSize.height - imageSize.height) / 2,
                width: imageSize.width,
                height: imageSize.height
            )
            
            newRect = newRect.intersection(imageFrame)
            
            if !newRect.isEmpty {
                cropRect = newRect
            }
        }
    }
    
    private func moveCrop(translation: CGSize) {
        var newRect = cropRect
        newRect.origin.x += translation.width
        newRect.origin.y += translation.height
        
        // Keep within image bounds
        let imageFrame = CGRect(
            x: (containerSize.width - imageSize.width) / 2,
            y: (containerSize.height - imageSize.height) / 2,
            width: imageSize.width,
            height: imageSize.height
        )
        
        if imageFrame.contains(newRect) {
            cropRect = newRect
        }
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    let onImageSelected: () -> Void
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.selectedImage = image
                parent.onImageSelected()
            }
            picker.dismiss(animated: true)
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}



#Preview {
    ImageCropperView()
}

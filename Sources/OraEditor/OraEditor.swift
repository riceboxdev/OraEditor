// The Swift Programming Language
// https://docs.swift.org/swift-book
import SwiftUI
import PhotosUI
import AVKit
import Combine


class OraManager: ObservableObject {
    @Published var isLoading: Bool = false
    @Published var step: OraEditorSteps = .editPhoto
    @Published var sheetState: EditorSheetState = .collapsed
    @Published var isCropping: Bool = false
    @Published var getColor: Bool = false
    @Published var showToolSheet: Bool = false
    @Published var selectedImage: UIImage? = UIImage(named: "sample")
    @Published var croppedImage: UIImage?
    @Published var selectedDetent: PresentationDetent = .height(EditorSheetState.toolMode.rawValue)
    
    // Crop-related properties
    @Published var imageScale: CGFloat = 1.0
    @Published var imageOffset: CGSize = .zero
    @Published var cropRect: CGRect = .zero
    @Published var lastImageScale: CGFloat = 1.0
    @Published var lastImageOffset: CGSize = .zero
    @Published var lastCropRect: CGRect = .zero
    
    let targetAspectRatio: CGFloat = 0.46
    
    func shouldAutoCrop(image: UIImage) -> Bool {
        let imageAspectRatio = image.size.width / image.size.height
        let tolerance: CGFloat = 0.05
        return abs(imageAspectRatio - targetAspectRatio) > tolerance
    }
    
  
  
    
    // MARK: - Image Downloading
    
    enum ImageDownloadError: Error {
        case badStatusCode(Int)
        case invalidImageData
    }
    
    // Downloads an image from a URL and returns a UIImage. Throws on failure.
    static func downloadImage(from url: URL) async throws -> UIImage {
        let (data, response) = try await URLSession.shared.data(from: url)
        
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw ImageDownloadError.badStatusCode(http.statusCode)
        }
        
        guard let image = UIImage(data: data) else {
            throw ImageDownloadError.invalidImageData
        }
        
        return image
    }
    
    // Convenience: downloads and sets the image on the manager, updating UI state.
    @MainActor
    func downloadAndSetImage(from url: URL) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let image = try await OraManager.downloadImage(from: url)
            selectedImage = image
            
            // Auto-crop decision
            if shouldAutoCrop(image: image) {
                isCropping = true
            }
            
            step = .editPhoto
        } catch {
            // Handle or surface the error as needed
            print("Failed to download image:", error)
        }
    }
}

enum OraEditorSteps: String, CaseIterable {
    case selectPhoto = "Select Photo"
    case editPhoto = "Edit Photo"
}

public struct OraEditor: View {
    @StateObject var manager = OraManager()
    public init() { }
    public var body: some View {
        Group {
            if manager.isLoading {
                LoadingView()
            } else {
                Group {
                    switch manager.step {
                    case .selectPhoto:
                        DefaultEditorView()
                            .environmentObject(manager)
                    case .editPhoto:
                        ImageEditorView()
                            .environmentObject(manager)
                    }
                }
                .transition(.opacity.animation(.smooth(duration: 1)))
                .animation(.smooth(duration: 1), value: manager.step)
            }
        }
        .transition(.opacity)
        .animation(.smooth(duration: 0.1), value: manager.isLoading)
        .onAppear() {
            Task {
                if let url = URL(string: "https://picsum.photos/500/1100") {
                    await manager.downloadAndSetImage(from: url)
                }
            }
        }
    }
}

struct LoadingView: View {
    @State var animating: Bool = true
    var body: some View {
        VStack {
            Spacer()
            Text("Loading...")
                .font(.subheadline)
                .fontDesign(.monospaced)
                .bold()
                .opacity(animating ? 1 : 0.4)
                .animation(.smooth(duration: 0.2).repeatForever(autoreverses: true), value: animating)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(.quinary)
        .ignoresSafeArea()
        .onAppear() {
            animating = false
        }
    }
}

struct DefaultEditorView: View {
    @EnvironmentObject var manager: OraManager
    @State var pickedPhoto: PhotosPickerItem?
    var body: some View {
        ZStack {
            Rectangle()
                .fill(.quinary)
                .ignoresSafeArea()
            
            PhotosPicker(selection: $pickedPhoto, matching: .images) {
                ZStack {
                    Circle()
                        .fill(.quaternary)
                        .frame(width: 200, height: 200)
                    
                    Text("Upload a Photo\nto Start".uppercased())
                        .font(.subheadline)
                        .fontDesign(.monospaced)
                        .bold()
                        .multilineTextAlignment(.center)
                }
            }
            .buttonStyle(.plain)
        }
        .onChange(of: pickedPhoto) {
           loadPhoto(from: pickedPhoto)
        }
    }
     
    private func loadPhoto(from item: PhotosPickerItem?) {
        guard let item = item else { return }
        manager.isLoading = true
        
        item.loadTransferable(type: Data.self) { result in
            switch result {
            case .success(let data):
                if let data = data, let uiImage = UIImage(data: data) {
                    DispatchQueue.main.async {
                        self.manager.selectedImage = uiImage
                        
                        // Check if auto-crop is needed
                        if manager.shouldAutoCrop(image: uiImage) {
                            manager.isCropping = true
                        }
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        manager.isLoading = false
                        manager.step = .editPhoto
                    }
                }
            case .failure(let error):
                print("Error loading photo: \(error)")
                DispatchQueue.main.async {
                    manager.isLoading = false
                }
            }
        }
    }
}

public struct Shimmer: ViewModifier {
    @State var isInitialState: Bool = true
    public func body(content: Content) -> some View {
        content
            .mask {
                LinearGradient(
                    gradient: .init(colors: [.black.opacity(0.4), .black, .black.opacity(0.4)]),
                    startPoint: (isInitialState ? .init(x: -0.3, y: -0.3) : .init(x: 1.3, y: 1.3)),
                    endPoint: (isInitialState ? .init(x: 0, y: 0) : .init(x: -1.3, y: -1.3))
                )
            }
            .animation(.smooth(duration: 0.5).repeatForever(autoreverses: true), value: isInitialState)
            .onAppear() {
                isInitialState = false
            }
    }
}

enum EditorSheetState: CGFloat {
    case collapsed = 80
    case toolMode  = 160
    case expanded  = 350
}

struct ImageEditorView: View {
    @EnvironmentObject var manager: OraManager
    @State private var showControls = true
    @State private var imagePreviewHeight: CGFloat = 400
    @State private var spacerHeight: CGFloat = EditorSheetState.collapsed.rawValue
    @State private var imageSize = CGSize.zero
    @State private var imageOffset = CGPoint.zero
    
    @State private var photosItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var showDialog = false
    @State private var selectedCropType: Crop = .rectangle
    @State private var showCropView = false
    
    // Namespace for matched geometry between preview and crop view
    @Namespace private var cropNamespace
    
    let compactSize = EditorSheetState.collapsed.rawValue
    let toolSize = EditorSheetState.toolMode.rawValue
    let expandedSize = EditorSheetState.expanded.rawValue
    let showBounds = false
   
    var body: some View {
        VStack {
            ZStack {
                GeometryReader { geo in
                    let imageHeight = geo.size.height - 100
                    VStack {
                        if let image = manager.selectedImage {
                           Image(uiImage: image)
                                .resizable()
                                .aspectRatio(manager.targetAspectRatio, contentMode: .fit)
                                .frame(height: imageHeight)
                                .clipped()
                                // Matched geometry source
                                .matchedGeometryEffect(id: "editorImage", in: cropNamespace)
                        }
                    }
                    .containerRelativeFrame(.horizontal)
                }
                .border(showBounds ? .green : .clear)
                
                if manager.isCropping {
                    CropView(
                        crop: .rectangle,
                        image: manager.selectedImage,
                        // Matched geometry destination
                        namespace: cropNamespace,
                        matchedId: "editorImage"
                    ) { croppedImage, status in
                        if let croppedImage {
                            manager.croppedImage = croppedImage
                        }
                        if status {
                            manager.isCropping = false
                        }
                    }
                    .onAppear() {
                        showControls = false
                    }
                    .onDisappear() {
                        showControls = true
                    }
                }
            }
            
            if showControls {
                Rectangle()
                    .fill(.clear)
                    .frame(height: spacerHeight)
                    .padding(.vertical)
                    .border(showBounds ? .blue : .clear)
            }
        }
//        .background(Color(UIColor.secondarySystemBackground))
        .onChange(of: manager.selectedDetent) { newValue in
            if newValue == .height(compactSize) {
                withAnimation(.smooth) {
                    self.spacerHeight = compactSize
                }
            } else if newValue == .height(toolSize) {
                withAnimation(.smooth) {
                    self.spacerHeight = toolSize
                }
            } else if newValue == .height(expandedSize) {
                withAnimation(.smooth) {
                    self.spacerHeight = expandedSize
                }
            }
        }
        .sheet(isPresented: $showControls) {
          EditorSheetView()
            .presentationDetents(
                [
                    .height(EditorSheetState.collapsed.rawValue),
                    .height(EditorSheetState.toolMode.rawValue),
                    .height(EditorSheetState.expanded.rawValue)
                ],
                selection: $manager.selectedDetent
            )
            .presentationBackgroundInteraction(.enabled)
            .interactiveDismissDisabled()
        }
    }
    
    private func calculateImageSize(in containerSize: CGSize, for image: UIImage) {
        let imageAspectRatio = image.size.width / image.size.height
        let containerAspectRatio = containerSize.width / containerSize.height
        
        if imageAspectRatio > containerAspectRatio {
            imageSize.width = containerSize.width
            imageSize.height = containerSize.width / imageAspectRatio
        } else {
            imageSize.height = containerSize.height
            imageSize.width = containerSize.height * imageAspectRatio
        }
        
        imageOffset.x = (containerSize.width - imageSize.width) / 2
        imageOffset.y = (containerSize.height - imageSize.height) / 2
    }
    
    private func calculateCropRect(in containerSize: CGSize, imageHeight: CGFloat) {
        let cropWidth = imageHeight * manager.targetAspectRatio
        let cropHeight = imageHeight - 40 // Some padding
        
        manager.cropRect = CGRect(
            x: (containerSize.width - cropWidth) / 2,
            y: 20,
            width: cropWidth,
            height: cropHeight
        )
    }
}

// New Interactive Crop Overlay
struct InteractiveCropOverlay: View {
    @ObservedObject var manager: OraManager
    let containerSize: CGSize
    
    var body: some View {
        ZStack {
            // Non-interactive dimming overlay
            DimmingOverlay(cropRect: manager.cropRect)
                .allowsHitTesting(false) // Key: doesn't block image gestures
            
            // Interactive crop border
            InteractiveCropBorder(
                cropRect: $manager.cropRect,
                lastCropRect: $manager.lastCropRect,
                containerSize: containerSize
            )
            
            // Interactive corner handles
            ForEach(0..<4, id: \.self) { index in
                CropHandle(
                    index: index,
                    cropRect: $manager.cropRect,
                    lastCropRect: $manager.lastCropRect,
                    containerSize: containerSize
                )
            }
        }
    }
}

struct DimmingOverlay: View {
    let cropRect: CGRect
    
    var body: some View {
        // Create dimming effect with clear crop area
        Rectangle()
            .fill(Color.black.opacity(0.5))
            .mask(
                Rectangle()
                    .overlay(
                        Rectangle()
                            .frame(width: cropRect.width, height: cropRect.height)
                            .position(x: cropRect.midX, y: cropRect.midY)
                            .blendMode(.destinationOut)
                    )
                    .compositingGroup()
            )
    }
}

struct InteractiveCropBorder: View {
    @Binding var cropRect: CGRect
    @Binding var lastCropRect: CGRect
    let containerSize: CGSize
    
    var body: some View {
        Rectangle()
            .stroke(Color.white, lineWidth: 2)
            .frame(width: cropRect.width, height: cropRect.height)
            .position(x: cropRect.midX, y: cropRect.midY)
            // Make only the border interactive with a wider hit area
            .contentShape(
                Rectangle()
                    .stroke(lineWidth: 20) // Wider invisible hit area
            )
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let newX = lastCropRect.origin.x + value.translation.width
                        let newY = lastCropRect.origin.y + value.translation.height
                        
                        cropRect = CGRect(
                            x: max(0, min(newX, containerSize.width - cropRect.width)),
                            y: max(0, min(newY, containerSize.height - cropRect.height)),
                            width: cropRect.width,
                            height: cropRect.height
                        )
                    }
                    .onEnded { _ in
                        lastCropRect = cropRect
                    }
            )
    }
}

struct CropHandle: View {
    let index: Int
    @Binding var cropRect: CGRect
    @Binding var lastCropRect: CGRect
    let containerSize: CGSize
    
    private var handlePosition: CGPoint {
        switch index {
        case 0: return CGPoint(x: cropRect.minX, y: cropRect.minY) // Top-left
        case 1: return CGPoint(x: cropRect.maxX, y: cropRect.minY) // Top-right
        case 2: return CGPoint(x: cropRect.maxX, y: cropRect.maxY) // Bottom-right
        case 3: return CGPoint(x: cropRect.minX, y: cropRect.maxY) // Bottom-left
        default: return CGPoint.zero
        }
    }
    
    var body: some View {
        // Using corner indicators similar to your original design
        ZStack {
            // Horizontal line
            Rectangle()
                .fill(Color.white)
                .frame(width: 20, height: 3)
            
            // Vertical line
            Rectangle()
                .fill(Color.white)
                .frame(width: 3, height: 20)
        }
        .position(handlePosition)
        .contentShape(Rectangle()) // Larger touch area
        .gesture(
            DragGesture()
                .onChanged { value in
                    resizeCropRect(with: value.translation)
                }
                .onEnded { _ in
                    lastCropRect = cropRect
                }
        )
    }
    
    private func resizeCropRect(with translation: CGSize) {
        let minSize: CGFloat = 50 // Minimum crop size
        var newRect = lastCropRect
        
        switch index {
        case 0: // Top-left
            let newWidth = max(minSize, lastCropRect.width - translation.width)
            let newHeight = max(minSize, lastCropRect.height - translation.height)
            let deltaWidth = lastCropRect.width - newWidth
            let deltaHeight = lastCropRect.height - newHeight
            
            newRect = CGRect(
                x: lastCropRect.origin.x + deltaWidth,
                y: lastCropRect.origin.y + deltaHeight,
                width: newWidth,
                height: newHeight
            )
            
        case 1: // Top-right
            let newWidth = max(minSize, lastCropRect.width + translation.width)
            let newHeight = max(minSize, lastCropRect.height - translation.height)
            let deltaHeight = lastCropRect.height - newHeight
            
            newRect = CGRect(
                x: lastCropRect.origin.x,
                y: lastCropRect.origin.y + deltaHeight,
                width: newWidth,
                height: newHeight
            )
            
        case 2: // Bottom-right
            newRect = CGRect(
                x: lastCropRect.origin.x,
                y: lastCropRect.origin.y,
                width: max(minSize, lastCropRect.width + translation.width),
                height: max(minSize, lastCropRect.height + translation.height)
            )
            
        case 3: // Bottom-left
            let newWidth = max(minSize, lastCropRect.width - translation.width)
            let deltaWidth = lastCropRect.width - newWidth
            
            newRect = CGRect(
                x: lastCropRect.origin.x + deltaWidth,
                y: lastCropRect.origin.y,
                width: newWidth,
                height: max(minSize, lastCropRect.height + translation.height)
            )
            
        default:
            break
        }
        
        // Ensure the crop rect stays within bounds
        newRect.origin.x = max(0, newRect.origin.x)
        newRect.origin.y = max(0, newRect.origin.y)
        newRect.size.width = min(newRect.width, containerSize.width - newRect.origin.x)
        newRect.size.height = min(newRect.height, containerSize.height - newRect.origin.y)
        
        cropRect = newRect
    }
}

struct EditorSheetView: View {
    @EnvironmentObject var manager: OraManager
    let compactSize = EditorSheetState.collapsed.rawValue
    let toolSize = EditorSheetState.toolMode.rawValue
    let expandedSize = EditorSheetState.expanded.rawValue
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                CircleButton(icon: "crop", isActive: $manager.isCropping) {
                    manager.isCropping.toggle()
                }
                CircleButton(icon: "drop", isActive: $manager.getColor) {
                    manager.getColor.toggle()
                    manager.selectedDetent = .height(toolSize)
                }
                Spacer()
                
                if manager.isCropping {
                    // Crop action button
                    CircleButton(icon: "checkmark", prominent: true, isActive: .constant(false)) {
//                        manager.cropImage()
                    }
                } else {
                    CircleButton(icon: "arrow.up", prominent: true, isActive: .constant(false)) {
                        // Export or other action
                    }
                }
            }
            .padding(.horizontal, 10)
            .onChange(of: manager.selectedDetent) { oldValue, newValue in
                if newValue == .height(compactSize) {
                    withAnimation(.smooth) {
                        manager.sheetState = .collapsed
                    }
                } else if newValue == .height(toolSize) {
                    withAnimation(.smooth) {
                        manager.sheetState = .toolMode
                    }
                }
                else if newValue == .height(expandedSize) {
                    withAnimation(.smooth) {
                        manager.sheetState = .expanded
                    }
                }
            }
            .frame(height: compactSize)
            .ignoresSafeArea()
            
            if manager.selectedDetent == .height(toolSize) && !manager.isCropping {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        Circle()
                            .fill(.clear)
                            .frame(width: 60, height: 60)
                            .overlay {
                                Circle()
                                    .fill(.red)
                                    .frame(width: 45, height: 45)
                            }
                        
                        Circle()
                            .fill(.clear)
                            .frame(width: 60, height: 60)
                            .overlay {
                                Circle()
                                    .fill(.pink)
                                    .frame(width: 45, height: 45)
                            }
                        
                        Circle()
                            .fill(.clear)
                            .frame(width: 60, height: 60)
                            .overlay {
                                Circle()
                                    .fill(.indigo)
                                    .frame(width: 45, height: 45)
                            }
                        
                        Spacer()
                    }
                }
                .background(.quinary.opacity(0.25), in: .capsule)
                .padding(10)
                .frame(height: 60)
            } else if manager.isCropping {
                // Crop mode instructions
//                VStack {
//                    Text("Drag corners to resize • Drag border to move")
//                        .font(.caption)
//                        .foregroundColor(.secondary)
//                        .padding(.top, 10)
//                    
//                    Text("Touch image area to zoom and pan")
//                        .font(.caption2)
//                        .foregroundColor(.secondary)
//                        .padding(.bottom, 10)
//                }
//                .frame(height: 60)
            }
        }
        .ignoresSafeArea()
        .animation(.smooth, value: manager.selectedDetent)
        .animation(.smooth, value: manager.isCropping)
    }
}

struct CircleButton: View {
    var icon: String = ""
    var prominent: Bool = false
    @Binding var isActive: Bool
    var action: () -> Void = { print("Tapped") }
    var body: some View {
        if #available(iOS 17.0, *) {
            Button {
                withAnimation(.smooth) {
                    action()
                }
            } label: {
                Circle()
                    .fill(prominent ? Color.accentColor : Color.clear)
                    .overlay {
                        Image(systemName: icon)
                            .foregroundStyle(.white)
                    }
                    .overlay {
                        Circle()
                            .fill(.clear)
                            .stroke(isActive ? Color.white : .clear, lineWidth: 2)
                    }
            }
            .frame(width: 60, height: 60)
            .buttonStyle(.plain)
            .background(.ultraThinMaterial, in: .circle)
            .animation(.smooth, value: isActive)
        } else {
            // Fallback for earlier versions
            Button {
                withAnimation(.smooth) {
                    action()
                }
            } label: {
                Circle()
                    .fill(prominent ? .blue : .clear)
                    .overlay {
                        Image(systemName: icon)
                            .foregroundStyle(.white)
                    }
                    .overlay {
                        Circle()
                            .fill(.clear)
                            .stroke(isActive ? Color.white : .clear, lineWidth: 2)
                    }
            }
            .frame(width: 60, height: 60)
            .buttonStyle(.plain)
            .background(.ultraThinMaterial, in: .circle)
            .animation(.smooth, value: isActive)
        }
    }
}

#Preview {
    ZStack {
        if let image = UIImage(named: "sample") {
            Image(uiImage: image)
        }
        LinearGradient(colors: [.red.opacity(0.2), .blue], startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
            .opacity(0.3)
        OraEditor()
    }
}

#Preview {
   ToolbarPreview()
}

struct ToolbarPreview: View {
    @StateObject var manager = OraManager()
    @State var isPresented: Bool = true
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Controls Sheet")
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(
                    colors: [
                        .clear,
                        .blue
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .sheet(isPresented: $isPresented) {
                EditorSheetView()
                    .environmentObject(manager)
                    .presentationDetents(
                        [
                            .height(EditorSheetState.collapsed.rawValue),
                            .height(EditorSheetState.toolMode.rawValue),
                            .height(EditorSheetState.expanded.rawValue)
                        ],
                        selection: $manager.selectedDetent
                    )
                    .presentationBackgroundInteraction(.enabled)
                    .interactiveDismissDisabled()
            }
        }
    }
}


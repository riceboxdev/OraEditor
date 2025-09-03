// The Swift Programming Language
// https://docs.swift.org/swift-book
import SwiftUI
import PhotosUI
import AVKit
import Combine
import ColorKit


class OraManager: ObservableObject {
    @Published var isLoading: Bool = false
    @Published var step: OraEditorSteps = .editPhoto
    @Published var selectedTool: EditorSheetTools?
    @Published var isCropping: Bool = false
    @Published var showToolSheet: Bool = false
    @Published var selectedImage: UIImage?
    @Published var croppedImage: UIImage?
    @Published var selectedDetent: PresentationDetent = .height(EditorSheetState.collapsed.rawValue)
    
    @Published var backgroundColor: UIColor = .blue
    @Published var extractedColors: [UIColor] = []
    
    let targetAspectRatio: CGFloat = 0.46
    
    func shouldAutoCrop(image: UIImage) -> Bool {
        let imageAspectRatio = image.size.width / image.size.height
        let tolerance: CGFloat = 0.05
        return abs(imageAspectRatio - targetAspectRatio) > tolerance
    }
    
  
  
    func getColors(from image: UIImage) {
        do {
            self.extractedColors = try image.dominantColors()
        } catch {
            print("Failed To get dominant colors!")
        }
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
        .background {
            LinearGradient(
                colors: [
                    .clear,
                    Color(manager.backgroundColor)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
                .ignoresSafeArea()
                .opacity(0.3)
        }
        .transition(.opacity)
        .animation(.smooth(duration: 0.1), value: manager.isLoading)
//        .onAppear() {
//            Task {
//                if let url = URL(string: "https://picsum.photos/500/1100") {
//                    await manager.downloadAndSetImage(from: url)
//                }
//            }
//        }
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

public struct ImageEditorView: View {
    @StateObject var manager: OraManager = .init()
    @State private var showControls = false
    @State private var imagePreviewHeight: CGFloat = 400
    @State private var spacerHeight: CGFloat = EditorSheetState.collapsed.rawValue
    @State private var imageSize = CGSize.zero
    @State private var imageOffset = CGPoint.zero
    
    @State private var photosItem: PhotosPickerItem?
    @State private var showDialog = false
    @State private var selectedCropType: Crop = .rectangle
    @State private var showCropView = false
    
    // Namespace for matched geometry between preview and crop view
    @Namespace private var cropNamespace
    
    let compactSize = EditorSheetState.collapsed.rawValue
    let toolSize = EditorSheetState.toolMode.rawValue
    let expandedSize = EditorSheetState.expanded.rawValue
    let showBounds = false
    
    public init() { }
   
    public var body: some View {
        VStack {
            ZStack {
                
                rearImagePreview()
                
                if manager.isCropping {
                    CropView(
                        crop: .rectangle,
                        image: manager.selectedImage,
                        // Matched geometry destination for smooth transition from preview image
                        namespace: cropNamespace,
                        matchedId: "editorImage"
                    ) { croppedImage, status in
                        if let croppedImage {
                            manager.croppedImage = croppedImage
                        }
                        if status {
                            withAnimation(.smooth) {
                                manager.isCropping = false
                            }
                        } else {
                            withAnimation(.smooth) {
                                manager.isCropping = false
                            }
                        }
                    }
                    .onAppear() {
                        withAnimation(.smooth) {
                            showControls = false
                        }
                    }
                    .onDisappear() {
                        withAnimation(.smooth) {
                            showControls = true
                        }
                    }
                }
                
                if manager.selectedImage == nil {
                    DefaultEditorView()
                        .environmentObject(manager)
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
        .background {
            LinearGradient(
                colors: [
                    .clear,
                    Color(manager.backgroundColor)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
                .ignoresSafeArea()
                .opacity(0.4)
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
    
    @ViewBuilder
    func rearImagePreview() -> some View {
        GeometryReader { geo in
            let imageHeight = geo.size.height - 100
            VStack {
                if let image = manager.selectedImage {
                    // Matched geometry source for smooth transition to crop view
                   Image(uiImage: image)
                        .resizable()
                        .aspectRatio(manager.targetAspectRatio, contentMode: .fit)
                        .frame(height: imageHeight)
                        .clipped()
                        .matchedGeometryEffect(id: "editorImage", in: cropNamespace)
                        .onAppear() {
                            manager.getColors(from: image)
                            showControls = true
                        }
                }
            }
            .containerRelativeFrame(.horizontal)
        }
        .border(showBounds ? .green : .clear)
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

enum EditorSheetTools: CaseIterable {
    case crop
    case colorExtract
    
    var icon: String {
        switch self {
        case .crop: return "crop"
        case .colorExtract: return "drop"
        }
    }
}

extension EditorSheetTools {
    func action(manager: OraManager) -> () -> Void {
        switch self {
        case .crop:
            return { manager.isCropping.toggle() }
        case .colorExtract:
            return {
                if manager.selectedTool == .colorExtract {
                    withAnimation(.smooth) {
                        manager.selectedTool = .none
                        manager.selectedDetent = .height(EditorSheetState.collapsed.rawValue)
                    }
                } else {
                    withAnimation(.smooth) {
                        manager.selectedDetent = .height(EditorSheetState.toolMode.rawValue)
                        manager.selectedTool = .colorExtract
                    }
                }
            }
        }
    }

//    func isActive(manager: OraManager) -> Bool {
//        switch self {
//        case .crop:
//            return manager.isCropping
//        case .colorExtract:
//            return manager.getColor
//        }
//    }
}

struct EditorSheetView: View {
    @EnvironmentObject var manager: OraManager
    let compactSize = EditorSheetState.collapsed.rawValue
    let toolSize = EditorSheetState.toolMode.rawValue
    let expandedSize = EditorSheetState.expanded.rawValue
    
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                ForEach(EditorSheetTools.allCases, id: \.self) { tool in
                    CircleButton(icon: tool.icon, isActive: manager.selectedTool == tool) {
                        tool.action(manager: manager)()
                    }
                }
               
                
                Spacer()
                
                if manager.isCropping {
                    // Crop action button
                    CircleButton(icon: "checkmark", prominent: true, isActive: false) {
//                        manager.cropImage()
                    }
                } else {
                    CircleButton(icon: "arrow.right", prominent: true, isActive: false) {
                        // Export or other action
                    }
                }
            }
            .padding(.horizontal, 10)
            .frame(height: compactSize)
            .ignoresSafeArea()
//            .border(.red)
            
            if manager.selectedDetent == .height(toolSize) && !manager.isCropping {
                switch manager.selectedTool {
                case .crop:
                    HStack {
                        
                    }
                case .colorExtract:
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(manager.extractedColors, id: \.self) { color in
                                ColorPickerButton(color: color, isSelected: manager.backgroundColor == color) {
                                    manager.backgroundColor = color
                                }
                            }
                           
                            
                            Spacer()
                        }
                        .padding(10)
                    }
                    .background(.quinary.opacity(0.25), in: .capsule)
                    .padding(10)
                    .frame(height: 60)
                case .none:
                    HStack {
                        
                    }
                }
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

struct ColorPickerButton: View {
    var color: UIColor
    var size: CGFloat = 50
    var isSelected: Bool = false
    var onTap: () -> Void
    var body: some View {
        Button {
          onTap()
        } label: {
            Circle()
                .fill(Color(color))
              
                .overlay {
                    if isSelected {
                        ZStack {
                            Circle()
                                .fill(.clear)
                                .stroke(Color.white, lineWidth: 2)
                            Image(systemName: "checkmark")
                        }
                    }
                }
        }
        .buttonStyle(.plain)
        .frame(width: size, height: size)
        .scaleEffect(isSelected ? 0.8 : 1)
        .animation(.smooth(duration: 0.4), value: isSelected)
    }
}

struct CircleButton: View {
    var icon: String = ""
    var prominent: Bool = false
    var isActive: Bool
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

// --- CropView definition (must accept namespace and matchedId) ---
//struct CropView: View {
//    let crop: Crop
//    let image: UIImage?
//    let namespace: Namespace.ID
//    let matchedId: String
//    let completion: (UIImage?, Bool) -> Void
//    
//    @State private var localImage: UIImage? = nil
//    
//    var body: some View {
//        if let image = image {
//            // Matched geometry destination image
//            Image(uiImage: image)
//                .resizable()
//                .aspectRatio(contentMode: .fit)
//                .matchedGeometryEffect(id: matchedId, in: namespace)
//                // Additional crop UI and gestures here, omitted for brevity
//                .overlay(
//                    Text("Crop View")
//                        .foregroundColor(.white)
//                        .padding()
//                        .background(Color.black.opacity(0.5))
//                        .cornerRadius(8)
//                        .padding()
//                )
//        } else {
//            Text("No Image to Crop")
//        }
//    }
//}

#Preview {
    ZStack {
    
   
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


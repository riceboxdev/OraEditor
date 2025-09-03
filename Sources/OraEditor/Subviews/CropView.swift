//
//  SwiftUIView.swift
//  Sushi
//
//  Created by Nick Rogers on 9/2/25.
//

import SwiftUI

@available(iOS 16.0.0, *)
struct MainCropView: View {
    @State private var showPicker = false
    @State private var croppedImage: UIImage?

    var body: some View {
        NavigationStack {
            VStack {
                if let croppedImage {
                    Image(uiImage: croppedImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 300, height: 400)
                } else {
                    Text("No Image is Selected")
                }
            }
            .navigationTitle("Crop")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showPicker.toggle()
                    } label : {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.callout)
                    }
                }
            }
            .cropImagePicker(options: [.circle, .square, .rectangle, .custom(.init(width: 200, height: 200))], show: $showPicker, croppedImage: $croppedImage)
        }
    }
}

@available(iOS 16.0.0, *)
#Preview {
    MainCropView()
}

@available(iOS 16.0.0, *)
public enum Crop: Equatable {
    case circle
    case rectangle
    case square
    case custom(CGSize)
    
    public func name() -> String {
        switch self {
        case .circle: return "Circle"
        case .rectangle: return "Rectangle"
        case .square: return "Square"
        case .custom(let cGSize):
            return "Custom \(Int(cGSize.width))x\(Int(cGSize.height))"
        }
    }
    
    public func size() -> CGSize {
        switch self {
        case .circle: return .init(width: 300, height: 300)
        case .rectangle: return .init(width: 300, height: 500)
        case .square: return .init(width: 300, height: 300)
        case .custom(let cGSize): return cGSize
        }
    }
}

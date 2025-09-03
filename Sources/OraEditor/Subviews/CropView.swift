//
//  CropView.swift
//  OraEditor
//
//  Created by Nick Rogers on 8/22/25.
//


import SwiftUI

public struct OraCropView: View {
    public let image: UIImage
    public let aspectRatio: CGFloat? // pass `nil` for freeform crop, or something like 1.0, 16/9, etc.
    
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastScale: CGFloat = 1.0
    @State private var lastOffset: CGSize = .zero
    
    public var body: some View {
        GeometryReader { geo in
            ZStack {
                // Image with drag + zoom
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .scaleEffect(scale)
                    .offset(offset)
                    .gesture(
                        SimultaneousGesture(
                            DragGesture()
                                .onChanged { value in
                                    offset = CGSize(
                                        width: lastOffset.width + value.translation.width,
                                        height: lastOffset.height + value.translation.height
                                    )
                                }
                                .onEnded { _ in
                                    lastOffset = offset
                                },
                            MagnificationGesture()
                                .onChanged { value in
                                    scale = lastScale * value
                                }
                                .onEnded { value in
                                    scale = lastScale * value
                                    lastScale = scale
                                }
                        )
                    )
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                
                // Crop overlay
                Rectangle()
                    .fill(Color.black.opacity(0.5))
                    .mask(
                        CropMask(aspectRatio: aspectRatio, size: geo.size)
                            .fill(style: FillStyle(eoFill: true))
                    )
                    .allowsHitTesting(false)
                
                // Visible crop border
                CropMask(aspectRatio: aspectRatio, size: geo.size)
                    .stroke(Color.white, lineWidth: 2)
            }
        }
        .clipped()
    }
}

struct CropMask: Shape {
    let aspectRatio: CGFloat?
    let size: CGSize
    
    func path(in rect: CGRect) -> Path {
        var path = Path(CGRect(origin: .zero, size: rect.size))
        
        let cropRect: CGRect
        if let ratio = aspectRatio {
            // Fixed aspect ratio
            let cropWidth = min(rect.width, rect.height * ratio)
            let cropHeight = cropWidth / ratio
            cropRect = CGRect(
                x: (rect.width - cropWidth) / 2,
                y: (rect.height - cropHeight) / 2,
                width: cropWidth,
                height: cropHeight
            )
        } else {
            // Square default if freeform
            let side = min(rect.width, rect.height) * 0.8
            cropRect = CGRect(
                x: (rect.width - side) / 2,
                y: (rect.height - side) / 2,
                width: side,
                height: side
            )
        }
        
        path.addRect(cropRect)
        return path
    }
}



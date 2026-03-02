import SwiftUI

#if os(iOS)
import MetalKit
import RealityKit
import UIKit

public final class MetalClearRenderer: NSObject, MTKViewDelegate {
    private let commandQueue: MTLCommandQueue?

    override init() {
        let device = MTLCreateSystemDefaultDevice()
        commandQueue = device?.makeCommandQueue()
        super.init()
    }

    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    public func draw(in view: MTKView) {
        guard
            let drawable = view.currentDrawable,
            let descriptor = view.currentRenderPassDescriptor,
            let queue = commandQueue,
            let commandBuffer = queue.makeCommandBuffer(),
            let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor)
        else {
            return
        }

        encoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}

public struct MetalCanvasView: UIViewRepresentable {
    public init() {}

    public func makeCoordinator() -> MetalClearRenderer {
        MetalClearRenderer()
    }

    public func makeUIView(context: Context) -> MTKView {
        let view = MTKView(frame: .zero, device: MTLCreateSystemDefaultDevice())
        view.enableSetNeedsDisplay = false
        view.isPaused = false
        view.clearColor = MTLClearColor(red: 0.04, green: 0.07, blue: 0.12, alpha: 1.0)
        view.delegate = context.coordinator
        return view
    }

    public func updateUIView(_ uiView: MTKView, context: Context) {}
}

public struct RealityPreviewView: UIViewRepresentable {
    public init() {}

    public func makeUIView(context: Context) -> ARView {
        let view = ARView(frame: .zero, cameraMode: .nonAR, automaticallyConfigureSession: false)

        let anchor = AnchorEntity(world: .zero)
        let sphere = ModelEntity(
            mesh: .generateSphere(radius: 0.08),
            materials: [SimpleMaterial(color: .cyan, roughness: 0.4, isMetallic: true)]
        )
        anchor.addChild(sphere)
        view.scene.addAnchor(anchor)
        return view
    }

    public func updateUIView(_ uiView: ARView, context: Context) {}
}

public struct RendererExperimentView: View {
    @State private var selectedBackend: RendererBackend = .metalKit

    public init() {}

    public var body: some View {
        VStack(spacing: 12) {
            Picker("Backend", selection: $selectedBackend) {
                Text("MetalKit").tag(RendererBackend.metalKit)
                Text("RealityKit").tag(RendererBackend.realityKit)
            }
            .pickerStyle(.segmented)

            Group {
                switch selectedBackend {
                case .metalKit:
                    MetalCanvasView()
                case .realityKit:
                    RealityPreviewView()
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.white.opacity(0.15), lineWidth: 1)
            )
        }
        .padding()
    }
}

#else

public struct RendererExperimentView: View {
    public init() {}

    public var body: some View {
        Text("RendererExperimentView is available on iOS only.")
            .padding()
    }
}

#endif

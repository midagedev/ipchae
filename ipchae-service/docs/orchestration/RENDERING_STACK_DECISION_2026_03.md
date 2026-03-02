# Rendering Stack Decision (MetalKit vs RealityKit)

Date: 2026-03-01  
Scope: iOS/iPadOS first release for IPCHAE editor

## 1. Decision
1. Primary renderer: **MetalKit (MTKView) + custom editor kernel**
2. Secondary/optional layer: RealityKit for preview-oriented or AR-specific features only
3. Do not use RealityKit as the main editable mesh kernel for v1

## 2. Why
IPCHAE core is an interactive creation editor (high-frequency brush updates, transform, undo/redo transactions, predictable geometry ops). We need explicit control over frame pacing, memory, and command scheduling. MetalKit gives that control directly.

## 3. Evidence (Web research)
1. Apple describes MetalKit as the bridge between Metal and app frameworks, and `MTKView` as the preferred drawable/render-loop surface.
2. RealityKit is positioned as a high-level 3D/AR framework (great for immersive scenes, less direct control for low-level custom mesh editing loops).
3. Apple still positions SceneKit as a high-level scene graph; not selected for core editor due lower low-level control than Metal.
4. For tight performance control in graphics apps, Apple points to profiling/optimization with Metal tooling (Instruments + capture workflows).

## 4. Selection Matrix
| Criterion | MetalKit | RealityKit | Decision Impact |
|---|---|---|---|
| Low-level render control | High | Medium/Low | Editor core needs High |
| Brush/mesh kernel customization | High | Medium | Core requirement |
| AR/quick scene composition | Medium | High | Future additive feature |
| Performance tuning knobs | High | Medium | Core requirement |
| Implementation complexity | High | Medium | Accept complexity for control |

## 5. Implementation Plan
1. Spike A (now): minimal `MTKView` render loop and input-to-draw timing capture.
2. Spike B: stroke insertion + undo transaction replay benchmark.
3. Spike C (optional): RealityKit preview path for exported mesh viewer.
4. Decision checkpoint: keep MetalKit as default unless benchmark disproves assumptions.

## 6. Exit Criteria
1. Baseline iPad keeps stable frame pacing in editor stress scenario.
2. Undo/redo replay cost remains within target budget.
3. Memory pressure stays inside phase gate threshold.

## 7. Sources
1. Apple MetalKit overview: [https://developer.apple.com/documentation/metalkit](https://developer.apple.com/documentation/metalkit)
2. Apple MTKView docs: [https://developer.apple.com/documentation/metalkit/mtkview](https://developer.apple.com/documentation/metalkit/mtkview)
3. Apple RealityKit docs: [https://developer.apple.com/documentation/realitykit/](https://developer.apple.com/documentation/realitykit/)
4. Apple SceneKit docs: [https://developer.apple.com/documentation/scenekit/](https://developer.apple.com/documentation/scenekit/)
5. Apple Metal tools & optimization docs: [https://developer.apple.com/documentation/metal/](https://developer.apple.com/documentation/metal/)


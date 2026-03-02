import CoreDomain
import Foundation
import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

public struct StudioSandboxView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @StateObject private var viewModel = StudioEditorViewModel()
    @State private var report: ValidationReport?
    @State private var statusMessage: String = "캔버스에서 바로 그려보세요."
    @State private var showInspectorSheet: Bool = false
    @State private var showExportSheet: Bool = false
    @State private var exportPayload: String = ""

    public init() {}

    public var body: some View {
        let compactUI = horizontalSizeClass != .regular
        NavigationStack {
            GeometryReader { proxy in
                let wideLayout = shouldUseWideLayout(width: proxy.size.width)

                Group {
                    if wideLayout {
                        iPadLayout(canvasSize: proxy.size)
                    } else {
                        iPhoneLayout(canvasSize: proxy.size)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(Color.platformGroupedBackground)
                .toolbar(.hidden, for: .navigationBar)
                .sheet(isPresented: $showInspectorSheet) {
                    NavigationStack {
                        ScrollView {
                            VStack(spacing: 14) {
                                toolPanel(compact: true)
                                slicePanel(compact: true)
                                brushPanel()
                                snapshotPanel()
                            }
                            .padding(16)
                        }
                        .navigationTitle("인스펙터")
                        .platformInlineNavigationTitle()
                        .toolbar {
                            ToolbarItem(placement: .studioTrailingPlacement) {
                                Button("닫기") {
                                    showInspectorSheet = false
                                }
                            }
                        }
                    }
                }
                .sheet(isPresented: $showExportSheet) {
                    NavigationStack {
                        ScrollView {
                            Text(exportPayload)
                                .font(.caption.monospaced())
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(16)
                        }
                        .navigationTitle("내보내기 미리보기")
                        .platformInlineNavigationTitle()
                        .toolbar {
                            ToolbarItem(placement: .studioTrailingPlacement) {
                                Button("닫기") {
                                    showExportSheet = false
                                }
                            }
                        }
                    }
                }
            }
        }
        // Editor canvas usability degrades with accessibility-size Dynamic Type.
        // Keep text scalable, but cap to a practical range for dense editing UI.
        .dynamicTypeSize(.small ... .medium)
        .font(compactUI ? .footnote : .body)
        .environment(\.controlSize, compactUI ? .mini : .small)
    }

    private func shouldUseWideLayout(width: CGFloat) -> Bool {
        _ = width
        return horizontalSizeClass == .regular
    }

    private func iPhoneLayout(canvasSize: CGSize) -> some View {
        immersiveEditorLayout()
    }

    private func iPadLayout(canvasSize: CGSize) -> some View {
        immersiveEditorLayout()
    }

    private func immersiveEditorLayout() -> some View {
        ZStack {
            Color.white

            EditorCanvasView(viewModel: viewModel) { message in
                statusMessage = message
            }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            VStack(spacing: 8) {
                editorTopBar
                canvasMetaBar
                Spacer(minLength: 0)
                statusOverlay
                compactBottomToolbar
                    .fixedSize(horizontal: false, vertical: true)
                    .layoutPriority(1)
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)
            .padding(.bottom, 6)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
    }

    private var editorTopBar: some View {
        HStack(spacing: 6) {
            Button {
                dismiss()
            } label: {
                Label("완료", systemImage: "chevron.backward")
            }
            .buttonStyle(.bordered)

            Spacer(minLength: 0)

            Text("스튜디오")
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Spacer(minLength: 0)

            Button {
                validateDraft()
            } label: {
                Label("검증", systemImage: "checkmark.seal")
            }
            .buttonStyle(.bordered)

            Button {
                viewModel.clear()
                report = nil
                statusMessage = "캔버스 초기화"
            } label: {
                Label("초기화", systemImage: "trash")
            }
            .buttonStyle(.bordered)

            Button {
                exportDraft()
            } label: {
                Label("내보내기", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.borderedProminent)
        }
        .font(.caption)
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.platformSecondaryGroupedBackground)
        )
    }

    private var canvasMetaBar: some View {
        HStack(spacing: 10) {
            Text("로컬 프로젝트")
                .font(.caption.weight(.semibold))
            Text(viewModel.currentViewLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
            if horizontalSizeClass == .regular {
                if viewModel.isAutosavePending {
                    Text("저장 중…")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    Text("저장됨")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Text("스트로크 \(viewModel.strokeCount)")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("studio.strokeCountHeader")
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule())
    }

    private var statusOverlay: some View {
        HStack {
            Text(statusMessage)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule())
    }

    private func canvasSection(height: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Project Local")
                    .font(.headline)
                Spacer()
                Text(viewModel.currentViewLabel)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if viewModel.isAutosavePending {
                    Text("Saving…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Saved")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text("Strokes \(viewModel.strokeCount)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("studio.strokeCountHeader")
            }

            EditorCanvasView(viewModel: viewModel) { message in
                statusMessage = message
            }
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.black.opacity(0.14), lineWidth: 1)
                )

            Text(statusMessage)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.platformSecondaryGroupedBackground)
        )
        .frame(maxWidth: .infinity)
    }

    private var compactBottomToolbar: some View {
        VStack(spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(StudioEditorViewModel.toolOrder, id: \.self) { tool in
                        Button {
                            viewModel.drawTool = tool
                            statusMessage = "\(tool.localizedLabel) 도구로 전환했습니다."
                        } label: {
                            Label(tool.localizedLabel, systemImage: tool.symbolName)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(viewModel.drawTool == tool ? .blue : .gray.opacity(0.5))
                    }
                }
                .padding(.horizontal, 2)
            }

            if horizontalSizeClass == .regular {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        Text("브러시 \(Int(viewModel.brushSize.rounded()))")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)

                        Button("-") {
                            viewModel.brushSize = max(1, viewModel.brushSize - 1)
                            statusMessage = "브러시 크기 \(Int(viewModel.brushSize.rounded()))"
                        }
                        .buttonStyle(.bordered)

                        Button("+") {
                            viewModel.brushSize = min(60, viewModel.brushSize + 1)
                            statusMessage = "브러시 크기 \(Int(viewModel.brushSize.rounded()))"
                        }
                        .buttonStyle(.bordered)

                        ForEach(Array(StudioEditorViewModel.palette.prefix(10)), id: \.self) { hex in
                            Button {
                                viewModel.brushColorHex = hex
                                statusMessage = "색상 \(hex.uppercased())"
                            } label: {
                                Circle()
                                    .fill(Color(hex: hex))
                                    .frame(width: 18, height: 18)
                                    .overlay(
                                        Circle()
                                            .stroke(
                                                viewModel.brushColorHex == hex ? Color.black : Color.clear,
                                                lineWidth: 2
                                            )
                                    )
                            }
                            .buttonStyle(.plain)
                        }

                        Button {
                            showInspectorSheet = true
                        } label: {
                            Label("더보기", systemImage: "slider.horizontal.3")
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.horizontal, 2)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Button {
                        if viewModel.inputMode == .draw {
                            viewModel.inputMode = .pan
                            statusMessage = "선택/이동 입력 모드"
                        } else {
                            viewModel.inputMode = .draw
                            statusMessage = "그리기 입력 모드"
                        }
                    } label: {
                        Label(
                            viewModel.inputMode == .draw ? "모드: 그리기" : "모드: 선택",
                            systemImage: viewModel.inputMode == .draw ? "pencil.tip" : "hand.tap"
                        )
                    }
                    .buttonStyle(.bordered)

                    Menu("뷰: \(viewModel.currentViewLabel)") {
                        ForEach(StudioEditorViewModel.viewOrder, id: \.self) { id in
                            Button(id.localizedLabel) {
                                viewModel.applyViewPreset(id)
                                statusMessage = "\(id.localizedLabel) 뷰"
                            }
                        }
                    }
                    .buttonStyle(.bordered)

                    Menu("슬라이스: \(viewModel.activeSliceAxis.rawValue.uppercased())") {
                        Button("X") {
                            viewModel.updateActiveSliceAxis(.x)
                            statusMessage = "슬라이스 축: X"
                        }
                        Button("Y") {
                            viewModel.updateActiveSliceAxis(.y)
                            statusMessage = "슬라이스 축: Y"
                        }
                        Button("Z") {
                            viewModel.updateActiveSliceAxis(.z)
                            statusMessage = "슬라이스 축: Z"
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(!viewModel.sliceEnabled || viewModel.activeSliceLayer == nil)

                    Button {
                        viewModel.stabilizerEnabled.toggle()
                        statusMessage = viewModel.stabilizerEnabled ? "선 보정 켜짐" : "선 보정 꺼짐"
                    } label: {
                        Label(
                            viewModel.stabilizerEnabled ? "보정: 켬" : "보정: 끔",
                            systemImage: viewModel.stabilizerEnabled ? "wand.and.stars" : "wand.and.stars.inverse"
                        )
                    }
                    .buttonStyle(.bordered)

                    Menu("보정 모드: \(viewModel.stabilizerMode.localizedLabel)") {
                        Button("실시간") {
                            viewModel.stabilizerMode = .realtime
                            statusMessage = "보정 모드: 실시간"
                        }
                        Button("사후") {
                            viewModel.stabilizerMode = .after
                            statusMessage = "보정 모드: 사후"
                        }
                        Divider()
                        Button("강도 -") {
                            viewModel.stabilizerStrength = max(0, viewModel.stabilizerStrength - 0.05)
                            statusMessage = String(format: "보정 강도 %.2f", viewModel.stabilizerStrength)
                        }
                        Button("강도 +") {
                            viewModel.stabilizerStrength = min(1, viewModel.stabilizerStrength + 0.05)
                            statusMessage = String(format: "보정 강도 %.2f", viewModel.stabilizerStrength)
                        }
                    }
                    .buttonStyle(.bordered)

                    Button {
                        viewModel.stylusPalmRejectionEnabled.toggle()
                        statusMessage = viewModel.stylusPalmRejectionEnabled ? "Pencil 전용 그리기 켜짐" : "Pencil 전용 그리기 꺼짐"
                    } label: {
                        Label(
                            viewModel.stylusPalmRejectionEnabled ? "Palm Rejection: 켬" : "Palm Rejection: 끔",
                            systemImage: viewModel.stylusPalmRejectionEnabled ? "pencil.and.scribble" : "hand.draw"
                        )
                    }
                    .buttonStyle(.bordered)

                    Button {
                        viewModel.undo()
                        statusMessage = "되돌리기 완료"
                    } label: {
                        Label("되돌리기", systemImage: "arrow.uturn.backward")
                    }
                    .buttonStyle(.bordered)

                    Button {
                        viewModel.redo()
                        statusMessage = "다시하기 완료"
                    } label: {
                        Label("다시하기", systemImage: "arrow.uturn.forward")
                    }
                    .buttonStyle(.bordered)

                    Button {
                        showInspectorSheet = true
                    } label: {
                        Label("인스펙터", systemImage: "sidebar.right")
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("studio.inspectorButton")
                }
                .padding(.horizontal, 2)
            }
        }
        .padding(6)
        .font(.caption2)
        .environment(\.controlSize, .mini)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func toolPanel(compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("도구")
                .font(.headline)

            Text("뷰")
                .font(.subheadline.weight(.semibold))
            WrappingRow(items: StudioEditorViewModel.viewOrder.map(\.rawValue)) { item in
                let id = ViewID(rawValue: item) ?? .front
                Button(id.localizedLabel) {
                    viewModel.applyViewPreset(id)
                    statusMessage = "\(id.localizedLabel) 뷰"
                }
                .buttonStyle(.bordered)
                .tint(viewModel.activeView == id ? .blue : .gray.opacity(0.5))
            }

            Picker(
                "슬라이스 축",
                selection: Binding(
                    get: { viewModel.activeSliceAxis },
                    set: { axis in
                        viewModel.updateActiveSliceAxis(axis)
                        statusMessage = "슬라이스 축: \(axis.rawValue.uppercased())"
                    }
                )
            ) {
                Text("X").tag(SliceAxis.x)
                Text("Y").tag(SliceAxis.y)
                Text("Z").tag(SliceAxis.z)
            }
            .pickerStyle(.segmented)
            .disabled(!viewModel.sliceEnabled || viewModel.activeSliceLayer == nil)

            Text("입력")
                .font(.subheadline.weight(.semibold))
            HStack {
                Button("그리기") {
                    viewModel.inputMode = .draw
                    statusMessage = "그리기 입력 모드"
                }
                .buttonStyle(.bordered)
                .tint(viewModel.inputMode == .draw ? .blue : .gray.opacity(0.5))

                Button("선택/이동") {
                    viewModel.inputMode = .pan
                    statusMessage = "선택/이동 입력 모드"
                }
                .buttonStyle(.bordered)
                .tint(viewModel.inputMode == .pan ? .blue : .gray.opacity(0.5))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("제스처")
                    .font(.subheadline.weight(.semibold))
                Toggle("두 손가락 탭 되돌리기", isOn: $viewModel.undoByTwoFingerTapEnabled)
                Toggle("세 손가락 탭 다시하기", isOn: $viewModel.redoByThreeFingerTapEnabled)
                Toggle("빠른 스포이드 (길게 누르기)", isOn: $viewModel.quickEyedropperEnabled)
                HStack(spacing: 8) {
                    Text(String(format: "스포이드 지연 %.2fs", viewModel.quickEyedropperDelay))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Slider(value: $viewModel.quickEyedropperDelay, in: 0.1...2.0, step: 0.05)
                }
                .disabled(!viewModel.quickEyedropperEnabled)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("펜 보정")
                    .font(.subheadline.weight(.semibold))
                Toggle("선 보정", isOn: $viewModel.stabilizerEnabled)
                Picker("보정 모드", selection: $viewModel.stabilizerMode) {
                    Text("실시간").tag(StabilizerMode.realtime)
                    Text("사후").tag(StabilizerMode.after)
                }
                .pickerStyle(.segmented)
                .disabled(!viewModel.stabilizerEnabled)
                HStack(spacing: 8) {
                    Text(String(format: "보정 강도 %.2f", viewModel.stabilizerStrength))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Slider(value: $viewModel.stabilizerStrength, in: 0...1, step: 0.01)
                }
                .disabled(!viewModel.stabilizerEnabled)
                Toggle("Stylus Palm Rejection (Pencil 전용 그리기)", isOn: $viewModel.stylusPalmRejectionEnabled)
                    .font(.caption)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("카메라")
                    .font(.subheadline.weight(.semibold))
                HStack {
                    Button("확대 +") {
                        viewModel.zoomMain(by: 1.12)
                        statusMessage = "메인 카메라 확대"
                    }
                    .buttonStyle(.bordered)

                    Button("축소 -") {
                        viewModel.zoomMain(by: 0.89)
                        statusMessage = "메인 카메라 축소"
                    }
                    .buttonStyle(.bordered)
                }

                HStack {
                    Button("카메라 리셋") {
                        viewModel.resetMainCamera()
                        statusMessage = "메인 카메라 리셋"
                    }
                    .buttonStyle(.bordered)

                    Button("PIP 뷰 적용") {
                        viewModel.applyPIPCameraToMain()
                        statusMessage = "PIP 카메라를 메인에 적용"
                    }
                    .buttonStyle(.bordered)
                }

                Toggle("PIP 표시", isOn: $viewModel.showPIP)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("선택")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text("\(viewModel.selectedCount)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Toggle("다중 선택", isOn: $viewModel.multiSelectEnabled)

                HStack {
                    Button("마지막 선택") {
                        viewModel.selectLastStroke()
                        statusMessage = "마지막 스트로크 선택"
                    }
                    .buttonStyle(.bordered)

                    Button("전체 선택") {
                        viewModel.selectAllStrokes()
                        statusMessage = "전체 선택"
                    }
                    .buttonStyle(.bordered)
                }

                HStack {
                    Button("그룹 선택") {
                        viewModel.selectStrokeGroup()
                        statusMessage = "그룹 선택"
                    }
                    .buttonStyle(.bordered)

                    Button("그룹화") {
                        viewModel.groupSelected()
                        statusMessage = "선택 그룹화"
                    }
                    .buttonStyle(.bordered)

                    Button("그룹 해제") {
                        viewModel.ungroupSelected()
                        statusMessage = "선택 그룹 해제"
                    }
                    .buttonStyle(.bordered)
                }

                HStack {
                    Button("복제") {
                        viewModel.duplicateSelected()
                        statusMessage = "선택 복제"
                    }
                    .buttonStyle(.bordered)

                    Button("삭제") {
                        viewModel.deleteSelected()
                        statusMessage = "선택 삭제"
                    }
                    .buttonStyle(.bordered)
                }

                HStack {
                    Button("복사") {
                        viewModel.copySelected()
                        statusMessage = "선택 복사"
                    }
                    .buttonStyle(.bordered)

                    Button("잘라내기") {
                        viewModel.cutSelected()
                        statusMessage = "선택 잘라내기"
                    }
                    .buttonStyle(.bordered)

                    Button("붙여넣기") {
                        viewModel.pasteCopied()
                        statusMessage = "붙여넣기"
                    }
                    .buttonStyle(.bordered)
                }

                HStack {
                    Button("X+ 이동") {
                        viewModel.nudgeSelected(deltaU: 0.02, deltaV: 0)
                        statusMessage = "선택 이동 +X"
                    }
                    .buttonStyle(.bordered)

                    Button("선택 해제") {
                        viewModel.clearSelection()
                        statusMessage = "선택 해제"
                    }
                    .buttonStyle(.bordered)
                }

                HStack {
                    Button("확대 +") {
                        viewModel.scaleSelected(by: 1.08)
                        statusMessage = "선택 확대"
                    }
                    .buttonStyle(.bordered)

                    Button("축소 -") {
                        viewModel.scaleSelected(by: 0.92)
                        statusMessage = "선택 축소"
                    }
                    .buttonStyle(.bordered)
                }

                HStack {
                    Button("회전 +15") {
                        viewModel.rotateSelected(degrees: 15)
                        statusMessage = "선택 회전 +15°"
                    }
                    .buttonStyle(.bordered)

                    Button("회전 -15") {
                        viewModel.rotateSelected(degrees: -15)
                        statusMessage = "선택 회전 -15°"
                    }
                    .buttonStyle(.bordered)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("변형")
                        .font(.subheadline.weight(.semibold))

                    Picker("피벗", selection: $viewModel.transformPivotMode) {
                        Text("객체").tag(PivotMode.object)
                        Text("선택").tag(PivotMode.selection)
                        Text("월드").tag(PivotMode.world)
                    }
                    .pickerStyle(.segmented)

                    Toggle("그리드 스냅", isOn: $viewModel.gridSnapEnabled)

                    HStack {
                        Text("그리드 간격 \(String(format: "%.3f", viewModel.gridSnapStep))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("-") {
                            viewModel.adjustGridSnapStep(by: -0.01)
                        }
                        .buttonStyle(.bordered)
                        Button("+") {
                            viewModel.adjustGridSnapStep(by: 0.01)
                        }
                        .buttonStyle(.bordered)
                    }

                    Toggle("각도 스냅", isOn: $viewModel.angleSnapEnabled)

                    HStack {
                        Text("각도 간격 \(Int(viewModel.angleSnapDegrees))°")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("-") {
                            viewModel.adjustAngleSnapDegrees(by: -5)
                        }
                        .buttonStyle(.bordered)
                        Button("+") {
                            viewModel.adjustAngleSnapDegrees(by: 5)
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }

            if !compact {
                HStack {
                    Button("되돌리기") {
                        viewModel.undo()
                        statusMessage = "되돌리기 완료"
                    }
                    .buttonStyle(.bordered)
                    Button("다시하기") {
                        viewModel.redo()
                        statusMessage = "다시하기 완료"
                    }
                    .buttonStyle(.bordered)
                    Button("초기화") {
                        viewModel.clear()
                        report = nil
                        statusMessage = "캔버스 초기화"
                    }
                    .buttonStyle(.bordered)
                }
            }

            Toggle("대칭 그리기", isOn: $viewModel.mirrorDraw)
                .onChange(of: viewModel.mirrorDraw) { _, value in
                    statusMessage = value ? "대칭 드로잉 ON" : "대칭 드로잉 OFF"
                }
            Toggle("자동 채우기", isOn: $viewModel.autoFillClosedStroke)
            Toggle("스무스 메쉬", isOn: $viewModel.smoothMeshView)
        }
        .padding(12)
        .background(cardBackground)
    }

    private func slicePanel(compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("슬라이스")
                    .font(.headline)
                Spacer()
                Toggle("활성화", isOn: $viewModel.sliceEnabled)
                    .labelsHidden()
            }

            HStack {
                Button("+ 레이어") {
                    viewModel.addSliceLayer()
                }
                .buttonStyle(.bordered)
                Button("- 레이어") {
                    viewModel.removeActiveSliceLayer()
                }
                .buttonStyle(.bordered)
                Spacer()
            }

            if let activeLayer = viewModel.activeSliceLayer {
                Picker(
                    "축",
                    selection: Binding(
                        get: { viewModel.activeSliceAxis },
                        set: { axis in
                            viewModel.updateActiveSliceAxis(axis)
                            statusMessage = "슬라이스 축 \(axis.rawValue.uppercased())"
                        }
                    )
                ) {
                    Text("X").tag(SliceAxis.x)
                    Text("Y").tag(SliceAxis.y)
                    Text("Z").tag(SliceAxis.z)
                }
                .pickerStyle(.segmented)

                HStack(spacing: 8) {
                    Button(activeLayer.visible ? "표시" : "숨김") {
                        viewModel.toggleActiveSliceVisibility()
                        statusMessage = viewModel.isActiveSliceVisible ? "Slice 레이어 표시" : "Slice 레이어 숨김"
                    }
                    .buttonStyle(.bordered)

                    Button(activeLayer.locked ? "잠금 해제" : "잠금") {
                        viewModel.toggleActiveSliceLock()
                        statusMessage = viewModel.isActiveSliceLocked ? "Slice 레이어 잠금" : "Slice 레이어 잠금 해제"
                    }
                    .buttonStyle(.bordered)

                    Spacer()
                }

                HStack {
                    Text(activeLayer.name)
                        .font(.subheadline)
                    Spacer()
                    Text(String(format: "%.2f", activeLayer.depth))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Slider(
                    value: Binding(
                        get: { viewModel.activeSliceDepth },
                        set: { viewModel.setActiveSliceDepth($0) }
                    ),
                    in: -6...6,
                    step: 0.02
                )
            } else {
                Text("활성 Slice 레이어가 없습니다.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !compact {
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(viewModel.sliceLayers, id: \.id) { layer in
                            HStack(spacing: 6) {
                                Button {
                                    viewModel.selectSliceLayer(id: layer.id)
                                } label: {
                                    HStack {
                                        Circle()
                                            .fill(Color(hex: layer.colorHex))
                                            .frame(width: 10, height: 10)
                                        Text(layer.name)
                                            .font(.caption)
                                            .lineLimit(1)
                                        Spacer()
                                        Text("\(layer.axis.rawValue.uppercased()) \(layer.depth, specifier: "%.2f")")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(.vertical, 4)
                                }
                                .buttonStyle(.plain)

                                Button(layer.visible ? "숨김" : "표시") {
                                    viewModel.toggleSliceLayerVisibility(id: layer.id)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.mini)

                                Button(layer.locked ? "잠금 해제" : "잠금") {
                                    viewModel.toggleSliceLayerLock(id: layer.id)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.mini)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(viewModel.activeSliceLayerID == layer.id ? Color.accentColor.opacity(0.14) : Color.clear)
                            )
                        }
                    }
                }
                .frame(maxHeight: 120)
            }
        }
        .padding(12)
        .background(cardBackground)
    }

    private func brushPanel() -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("브러시")
                .font(.headline)

            Text("크기 \(Int(viewModel.brushSize.rounded()))")
                .font(.subheadline)
            Slider(value: $viewModel.brushSize, in: 1...60, step: 1)

            Text("강도 \(Int((viewModel.brushStrength * 100).rounded()))%")
                .font(.subheadline)
            Slider(value: $viewModel.brushStrength, in: 0.05...1, step: 0.01)

            Text("색상")
                .font(.subheadline.weight(.semibold))
            WrappingRow(items: StudioEditorViewModel.palette) { hex in
                Button {
                    viewModel.brushColorHex = hex
                    statusMessage = "색상 \(hex.uppercased())"
                } label: {
                    Circle()
                        .fill(Color(hex: hex))
                        .frame(width: 28, height: 28)
                        .overlay(
                            Circle()
                                .stroke(
                                    viewModel.brushColorHex == hex ? Color.primary : .clear,
                                    lineWidth: 2
                                )
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(cardBackground)
    }

    private func snapshotPanel() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("스냅샷")
                .font(.headline)
            Text("스트로크: \(viewModel.strokeCount)")
                .accessibilityIdentifier("studio.snapshot.strokes")
            Text("도트: \(viewModel.dotCount)")
            Text(String(format: "평균 반경: %.3f", viewModel.averageRadius))
            if let savedAt = viewModel.lastSavedAt {
                Text("저장 시각: \(savedAt.formatted(date: .omitted, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack {
                Button("검증") {
                    validateDraft()
                }
                .buttonStyle(.bordered)

                Button("내보내기") {
                    exportDraft()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(12)
        .background(cardBackground)
    }

    @ViewBuilder
    private var reportPanel: some View {
        if let report {
            VStack(alignment: .leading, spacing: 8) {
                Text("검증 결과")
                    .font(.headline)
                Text(report.exportAllowed ? "내보내기 가능" : "내보내기 차단")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(report.exportAllowed ? .green : .red)
                ForEach(Array(report.all.enumerated()), id: \.offset) { _, issue in
                    Text("• [\(issue.severity.rawValue)] \(issue.message)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(12)
            .background(cardBackground)
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color.platformTertiaryGroupedBackground)
    }

    private func validateDraft() {
        report = ValidationService.validateDraftSummary(viewModel.makeSummary())
        if report?.exportAllowed == true {
            statusMessage = "검증 통과"
        } else {
            statusMessage = "검증 실패: 이슈를 확인해 주세요."
        }
    }

    private func exportDraft() {
        let latest = report ?? ValidationService.validateDraftSummary(viewModel.makeSummary())
        report = latest
        guard latest.exportAllowed else {
            statusMessage = "내보내기 차단: 검증 이슈를 먼저 해결하세요."
            return
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        do {
            let data = try encoder.encode(viewModel.makeSummary())
            exportPayload = String(decoding: data, as: UTF8.self)
            showExportSheet = true
            statusMessage = "내보내기 데이터 생성 완료"
        } catch {
            statusMessage = "내보내기 데이터 생성 실패"
        }
    }
}

private struct EditorCanvasView: View {
    @ObservedObject var viewModel: StudioEditorViewModel
    let onStatusMessage: (String) -> Void

    var body: some View {
        GeometryReader { proxy in
            let canvasSize = proxy.size
            let pipTopInset = max(CGFloat(84), proxy.safeAreaInsets.top + 56)
            let pipSize = CGSize(
                width: min(220, canvasSize.width * 0.42),
                height: min(160, canvasSize.height * 0.3)
            )
            ZStack {
                Canvas { context, size in
                    renderScene(
                        context: context,
                        size: size,
                        camera: viewModel.mainCameraState,
                        includeActiveStroke: true,
                        includeGrid: true
                    )
                }
                .accessibilityIdentifier("studio.canvas")
                .contentShape(Rectangle())
                .modifier(CanvasDragInputModifier(viewModel: viewModel, canvasSize: canvasSize))
                .background(
                    CanvasMultiTouchGestureBridge(
                        stylusOnlyDrawing: viewModel.stylusPalmRejectionEnabled && viewModel.inputMode == .draw,
                        twoFingerUndoEnabled: viewModel.undoByTwoFingerTapEnabled,
                        threeFingerRedoEnabled: viewModel.redoByThreeFingerTapEnabled,
                        quickEyedropperEnabled: viewModel.quickEyedropperEnabled,
                        quickEyedropperDelay: viewModel.quickEyedropperDelay,
                        onPanChanged: { location, translation in
                            viewModel.handleDragChanged(
                                location,
                                translation: translation,
                                canvasSize: canvasSize
                            )
                        },
                        onPanEnded: { location, translation in
                            viewModel.handleDragEnded(
                                location: location,
                                translation: translation,
                                canvasSize: canvasSize
                            )
                        },
                        onTwoFingerTap: {
                            if viewModel.inputMode == .draw, viewModel.cancelActiveStrokeIfNeeded() {
                                onStatusMessage("그리기 취소")
                            } else if viewModel.undo() {
                                onStatusMessage("되돌리기 완료")
                            }
                        },
                        onThreeFingerTap: {
                            if viewModel.redo() {
                                onStatusMessage("다시하기 완료")
                            }
                        },
                        onQuickEyedropper: { location in
                            guard viewModel.inputMode == .draw else { return }
                            guard !viewModel.isStrokeInProgress else { return }
                            if let picked = viewModel.pickBrushColorFromNearestStroke(
                                at: location,
                                in: canvasSize
                            ) {
                                onStatusMessage("스포이드 색상 \(picked.uppercased())")
                            } else {
                                onStatusMessage("선 근처를 길게 눌러 색상을 선택하세요.")
                            }
                        }
                    )
                )

                if viewModel.inputMode == .pan {
                    Text("이동 모드")
                        .font(.caption.weight(.semibold))
                        .padding(8)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(.top, 10)
                        .frame(maxHeight: .infinity, alignment: .top)
                }

                if viewModel.inputMode == .draw, !viewModel.canDrawOnActiveSlice {
                    Text(viewModel.isActiveSliceLocked ? "슬라이스 잠금" : "슬라이스 숨김")
                        .font(.caption.weight(.semibold))
                        .padding(8)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(.top, 10)
                        .frame(maxHeight: .infinity, alignment: .top)
                }

                if viewModel.showPIP {
                    PIPPreviewView(viewModel: viewModel) { deltaX, deltaY in
                        viewModel.panPIP(
                            deltaX: Double(deltaX),
                            deltaY: Double(deltaY),
                            pipSize: pipSize
                        )
                    }
                        .frame(width: pipSize.width, height: pipSize.height)
                        .padding(.top, pipTopInset)
                        .padding(.trailing, 12)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        .offset(viewModel.pipOffset)
                }
            }
            .onAppear {
                viewModel.updateCanvasSize(
                    canvasSize,
                    pipTopInset: pipTopInset,
                    pipBottomInset: 12
                )
            }
            .onChange(of: canvasSize) { _, newValue in
                viewModel.updateCanvasSize(
                    newValue,
                    pipTopInset: pipTopInset,
                    pipBottomInset: 12
                )
            }
        }
    }

    private func renderScene(
        context: GraphicsContext,
        size: CGSize,
        camera: EditorCameraState,
        includeActiveStroke: Bool,
        includeGrid: Bool
    ) {
        let background = Path(CGRect(origin: .zero, size: size))
        context.fill(background, with: .color(.white))

        if includeGrid {
            drawGuides(context: context, size: size)
        }
        drawAxisOverlay(context: context, size: size, camera: camera)
        drawSliceGuide(context: context, size: size, camera: camera)

        for (index, stroke) in viewModel.strokes.enumerated() {
            let points = viewModel.projectedPoints(stroke: stroke, strokeOrdinal: index, in: size, camera: camera)
            guard points.count > 1 else { continue }
            var path = Path()
            path.move(to: points[0])
            for point in points.dropFirst() {
                path.addLine(to: point)
            }
            let heightFX = viewModel.heightVisualIntensity(for: stroke)
            let baseOpacity = 0.86 + (0.12 * heightFX)
            context.stroke(
                path,
                with: .color(Color(hex: stroke.colorHex).opacity(baseOpacity)),
                style: StrokeStyle(lineWidth: stroke.lineWidth, lineCap: .round, lineJoin: .round)
            )
            if heightFX > 0.01 {
                context.stroke(
                    path,
                    with: .color(.black.opacity(0.03 + (0.09 * heightFX))),
                    style: StrokeStyle(
                        lineWidth: stroke.lineWidth + (0.8 * heightFX),
                        lineCap: .round,
                        lineJoin: .round
                    )
                )
                context.stroke(
                    path,
                    with: .color(.white.opacity(0.05 + (0.16 * heightFX))),
                    style: StrokeStyle(
                        lineWidth: max(0.9, (stroke.lineWidth * 0.52)),
                        lineCap: .round,
                        lineJoin: .round
                    )
                )
            }

            if viewModel.selectedStrokeIDs.contains(stroke.id) {
                context.stroke(
                    path,
                    with: .color(.yellow.opacity(0.95)),
                    style: StrokeStyle(lineWidth: stroke.lineWidth + 2, lineCap: .round, lineJoin: .round)
                )
            }
        }

        if includeActiveStroke, !viewModel.activeStrokePoints.isEmpty {
            let points = viewModel.projectedActiveStrokePoints(in: size, camera: camera)
            if points.count > 1 {
                var active = Path()
                active.move(to: points[0])
                for point in points.dropFirst() {
                    active.addLine(to: point)
                }
                context.stroke(
                    active,
                    with: .color(Color(hex: viewModel.brushColorHex).opacity(0.9)),
                    style: StrokeStyle(
                        lineWidth: viewModel.brushSize,
                        lineCap: .round,
                        lineJoin: .round
                    )
                )
            }
        }
    }

    private func drawGuides(context: GraphicsContext, size: CGSize) {
        var grid = Path()
        let rows = 14
        let cols = 14
        for row in 1..<rows {
            let y = (size.height / CGFloat(rows)) * CGFloat(row)
            grid.move(to: CGPoint(x: 0, y: y))
            grid.addLine(to: CGPoint(x: size.width, y: y))
        }
        for col in 1..<cols {
            let x = (size.width / CGFloat(cols)) * CGFloat(col)
            grid.move(to: CGPoint(x: x, y: 0))
            grid.addLine(to: CGPoint(x: x, y: size.height))
        }
        context.stroke(
            grid,
            with: .color(Color.black.opacity(0.12)),
            style: StrokeStyle(lineWidth: 0.7)
        )
    }

    private func drawAxisOverlay(context: GraphicsContext, size: CGSize, camera: EditorCameraState) {
        let origin = viewModel.projectScenePoint(x: 0, y: 0, z: 0, in: size, camera: camera)
        let xPositive = viewModel.projectScenePoint(x: 1, y: 0, z: 0, in: size, camera: camera)
        let yPositive = viewModel.projectScenePoint(x: 0, y: 1, z: 0, in: size, camera: camera)
        let zPositive = viewModel.projectScenePoint(x: 0, y: 0, z: 1, in: size, camera: camera)

        let xNegative = viewModel.projectScenePoint(x: -1, y: 0, z: 0, in: size, camera: camera)
        let yNegative = viewModel.projectScenePoint(x: 0, y: -1, z: 0, in: size, camera: camera)
        let zNegative = viewModel.projectScenePoint(x: 0, y: 0, z: -1, in: size, camera: camera)

        func line(_ from: CGPoint, _ to: CGPoint, color: Color, width: CGFloat, opacity: Double = 1) {
            var path = Path()
            path.move(to: from)
            path.addLine(to: to)
            context.stroke(path, with: .color(color.opacity(opacity)), style: StrokeStyle(lineWidth: width, lineCap: .round))
        }

        line(origin, xNegative, color: .red, width: 1, opacity: 0.35)
        line(origin, yNegative, color: .green, width: 1, opacity: 0.35)
        line(origin, zNegative, color: .blue, width: 1, opacity: 0.35)

        line(origin, xPositive, color: .red, width: 2)
        line(origin, yPositive, color: .green, width: 2)
        line(origin, zPositive, color: .blue, width: 2)

        context.draw(Text("X").font(.caption2.weight(.bold)).foregroundStyle(.red), at: xPositive)
        context.draw(Text("Y").font(.caption2.weight(.bold)).foregroundStyle(.green), at: yPositive)
        context.draw(Text("Z").font(.caption2.weight(.bold)).foregroundStyle(.blue), at: zPositive)

        context.fill(Path(ellipseIn: CGRect(x: origin.x - 2.5, y: origin.y - 2.5, width: 5, height: 5)), with: .color(.black.opacity(0.5)))
    }

    private func drawSliceGuide(context: GraphicsContext, size: CGSize, camera: EditorCameraState) {
        guard viewModel.shouldShowSliceGuide else { return }
        let depth = max(-1, min(1, viewModel.activeSliceDepth / 6))
        let axis = viewModel.activeSliceAxis
        var guide = Path()
        switch axis {
        case .x:
            let a = viewModel.projectScenePoint(x: depth, y: -1, z: -1, in: size, camera: camera)
            let b = viewModel.projectScenePoint(x: depth, y: 1, z: 1, in: size, camera: camera)
            guide.move(to: a)
            guide.addLine(to: b)
        case .y:
            let a = viewModel.projectScenePoint(x: -1, y: depth, z: -1, in: size, camera: camera)
            let b = viewModel.projectScenePoint(x: 1, y: depth, z: 1, in: size, camera: camera)
            guide.move(to: a)
            guide.addLine(to: b)
        case .z:
            let a = viewModel.projectScenePoint(x: -1, y: -1, z: depth, in: size, camera: camera)
            let b = viewModel.projectScenePoint(x: 1, y: 1, z: depth, in: size, camera: camera)
            guide.move(to: a)
            guide.addLine(to: b)
        }
        context.stroke(
            guide,
            with: .color(.cyan.opacity(0.7)),
            style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
        )
    }
}

private struct CanvasDragInputModifier: ViewModifier {
    @ObservedObject var viewModel: StudioEditorViewModel
    let canvasSize: CGSize

    func body(content: Content) -> some View {
        #if os(iOS)
        content
        #else
        content.gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .local)
                .onChanged { value in
                    viewModel.handleDragChanged(
                        value.location,
                        translation: value.translation,
                        canvasSize: canvasSize
                    )
                }
                .onEnded { value in
                    viewModel.handleDragEnded(
                        location: value.location,
                        translation: value.translation,
                        canvasSize: canvasSize
                    )
                }
        )
        #endif
    }
}

private struct PIPPreviewView: View {
    @ObservedObject var viewModel: StudioEditorViewModel
    let onMove: (CGFloat, CGFloat) -> Void
    @State private var lastDragTranslation: CGSize = .zero
    @State private var lastMoveTranslation: CGSize = .zero

    var body: some View {
        ZStack(alignment: .topLeading) {
            Canvas { context, size in
                let background = Path(CGRect(origin: .zero, size: size))
                context.fill(background, with: .color(.white))
                drawPIPGuides(context: context, size: size, camera: viewModel.pipCameraState)
                drawPIPAxisOverlay(context: context, size: size, camera: viewModel.pipCameraState)

                var frame = Path()
                frame.addRect(CGRect(origin: .zero, size: size).insetBy(dx: 1, dy: 1))
                context.stroke(frame, with: .color(.black.opacity(0.15)), lineWidth: 1)

                for (index, stroke) in viewModel.strokes.enumerated() {
                    let points = viewModel.projectedPoints(
                        stroke: stroke,
                        strokeOrdinal: index,
                        in: size,
                        camera: viewModel.pipCameraState
                    )
                    guard points.count > 1 else { continue }
                    var path = Path()
                    path.move(to: points[0])
                    for point in points.dropFirst() {
                        path.addLine(to: point)
                    }
                    context.stroke(
                        path,
                        with: .color(Color(hex: stroke.colorHex)),
                        style: StrokeStyle(lineWidth: max(1.2, stroke.lineWidth * 0.45), lineCap: .round, lineJoin: .round)
                    )
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onChanged { value in
                        let deltaX = value.translation.width - lastDragTranslation.width
                        let deltaY = value.translation.height - lastDragTranslation.height
                        viewModel.orbitPIP(deltaYaw: Double(deltaX) * 0.7, deltaPitch: Double(deltaY) * 0.6)
                        lastDragTranslation = value.translation
                    }
                    .onEnded { _ in
                        lastDragTranslation = .zero
                    }
            )
            .accessibilityIdentifier("studio.pip")

            HStack(spacing: 6) {
                Text("이동")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.95))
                VStack(alignment: .leading, spacing: 2) {
                    Text("PIP")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white.opacity(0.9))
                    Text(viewModel.pipCameraLabel)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
            .padding(8)
            .background(Color.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .padding(8)
            .accessibilityIdentifier("studio.pipMoveHandle")
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onChanged { value in
                        let deltaX = value.translation.width - lastMoveTranslation.width
                        let deltaY = value.translation.height - lastMoveTranslation.height
                        onMove(deltaX, deltaY)
                        lastMoveTranslation = value.translation
                    }
                    .onEnded { _ in
                        lastMoveTranslation = .zero
                    }
            )

            VStack {
                Spacer()
                HStack(spacing: 6) {
                    Button("+") {
                        viewModel.zoomPIP(by: 1.12)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.mini)

                    Button("-") {
                        viewModel.zoomPIP(by: 0.89)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.mini)

                    Button("리셋") {
                        viewModel.resetPIPCamera()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.black.opacity(0.22), lineWidth: 1)
        )
    }

    private func drawPIPGuides(context: GraphicsContext, size: CGSize, camera: EditorCameraState) {
        let planeAxis = planeAxisForCurrentView()
        let depth: Double = {
            guard viewModel.sliceEnabled, viewModel.activeSliceAxis == planeAxis else { return 0 }
            return max(-1, min(1, viewModel.activeSliceDepth / 6))
        }()
        let steps = 10

        func project(_ x: Double, _ y: Double, _ z: Double) -> CGPoint {
            viewModel.projectScenePoint(x: x, y: y, z: z, in: size, camera: camera)
        }

        func stroke(_ from: CGPoint, _ to: CGPoint, color: Color, width: CGFloat) {
            var line = Path()
            line.move(to: from)
            line.addLine(to: to)
            context.stroke(line, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round))
        }

        for index in -steps...steps {
            let t = Double(index) / Double(steps)
            let major = index == 0 || (index % 5 == 0)
            let color = Color.black.opacity(major ? 0.22 : 0.1)
            let width: CGFloat = major ? 0.9 : 0.5

            let firstFrom: CGPoint
            let firstTo: CGPoint
            let secondFrom: CGPoint
            let secondTo: CGPoint

            switch planeAxis {
            case .z:
                firstFrom = project(-1, t, depth)
                firstTo = project(1, t, depth)
                secondFrom = project(t, -1, depth)
                secondTo = project(t, 1, depth)
            case .x:
                firstFrom = project(depth, -1, t)
                firstTo = project(depth, 1, t)
                secondFrom = project(depth, t, -1)
                secondTo = project(depth, t, 1)
            case .y:
                firstFrom = project(-1, depth, t)
                firstTo = project(1, depth, t)
                secondFrom = project(t, depth, -1)
                secondTo = project(t, depth, 1)
            }

            stroke(firstFrom, firstTo, color: color, width: width)
            stroke(secondFrom, secondTo, color: color, width: width)
        }
    }

    private func planeAxisForCurrentView() -> SliceAxis {
        switch viewModel.activeView {
        case .front, .back:
            return .z
        case .left, .right:
            return .x
        case .top:
            return .y
        }
    }

    private func drawPIPAxisOverlay(context: GraphicsContext, size: CGSize, camera: EditorCameraState) {
        let origin = viewModel.projectScenePoint(x: 0, y: 0, z: 0, in: size, camera: camera)
        let xPositive = viewModel.projectScenePoint(x: 1, y: 0, z: 0, in: size, camera: camera)
        let yPositive = viewModel.projectScenePoint(x: 0, y: 1, z: 0, in: size, camera: camera)
        let zPositive = viewModel.projectScenePoint(x: 0, y: 0, z: 1, in: size, camera: camera)

        func line(_ from: CGPoint, _ to: CGPoint, color: Color) {
            var path = Path()
            path.move(to: from)
            path.addLine(to: to)
            context.stroke(path, with: .color(color.opacity(0.9)), style: StrokeStyle(lineWidth: 1.1, lineCap: .round))
        }

        line(origin, xPositive, color: .red)
        line(origin, yPositive, color: .green)
        line(origin, zPositive, color: .blue)

        context.fill(Path(ellipseIn: CGRect(x: origin.x - 2, y: origin.y - 2, width: 4, height: 4)), with: .color(.black.opacity(0.5)))
    }
}

#if os(iOS)
private struct CanvasMultiTouchGestureBridge: UIViewRepresentable {
    var stylusOnlyDrawing: Bool
    var twoFingerUndoEnabled: Bool
    var threeFingerRedoEnabled: Bool
    var quickEyedropperEnabled: Bool
    var quickEyedropperDelay: Double
    var onPanChanged: (CGPoint, CGSize) -> Void
    var onPanEnded: (CGPoint, CGSize) -> Void
    var onTwoFingerTap: () -> Void
    var onThreeFingerTap: () -> Void
    var onQuickEyedropper: (CGPoint) -> Void

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.onPanChanged = onPanChanged
        context.coordinator.onPanEnded = onPanEnded
        context.coordinator.onTwoFingerTap = onTwoFingerTap
        context.coordinator.onThreeFingerTap = onThreeFingerTap
        context.coordinator.onQuickEyedropper = onQuickEyedropper
        context.coordinator.attachIfNeeded(to: uiView.superview)
        context.coordinator.updateConfiguration(
            stylusOnlyDrawing: stylusOnlyDrawing,
            twoFingerUndoEnabled: twoFingerUndoEnabled,
            threeFingerRedoEnabled: threeFingerRedoEnabled,
            quickEyedropperEnabled: quickEyedropperEnabled,
            quickEyedropperDelay: quickEyedropperDelay
        )
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        _ = uiView
        coordinator.detach()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onPanChanged: onPanChanged,
            onPanEnded: onPanEnded,
            onTwoFingerTap: onTwoFingerTap,
            onThreeFingerTap: onThreeFingerTap,
            onQuickEyedropper: onQuickEyedropper
        )
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var onPanChanged: (CGPoint, CGSize) -> Void
        var onPanEnded: (CGPoint, CGSize) -> Void
        var onTwoFingerTap: () -> Void
        var onThreeFingerTap: () -> Void
        var onQuickEyedropper: (CGPoint) -> Void

        private weak var hostView: UIView?
        private let panRecognizer = UIPanGestureRecognizer()
        private let twoFingerTapRecognizer = UITapGestureRecognizer()
        private let threeFingerTapRecognizer = UITapGestureRecognizer()
        private let longPressRecognizer = UILongPressGestureRecognizer()

        init(
            onPanChanged: @escaping (CGPoint, CGSize) -> Void,
            onPanEnded: @escaping (CGPoint, CGSize) -> Void,
            onTwoFingerTap: @escaping () -> Void,
            onThreeFingerTap: @escaping () -> Void,
            onQuickEyedropper: @escaping (CGPoint) -> Void
        ) {
            self.onPanChanged = onPanChanged
            self.onPanEnded = onPanEnded
            self.onTwoFingerTap = onTwoFingerTap
            self.onThreeFingerTap = onThreeFingerTap
            self.onQuickEyedropper = onQuickEyedropper
            super.init()

            panRecognizer.minimumNumberOfTouches = 1
            panRecognizer.maximumNumberOfTouches = 1
            panRecognizer.cancelsTouchesInView = false
            panRecognizer.delaysTouchesBegan = false
            panRecognizer.delaysTouchesEnded = false
            panRecognizer.addTarget(self, action: #selector(handlePan(_:)))
            panRecognizer.delegate = self

            twoFingerTapRecognizer.numberOfTouchesRequired = 2
            twoFingerTapRecognizer.numberOfTapsRequired = 1
            twoFingerTapRecognizer.cancelsTouchesInView = false
            twoFingerTapRecognizer.delaysTouchesBegan = false
            twoFingerTapRecognizer.addTarget(self, action: #selector(handleTwoFingerTap(_:)))
            twoFingerTapRecognizer.delegate = self

            threeFingerTapRecognizer.numberOfTouchesRequired = 3
            threeFingerTapRecognizer.numberOfTapsRequired = 1
            threeFingerTapRecognizer.cancelsTouchesInView = false
            threeFingerTapRecognizer.delaysTouchesBegan = false
            threeFingerTapRecognizer.addTarget(self, action: #selector(handleThreeFingerTap(_:)))
            threeFingerTapRecognizer.delegate = self

            longPressRecognizer.numberOfTouchesRequired = 1
            longPressRecognizer.minimumPressDuration = 0.18
            longPressRecognizer.cancelsTouchesInView = false
            longPressRecognizer.delaysTouchesBegan = false
            longPressRecognizer.addTarget(self, action: #selector(handleLongPress(_:)))
            longPressRecognizer.delegate = self
            longPressRecognizer.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.direct.rawValue)]

            twoFingerTapRecognizer.require(toFail: threeFingerTapRecognizer)
        }

        func attachIfNeeded(to view: UIView?) {
            guard let view else {
                detach()
                return
            }
            if hostView === view {
                return
            }
            detach()
            hostView = view
            view.addGestureRecognizer(panRecognizer)
            view.addGestureRecognizer(twoFingerTapRecognizer)
            view.addGestureRecognizer(threeFingerTapRecognizer)
            view.addGestureRecognizer(longPressRecognizer)
        }

        func detach() {
            guard let hostView else { return }
            hostView.removeGestureRecognizer(panRecognizer)
            hostView.removeGestureRecognizer(twoFingerTapRecognizer)
            hostView.removeGestureRecognizer(threeFingerTapRecognizer)
            hostView.removeGestureRecognizer(longPressRecognizer)
            self.hostView = nil
        }

        func updateConfiguration(
            stylusOnlyDrawing: Bool,
            twoFingerUndoEnabled: Bool,
            threeFingerRedoEnabled: Bool,
            quickEyedropperEnabled: Bool,
            quickEyedropperDelay: Double
        ) {
            if stylusOnlyDrawing {
                panRecognizer.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.pencil.rawValue)]
            } else {
                panRecognizer.allowedTouchTypes = [
                    NSNumber(value: UITouch.TouchType.direct.rawValue),
                    NSNumber(value: UITouch.TouchType.pencil.rawValue)
                ]
            }
            twoFingerTapRecognizer.isEnabled = twoFingerUndoEnabled
            threeFingerTapRecognizer.isEnabled = threeFingerRedoEnabled
            longPressRecognizer.isEnabled = quickEyedropperEnabled
            longPressRecognizer.minimumPressDuration = min(max(quickEyedropperDelay, 0.1), 2.0)
        }

        @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard let hostView else { return }
            let location = gesture.location(in: hostView)
            let translationPoint = gesture.translation(in: hostView)
            let translation = CGSize(width: translationPoint.x, height: translationPoint.y)

            switch gesture.state {
            case .began, .changed:
                onPanChanged(location, translation)
            case .ended, .cancelled, .failed:
                onPanEnded(location, translation)
            default:
                break
            }
        }

        @objc private func handleTwoFingerTap(_ gesture: UITapGestureRecognizer) {
            guard gesture.state == .ended else { return }
            onTwoFingerTap()
        }

        @objc private func handleThreeFingerTap(_ gesture: UITapGestureRecognizer) {
            guard gesture.state == .ended else { return }
            onThreeFingerTap()
        }

        @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
            guard gesture.state == .began else { return }
            guard let hostView else { return }
            onQuickEyedropper(gesture.location(in: hostView))
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            _ = gestureRecognizer
            _ = otherGestureRecognizer
            return true
        }
    }
}
#else
private struct CanvasMultiTouchGestureBridge: View {
    var stylusOnlyDrawing: Bool
    var twoFingerUndoEnabled: Bool
    var threeFingerRedoEnabled: Bool
    var quickEyedropperEnabled: Bool
    var quickEyedropperDelay: Double
    var onPanChanged: (CGPoint, CGSize) -> Void
    var onPanEnded: (CGPoint, CGSize) -> Void
    var onTwoFingerTap: () -> Void
    var onThreeFingerTap: () -> Void
    var onQuickEyedropper: (CGPoint) -> Void

    var body: some View {
        _ = stylusOnlyDrawing
        _ = twoFingerUndoEnabled
        _ = threeFingerRedoEnabled
        _ = quickEyedropperEnabled
        _ = quickEyedropperDelay
        _ = onPanChanged
        _ = onPanEnded
        _ = onTwoFingerTap
        _ = onThreeFingerTap
        _ = onQuickEyedropper
        return Color.clear
    }
}
#endif

private enum StabilizerMode: String, Codable, CaseIterable, Sendable {
    case realtime
    case after

    var localizedLabel: String {
        switch self {
        case .realtime:
            return "실시간"
        case .after:
            return "사후"
        }
    }
}

@MainActor
private final class StudioEditorViewModel: ObservableObject {
    static let toolOrder: [DrawTool] = [.freeDraw, .fill, .erase]
    static let viewOrder: [ViewID] = [.front, .right, .top, .left, .back]
    static let palette = [
        "#111827",
        "#334155",
        "#ef4444",
        "#f97316",
        "#f59e0b",
        "#22c55e",
        "#06b6d4",
        "#3b82f6",
        "#6366f1",
        "#8b5cf6",
        "#ec4899",
        "#f43f5e"
    ]

    @Published var strokes: [EditorStroke] = []
    @Published var activeStrokePoints: [NormalizedPoint] = []
    @Published var selectedStrokeIDs: Set<UUID> = []
    @Published var brushSize: Double = 12 {
        didSet { persistOnSettingChange(oldValue: oldValue, newValue: brushSize) }
    }
    @Published var brushStrength: Double = 0.28 {
        didSet { persistOnSettingChange(oldValue: oldValue, newValue: brushStrength) }
    }
    @Published var brushColorHex: String = "#3b82f6" {
        didSet { persistOnSettingChange(oldValue: oldValue, newValue: brushColorHex) }
    }
    @Published var drawTool: DrawTool = .freeDraw {
        didSet { persistOnSettingChange(oldValue: oldValue, newValue: drawTool) }
    }
    @Published var inputMode: InputMode = .draw {
        didSet { persistOnSettingChange(oldValue: oldValue, newValue: inputMode) }
    }
    @Published var activeView: ViewID = .front {
        didSet { persistOnSettingChange(oldValue: oldValue, newValue: activeView) }
    }
    @Published var drawPlaneAxis: SliceAxis = .z {
        didSet { persistOnSettingChange(oldValue: oldValue, newValue: drawPlaneAxis) }
    }
    @Published var transformPivotMode: PivotMode = .selection {
        didSet { persistOnSettingChange(oldValue: oldValue, newValue: transformPivotMode) }
    }
    @Published var gridSnapEnabled: Bool = false {
        didSet { persistOnSettingChange(oldValue: oldValue, newValue: gridSnapEnabled) }
    }
    @Published var gridSnapStep: Double = 0.04 {
        didSet { persistOnSettingChange(oldValue: oldValue, newValue: gridSnapStep) }
    }
    @Published var angleSnapEnabled: Bool = false {
        didSet { persistOnSettingChange(oldValue: oldValue, newValue: angleSnapEnabled) }
    }
    @Published var angleSnapDegrees: Double = 15 {
        didSet { persistOnSettingChange(oldValue: oldValue, newValue: angleSnapDegrees) }
    }
    @Published var mirrorDraw: Bool = false {
        didSet { persistOnSettingChange(oldValue: oldValue, newValue: mirrorDraw) }
    }
    @Published var smoothMeshView: Bool = true {
        didSet { persistOnSettingChange(oldValue: oldValue, newValue: smoothMeshView) }
    }
    @Published var autoFillClosedStroke: Bool = false {
        didSet { persistOnSettingChange(oldValue: oldValue, newValue: autoFillClosedStroke) }
    }
    @Published var stabilizerEnabled: Bool = true {
        didSet { persistOnSettingChange(oldValue: oldValue, newValue: stabilizerEnabled) }
    }
    @Published var stabilizerMode: StabilizerMode = .realtime {
        didSet { persistOnSettingChange(oldValue: oldValue, newValue: stabilizerMode) }
    }
    @Published var stabilizerStrength: Double = 0.45 {
        didSet { persistOnSettingChange(oldValue: oldValue, newValue: stabilizerStrength) }
    }
    @Published var stylusPalmRejectionEnabled: Bool = false {
        didSet { persistOnSettingChange(oldValue: oldValue, newValue: stylusPalmRejectionEnabled) }
    }
    @Published var undoByTwoFingerTapEnabled: Bool = true {
        didSet { persistOnSettingChange(oldValue: oldValue, newValue: undoByTwoFingerTapEnabled) }
    }
    @Published var redoByThreeFingerTapEnabled: Bool = true {
        didSet { persistOnSettingChange(oldValue: oldValue, newValue: redoByThreeFingerTapEnabled) }
    }
    @Published var quickEyedropperEnabled: Bool = true {
        didSet { persistOnSettingChange(oldValue: oldValue, newValue: quickEyedropperEnabled) }
    }
    @Published var quickEyedropperDelay: Double = 0.18 {
        didSet { persistOnSettingChange(oldValue: oldValue, newValue: quickEyedropperDelay) }
    }
    @Published var sliceEnabled: Bool = false {
        didSet { persistOnSettingChange(oldValue: oldValue, newValue: sliceEnabled) }
    }
    @Published var multiSelectEnabled: Bool = false {
        didSet { persistOnSettingChange(oldValue: oldValue, newValue: multiSelectEnabled) }
    }
    @Published var activeSliceLayerID: String = ""
    @Published var sliceLayers: [SliceLayer] = []
    @Published var mainCameraState: EditorCameraState = .front {
        didSet { persistOnSettingChange(oldValue: oldValue, newValue: mainCameraState) }
    }
    @Published var pipCameraState: EditorCameraState = .isometric {
        didSet { persistOnSettingChange(oldValue: oldValue, newValue: pipCameraState) }
    }
    @Published var showPIP: Bool = true {
        didSet { persistOnSettingChange(oldValue: oldValue, newValue: showPIP) }
    }
    @Published var pipOffset: CGSize = .zero {
        didSet { persistOnSettingChange(oldValue: oldValue, newValue: pipOffset) }
    }
    @Published var lastSavedAt: Date?
    @Published var isAutosavePending: Bool = false

    private var redoBuffer: [EditorStroke] = []
    private var copiedStrokeBuffer: [EditorStroke] = []
    private var canvasSize: CGSize = .zero
    private var pipTopInset: Double = 84
    private var pipBottomInset: Double = 12
    private var isDraggingStroke = false
    private var activeStrokeBasePoints: [NormalizedPoint] = []
    private var realtimeStabilizedPoint: NormalizedPoint?
    private var lastCanvasPanTranslation: CGSize = .zero
    private var autosaveTask: Task<Void, Never>?
    private var isRestoringSnapshot = false
    private var stackedScenePoints: [UUID: [ScenePoint]] = [:]
    private var stackHeightMapsByView: [ViewID: [StackCellKey: Double]] = [:]
    private var stackedGlobalDots: [StackDot] = []
    private var stackedGeometryDirty = true

    private static let autosaveKey = "ipchae.editor.autosave.v1"
    private static let autosaveDebounceNanos: UInt64 = 900_000_000
    private static let pipMargin: Double = 12
    private static let stackCellSize: Double = 0.08

    private struct StackCellKey: Hashable {
        let ix: Int
        let iy: Int
    }

    private struct StackDot {
        let point: ScenePoint
        let radius: Double
    }

    init() {
        let defaults = Self.defaultSliceLayers()
        sliceLayers = defaults
        activeSliceLayerID = defaults.first?.id ?? ""
        restoreAutosaveIfNeeded()
    }

    deinit {
        autosaveTask?.cancel()
    }

    var currentViewLabel: String {
        activeView.localizedLabel
    }

    var strokeCount: Int {
        strokes.count
    }

    var selectedCount: Int {
        selectedStrokeIDs.count
    }

    var dotCount: Int {
        strokes.reduce(0) { $0 + max(0, $1.points.count) }
    }

    var averageRadius: Double {
        guard !strokes.isEmpty else { return max(0.03, brushSize / 250) }
        let total = strokes.reduce(0) { $0 + $1.lineWidth }
        return max(0.03, min(0.3, total / Double(strokes.count) / 220))
    }

    var activeSliceLayer: SliceLayer? {
        sliceLayers.first(where: { $0.id == activeSliceLayerID })
    }

    var activeSliceDepth: Double {
        activeSliceLayer?.depth ?? 0
    }

    var activeSliceAxis: SliceAxis {
        activeSliceLayer?.axis ?? .z
    }

    var isActiveSliceVisible: Bool {
        activeSliceLayer?.visible ?? true
    }

    var isActiveSliceLocked: Bool {
        activeSliceLayer?.locked ?? false
    }

    var canDrawOnActiveSlice: Bool {
        !sliceEnabled || (isActiveSliceVisible && !isActiveSliceLocked)
    }

    var isStrokeInProgress: Bool {
        isDraggingStroke && !activeStrokePoints.isEmpty
    }

    var shouldShowSliceGuide: Bool {
        sliceEnabled && isActiveSliceVisible
    }

    var activeViewPlaneAxis: SliceAxis {
        Self.planeAxis(for: activeView)
    }

    var effectiveDrawAxis: SliceAxis {
        // View controls drawing plane orientation.
        activeViewPlaneAxis
    }

    var pipCameraLabel: String {
        "yaw \(Int(pipCameraState.yaw))° · pitch \(Int(pipCameraState.pitch))°"
    }

    func updateCanvasSize(
        _ size: CGSize,
        pipTopInset: CGFloat = 84,
        pipBottomInset: CGFloat = 12
    ) {
        canvasSize = size
        self.pipTopInset = Double(max(0, pipTopInset))
        self.pipBottomInset = Double(max(0, pipBottomInset))
        let clamped = clampedPIPOffset(pipOffset, pipSize: preferredPIPSize(for: size))
        if clamped != pipOffset {
            pipOffset = clamped
        }
    }

    func applyViewPreset(_ view: ViewID) {
        activeView = view
        mainCameraState = Self.cameraPreset(for: view)
    }

    func zoomMain(by factor: Double) {
        let next = max(0.35, min(3.2, mainCameraState.zoom * factor))
        mainCameraState.zoom = next
    }

    func zoomPIP(by factor: Double) {
        let next = max(0.35, min(3.2, pipCameraState.zoom * factor))
        pipCameraState.zoom = next
    }

    func orbitPIP(deltaYaw: Double, deltaPitch: Double) {
        pipCameraState.yaw = normalizedDegrees(pipCameraState.yaw + deltaYaw)
        pipCameraState.pitch = max(-85, min(85, pipCameraState.pitch + deltaPitch))
    }

    func panMain(deltaX: Double, deltaY: Double) {
        let nextX = max(-1.4, min(1.4, mainCameraState.panX + deltaX))
        let nextY = max(-1.4, min(1.4, mainCameraState.panY + deltaY))
        mainCameraState.panX = nextX
        mainCameraState.panY = nextY
    }

    func resetMainCamera() {
        mainCameraState = Self.cameraPreset(for: activeView)
    }

    func resetPIPCamera() {
        pipCameraState = .isometric
    }

    func applyPIPCameraToMain() {
        mainCameraState = pipCameraState
    }

    func panPIP(deltaX: Double, deltaY: Double, pipSize: CGSize) {
        let next = CGSize(width: pipOffset.width + deltaX, height: pipOffset.height + deltaY)
        pipOffset = clampedPIPOffset(next, pipSize: pipSize)
    }

    func selectLastStroke() {
        guard let last = strokes.last else { return }
        selectedStrokeIDs = [last.id]
    }

    func selectAllStrokes() {
        selectedStrokeIDs = Set(strokes.map(\.id))
    }

    func clearSelection() {
        selectedStrokeIDs.removeAll()
    }

    func selectStrokeGroup() {
        guard let firstID = selectedStrokeIDs.first else { return }
        guard let groupID = strokes.first(where: { $0.id == firstID })?.groupID else { return }
        let ids = strokes.filter { $0.groupID == groupID }.map(\.id)
        selectedStrokeIDs = Set(ids)
    }

    func groupSelected() {
        guard !selectedStrokeIDs.isEmpty else { return }
        let groupID = UUID().uuidString
        for index in strokes.indices where selectedStrokeIDs.contains(strokes[index].id) {
            strokes[index].groupID = groupID
        }
        markDirty()
    }

    func ungroupSelected() {
        guard !selectedStrokeIDs.isEmpty else { return }
        for index in strokes.indices where selectedStrokeIDs.contains(strokes[index].id) {
            strokes[index].groupID = nil
        }
        markDirty()
    }

    func copySelected() {
        copiedStrokeBuffer = strokes.filter { selectedStrokeIDs.contains($0.id) }
    }

    func cutSelected() {
        copySelected()
        deleteSelected()
    }

    func pasteCopied(offsetU: Double = 0.04, offsetV: Double = 0.04) {
        guard !copiedStrokeBuffer.isEmpty else { return }
        let pasted = copiedStrokeBuffer.map { stroke in
            EditorStroke(
                id: UUID(),
                colorHex: stroke.colorHex,
                lineWidth: stroke.lineWidth,
                points: stroke.points.map {
                    NormalizedPoint(
                        u: min(max($0.u + offsetU, 0), 1),
                        v: min(max($0.v + offsetV, 0), 1)
                    )
                },
                view: stroke.view,
                sliceDepth: stroke.sliceDepth,
                depositStrength: stroke.depositStrength,
                groupID: stroke.groupID
            )
        }
        strokes.append(contentsOf: pasted)
        selectedStrokeIDs = Set(pasted.map(\.id))
        markDirty()
    }

    func deleteSelected() {
        guard !selectedStrokeIDs.isEmpty else { return }
        let removed = strokes.filter { selectedStrokeIDs.contains($0.id) }
        guard !removed.isEmpty else { return }
        strokes.removeAll(where: { selectedStrokeIDs.contains($0.id) })
        redoBuffer.append(contentsOf: removed)
        selectedStrokeIDs.removeAll()
        markDirty()
    }

    func duplicateSelected(offsetU: Double = 0.03, offsetV: Double = -0.03) {
        guard !selectedStrokeIDs.isEmpty else { return }
        let selected = strokes.filter { selectedStrokeIDs.contains($0.id) }
        guard !selected.isEmpty else { return }
        let duplicates = selected.map { stroke in
            EditorStroke(
                id: UUID(),
                colorHex: stroke.colorHex,
                lineWidth: stroke.lineWidth,
                points: stroke.points.map {
                    NormalizedPoint(
                        u: min(max($0.u + offsetU, 0), 1),
                        v: min(max($0.v + offsetV, 0), 1)
                    )
                },
                view: stroke.view,
                sliceDepth: stroke.sliceDepth,
                depositStrength: stroke.depositStrength,
                groupID: stroke.groupID
            )
        }
        strokes.append(contentsOf: duplicates)
        selectedStrokeIDs = Set(duplicates.map(\.id))
        redoBuffer.removeAll()
        markDirty()
    }

    func nudgeSelected(deltaU: Double, deltaV: Double) {
        let targetIDs = effectiveTransformStrokeIDs()
        guard !targetIDs.isEmpty else { return }
        let step = clampedGridSnapStep
        let effectiveDeltaU = gridSnapEnabled ? snapDelta(deltaU, step: step) : deltaU
        let effectiveDeltaV = gridSnapEnabled ? snapDelta(deltaV, step: step) : deltaV
        var changed = false
        for index in strokes.indices {
            guard targetIDs.contains(strokes[index].id) else { continue }
            changed = true
            strokes[index].points = strokes[index].points.map {
                let nextU = $0.u + effectiveDeltaU
                let nextV = $0.v + effectiveDeltaV
                let snappedU = gridSnapEnabled ? snapValue(nextU, step: step) : nextU
                let snappedV = gridSnapEnabled ? snapValue(nextV, step: step) : nextV
                return NormalizedPoint(
                    u: min(max(snappedU, 0), 1),
                    v: min(max(snappedV, 0), 1)
                )
            }
        }
        if changed {
            markDirty()
        }
    }

    func scaleSelected(by factor: Double) {
        let targetIDs = effectiveTransformStrokeIDs()
        guard !targetIDs.isEmpty else { return }
        guard factor > 0 else { return }
        guard let selectionCenter = centroid(forStrokeIDs: targetIDs) else { return }
        let step = clampedGridSnapStep
        let groupCenters = groupCentroids(forStrokeIDs: targetIDs)
        var changed = false

        for index in strokes.indices {
            guard targetIDs.contains(strokes[index].id) else { continue }
            let center = transformPivot(
                for: strokes[index],
                selectionCenter: selectionCenter,
                groupCentroids: groupCenters
            )
            changed = true
            strokes[index].points = strokes[index].points.map { point in
                let translatedU = point.u - center.u
                let translatedV = point.v - center.v
                let scaledU = (translatedU * factor) + center.u
                let scaledV = (translatedV * factor) + center.v
                let snappedU = gridSnapEnabled ? snapValue(scaledU, step: step) : scaledU
                let snappedV = gridSnapEnabled ? snapValue(scaledV, step: step) : scaledV
                return NormalizedPoint(
                    u: min(max(snappedU, 0), 1),
                    v: min(max(snappedV, 0), 1)
                )
            }
        }
        if changed {
            markDirty()
        }
    }

    func rotateSelected(degrees: Double) {
        let targetIDs = effectiveTransformStrokeIDs()
        guard !targetIDs.isEmpty else { return }
        guard let selectionCenter = centroid(forStrokeIDs: targetIDs) else { return }
        let snappedDegrees = angleSnapEnabled ? snapValue(degrees, step: clampedAngleSnapDegrees) : degrees
        guard abs(snappedDegrees) > 0.0001 else { return }
        let radians = snappedDegrees * .pi / 180
        let cosValue = cos(radians)
        let sinValue = sin(radians)
        let step = clampedGridSnapStep
        let groupCenters = groupCentroids(forStrokeIDs: targetIDs)
        var changed = false

        for index in strokes.indices {
            guard targetIDs.contains(strokes[index].id) else { continue }
            let center = transformPivot(
                for: strokes[index],
                selectionCenter: selectionCenter,
                groupCentroids: groupCenters
            )
            changed = true
            strokes[index].points = strokes[index].points.map { point in
                let translatedU = point.u - center.u
                let translatedV = point.v - center.v
                let rotatedU = (translatedU * cosValue) - (translatedV * sinValue)
                let rotatedV = (translatedU * sinValue) + (translatedV * cosValue)
                let shiftedU = rotatedU + center.u
                let shiftedV = rotatedV + center.v
                let snappedU = gridSnapEnabled ? snapValue(shiftedU, step: step) : shiftedU
                let snappedV = gridSnapEnabled ? snapValue(shiftedV, step: step) : shiftedV
                return NormalizedPoint(
                    u: min(max(snappedU, 0), 1),
                    v: min(max(snappedV, 0), 1)
                )
            }
        }
        if changed {
            markDirty()
        }
    }

    func adjustGridSnapStep(by delta: Double) {
        let next = min(max(gridSnapStep + delta, 0.005), 0.2)
        guard next != gridSnapStep else { return }
        gridSnapStep = next
    }

    func adjustAngleSnapDegrees(by delta: Double) {
        let next = min(max(angleSnapDegrees + delta, 1), 90)
        guard next != angleSnapDegrees else { return }
        angleSnapDegrees = next
    }

    func addSliceLayer() {
        let axis = activeSliceLayer?.axis ?? .z
        let depth = activeSliceLayer?.depth ?? 0
        let layer = SliceLayer(
            id: "slice-layer-\(UUID().uuidString)",
            name: "\(axis.rawValue.uppercased()) Layer \(sliceLayers.count + 1)",
            axis: axis,
            depth: depth,
            visible: true,
            locked: false,
            colorHex: Self.colorHex(for: axis)
        )
        sliceLayers.insert(layer, at: 0)
        activeSliceLayerID = layer.id
        markDirty()
    }

    func removeActiveSliceLayer() {
        guard sliceLayers.count > 1 else { return }
        guard let index = sliceLayers.firstIndex(where: { $0.id == activeSliceLayerID }) else { return }
        sliceLayers.remove(at: index)
        activeSliceLayerID = sliceLayers[max(0, index - 1)].id
        markDirty()
    }

    func selectSliceLayer(id: String) {
        guard sliceLayers.contains(where: { $0.id == id }) else { return }
        activeSliceLayerID = id
        markDirty()
    }

    func updateActiveSliceAxis(_ axis: SliceAxis) {
        guard let index = sliceLayers.firstIndex(where: { $0.id == activeSliceLayerID }) else { return }
        sliceLayers[index].axis = axis
        sliceLayers[index].colorHex = Self.colorHex(for: axis)
        markDirty()
    }

    func setActiveSliceDepth(_ value: Double) {
        guard let index = sliceLayers.firstIndex(where: { $0.id == activeSliceLayerID }) else { return }
        sliceLayers[index].depth = max(-6, min(6, value))
        markDirty()
    }

    func toggleActiveSliceVisibility() {
        toggleSliceLayerVisibility(id: activeSliceLayerID)
    }

    func toggleActiveSliceLock() {
        toggleSliceLayerLock(id: activeSliceLayerID)
    }

    func toggleSliceLayerVisibility(id: String) {
        guard let index = sliceLayers.firstIndex(where: { $0.id == id }) else { return }
        sliceLayers[index].visible.toggle()
        markDirty()
    }

    func toggleSliceLayerLock(id: String) {
        guard let index = sliceLayers.firstIndex(where: { $0.id == id }) else { return }
        sliceLayers[index].locked.toggle()
        markDirty()
    }

    @discardableResult
    func cancelActiveStrokeIfNeeded() -> Bool {
        guard isDraggingStroke || !activeStrokePoints.isEmpty else { return false }
        activeStrokePoints.removeAll()
        activeStrokeBasePoints.removeAll()
        realtimeStabilizedPoint = nil
        isDraggingStroke = false
        return true
    }

    func pickBrushColorFromNearestStroke(at location: CGPoint, in canvasSize: CGSize) -> String? {
        guard !strokes.isEmpty else { return nil }
        let threshold = max(16, min(72, brushSize * 2))
        guard let nearest = nearestStroke(to: location, in: canvasSize, threshold: threshold) else { return nil }
        guard let stroke = strokes.first(where: { $0.id == nearest.0 }) else { return nil }
        brushColorHex = stroke.colorHex
        return stroke.colorHex
    }

    func handleDragChanged(_ location: CGPoint, translation: CGSize, canvasSize: CGSize) {
        updateCanvasSize(canvasSize)
        if inputMode != .draw {
            let dx = translation.width - lastCanvasPanTranslation.width
            let dy = translation.height - lastCanvasPanTranslation.height
            if canvasSize.width > 0, canvasSize.height > 0 {
                panMain(
                    deltaX: Double(dx / canvasSize.width) * 2,
                    deltaY: Double(-dy / canvasSize.height) * 2
                )
            }
            lastCanvasPanTranslation = translation
            return
        }

        guard canDrawOnActiveSlice else { return }

        if drawTool == .erase {
            eraseNearestStroke(at: location, in: canvasSize)
            return
        }

        if !isDraggingStroke {
            let dragDistance = hypot(translation.width, translation.height)
            if dragDistance < 1.8 {
                return
            }
            let rawPoint = normalizedPointMatchingProjection(location: location, in: canvasSize)
            let point = processedIncomingPoint(rawPoint, isStart: true)
            activeStrokeBasePoints = [point]
            rebuildActiveStrokePointsFromBase()
            isDraggingStroke = true
            return
        }

        let rawPoint = normalizedPointMatchingProjection(location: location, in: canvasSize)
        let point = processedIncomingPoint(rawPoint, isStart: false)
        if let last = activeStrokeBasePoints.last, last.distance(to: point) < 0.003 {
            return
        }
        activeStrokeBasePoints.append(point)
        rebuildActiveStrokePointsFromBase()
    }

    func handleDragEnded(location: CGPoint, translation: CGSize, canvasSize: CGSize) {
        defer {
            activeStrokePoints = []
            activeStrokeBasePoints = []
            realtimeStabilizedPoint = nil
            isDraggingStroke = false
        }

        if inputMode != .draw {
            let dragDistance = hypot(translation.width, translation.height)
            if dragDistance < 6 {
                selectNearestStroke(at: location, in: canvasSize)
            }
            lastCanvasPanTranslation = .zero
            return
        }

        guard canDrawOnActiveSlice else { return }
        guard drawTool != .erase else { return }
        guard activeStrokeBasePoints.count > 1 else { return }

        let finalizedBasePoints: [NormalizedPoint]
        if stabilizerEnabled, stabilizerMode == .after {
            finalizedBasePoints = applyPostStabilizer(
                to: activeStrokeBasePoints,
                strength: stabilizerStrength
            )
        } else {
            finalizedBasePoints = activeStrokeBasePoints
        }
        let finalizedPoints = mirroredPoints(from: finalizedBasePoints)
        guard finalizedPoints.count > 1 else { return }

        let stroke = EditorStroke(
            id: UUID(),
            colorHex: brushColorHex,
            lineWidth: brushSize,
            points: finalizedPoints,
            view: activeView,
            sliceDepth: activeDrawPlaneDepth(for: activeView),
            depositStrength: brushStrength
        )
        strokes.append(stroke)
        selectedStrokeIDs = [stroke.id]
        redoBuffer.removeAll()
        markDirty()
    }

    private func rebuildActiveStrokePointsFromBase() {
        activeStrokePoints = mirroredPoints(from: activeStrokeBasePoints)
    }

    private func mirroredPoints(from basePoints: [NormalizedPoint]) -> [NormalizedPoint] {
        guard mirrorDraw else { return basePoints }
        var mirrored: [NormalizedPoint] = []
        mirrored.reserveCapacity(basePoints.count * 2)
        for point in basePoints {
            mirrored.append(point)
            mirrored.append(point.mirroredX())
        }
        return mirrored
    }

    private func processedIncomingPoint(_ rawPoint: NormalizedPoint, isStart: Bool) -> NormalizedPoint {
        guard stabilizerEnabled, stabilizerMode == .realtime else {
            if isStart {
                realtimeStabilizedPoint = nil
            }
            return rawPoint
        }

        if isStart || realtimeStabilizedPoint == nil {
            realtimeStabilizedPoint = rawPoint
            return rawPoint
        }

        guard let previous = realtimeStabilizedPoint else { return rawPoint }
        let strength = min(max(stabilizerStrength, 0), 1)
        let followFactor = max(0.12, 1 - (strength * 0.82))
        let smoothed = NormalizedPoint(
            u: previous.u + ((rawPoint.u - previous.u) * followFactor),
            v: previous.v + ((rawPoint.v - previous.v) * followFactor)
        )
        realtimeStabilizedPoint = smoothed
        return smoothed
    }

    private func applyPostStabilizer(to points: [NormalizedPoint], strength: Double) -> [NormalizedPoint] {
        guard points.count > 2 else { return points }
        let clampedStrength = min(max(strength, 0), 1)
        let iterations = max(1, Int((clampedStrength * 5).rounded()))
        let blend = 0.16 + (clampedStrength * 0.54)

        var output = points
        for _ in 0..<iterations {
            var next = output
            for index in 1..<(output.count - 1) {
                let prev = output[index - 1]
                let current = output[index]
                let following = output[index + 1]
                let avgU = (prev.u + current.u + following.u) / 3
                let avgV = (prev.v + current.v + following.v) / 3
                next[index] = NormalizedPoint(
                    u: current.u + ((avgU - current.u) * blend),
                    v: current.v + ((avgV - current.v) * blend)
                )
            }
            output = next
        }
        return output
    }

    private func projectedMainScreenPoint(
        for point: NormalizedPoint,
        in size: CGSize
    ) -> CGPoint {
        let uv = normalizedToPlaneUV(point)
        let scenePoint = scenePointForPlaneCoordinates(
            u: uv.u,
            v: uv.v,
            view: activeView,
            depth: activeDrawPlaneDepth(for: activeView)
        )
        return projectScenePoint(
            x: scenePoint.x,
            y: scenePoint.y,
            z: scenePoint.z,
            in: size,
            camera: mainCameraState
        )
    }

    private func normalizedPointMatchingProjection(
        location: CGPoint,
        in size: CGSize
    ) -> NormalizedPoint {
        guard size.width > 0, size.height > 0 else {
            return NormalizedPoint(u: 0.5, v: 0.5)
        }

        var guess = NormalizedPoint.from(location: location, in: size)
        let epsilon = 0.0025
        let epsilonCGFloat = CGFloat(epsilon)

        for _ in 0..<4 {
            let projected = projectedMainScreenPoint(
                for: guess,
                in: size
            )

            let errorX = Double(location.x - projected.x)
            let errorY = Double(location.y - projected.y)
            if abs(errorX) + abs(errorY) < 0.6 {
                break
            }

            let guessU = NormalizedPoint(u: min(max(guess.u + epsilon, 0), 1), v: guess.v)
            let guessV = NormalizedPoint(u: guess.u, v: min(max(guess.v + epsilon, 0), 1))
            let projectedU = projectedMainScreenPoint(
                for: guessU,
                in: size
            )
            let projectedV = projectedMainScreenPoint(
                for: guessV,
                in: size
            )

            let j00 = Double((projectedU.x - projected.x) / epsilonCGFloat)
            let j10 = Double((projectedU.y - projected.y) / epsilonCGFloat)
            let j01 = Double((projectedV.x - projected.x) / epsilonCGFloat)
            let j11 = Double((projectedV.y - projected.y) / epsilonCGFloat)
            let det = (j00 * j11) - (j01 * j10)

            if abs(det) < 1e-7 {
                break
            }

            let deltaU = ((errorX * j11) - (j01 * errorY)) / det
            let deltaV = ((j00 * errorY) - (errorX * j10)) / det
            guess.u = min(max(guess.u + deltaU, 0), 1)
            guess.v = min(max(guess.v + deltaV, 0), 1)
        }

        return guess
    }

    @discardableResult
    func undo() -> Bool {
        guard let last = strokes.popLast() else { return false }
        selectedStrokeIDs.remove(last.id)
        redoBuffer.append(last)
        markDirty()
        return true
    }

    @discardableResult
    func redo() -> Bool {
        guard let next = redoBuffer.popLast() else { return false }
        strokes.append(next)
        selectedStrokeIDs = [next.id]
        markDirty()
        return true
    }

    func clear() {
        strokes.removeAll()
        redoBuffer.removeAll()
        activeStrokePoints.removeAll()
        activeStrokeBasePoints.removeAll()
        realtimeStabilizedPoint = nil
        isDraggingStroke = false
        selectedStrokeIDs.removeAll()
        markDirty()
    }

    func makeSummary() -> DraftSummary {
        ensureStackedScenePoints()

        let dots = strokes.flatMap { stroke in
            (stackedScenePoints[stroke.id] ?? []).map { scene in
                DraftExportDot(
                    x: scene.x,
                    y: scene.y,
                    z: scene.z,
                    radius: max(0.03, min(0.3, stroke.lineWidth / 220)),
                    depositAmount: max(0.05, min(1, stroke.depositStrength)),
                    colorHex: stroke.colorHex
                )
            }
        }

        let bounds = computeBounds(dots: dots)
        let radius = averageRadius
        let averageDepositAmount: Double = {
            guard !strokes.isEmpty else { return max(0.05, min(1, brushStrength)) }
            let total = strokes.reduce(0) { $0 + $1.depositStrength }
            return max(0.05, min(1, total / Double(strokes.count)))
        }()

        return DraftSummary(
            strokeCount: strokeCount,
            dotCount: dots.count,
            averageRadius: radius,
            averageDepositAmount: averageDepositAmount,
            bounds: bounds,
            dots: Array(dots.prefix(3_500))
        )
    }

    func projectedPoints(
        stroke: EditorStroke,
        strokeOrdinal: Int,
        in size: CGSize,
        camera: EditorCameraState
    ) -> [CGPoint] {
        _ = strokeOrdinal
        ensureStackedScenePoints()
        let scenePoints = stackedScenePoints[stroke.id] ?? []
        return scenePoints.map { scenePoint in
            projectScenePoint(x: scenePoint.x, y: scenePoint.y, z: scenePoint.z, in: size, camera: camera)
        }
    }

    func heightVisualIntensity(for stroke: EditorStroke) -> Double {
        ensureStackedScenePoints()
        let scenePoints = stackedScenePoints[stroke.id] ?? []
        guard !scenePoints.isEmpty else { return 0 }

        let heights = scenePoints.map { point in
            max(0, normalComponent(of: point, for: stroke.view) - stroke.sliceDepth)
        }
        let peak = heights.max() ?? 0
        let average = heights.reduce(0, +) / Double(heights.count)
        let blended = (peak * 0.64) + (average * 0.36)
        return max(0, min(1, blended / 0.42))
    }

    func projectedActiveStrokePoints(in size: CGSize, camera: EditorCameraState) -> [CGPoint] {
        let depth = activeDrawPlaneDepth(for: activeView)
        ensureStackedScenePoints()
        var map = stackHeightMapsByView[activeView] ?? [:]
        var previewDots = stackedGlobalDots
        let previewRadius = depositRadius(forLineWidth: brushSize)
        let previewAmount = depositAmount(forLineWidth: brushSize, strength: brushStrength)

        return activeStrokePoints.map { point in
            let uv = normalizedToPlaneUV(point)
            let planePoint = scenePointForPlaneCoordinates(
                u: uv.u,
                v: uv.v,
                view: activeView,
                depth: depth
            )
            let mapSupport = sampleHeight(from: map, u: uv.u, v: uv.v)
            let crossSupport = sampleCrossViewSupport(
                basePoint: planePoint,
                view: activeView,
                dots: previewDots
            )
            let supportHeight = max(mapSupport, crossSupport)
            let scenePoint = scenePointForPlaneCoordinates(
                u: uv.u,
                v: uv.v,
                view: activeView,
                depth: depth + supportHeight
            )
            depositHeight(
                in: &map,
                u: uv.u,
                v: uv.v,
                radius: previewRadius,
                amount: previewAmount
            )
            previewDots.append(
                StackDot(
                    point: scenePoint,
                    radius: previewRadius
                )
            )
            return projectScenePoint(x: scenePoint.x, y: scenePoint.y, z: scenePoint.z, in: size, camera: camera)
        }
    }

    func projectScenePoint(
        x: Double,
        y: Double,
        z: Double,
        in size: CGSize,
        camera: EditorCameraState
    ) -> CGPoint {
        let yaw = camera.yaw * .pi / 180
        let pitch = camera.pitch * .pi / 180

        let cosYaw = cos(yaw)
        let sinYaw = sin(yaw)
        let cosPitch = cos(pitch)
        let sinPitch = sin(pitch)

        let xYaw = (x * cosYaw) + (z * sinYaw)
        let zYaw = (-x * sinYaw) + (z * cosYaw)

        let yPitch = (y * cosPitch) - (zYaw * sinPitch)

        // Use orthographic projection for editing so the full canvas is drawable.
        let projectedX = (xYaw * camera.zoom) + camera.panX
        let projectedY = (yPitch * camera.zoom) + camera.panY

        let screenX = ((projectedX + 1) * 0.5) * size.width
        let screenY = ((1 - projectedY) * 0.5) * size.height
        return CGPoint(x: screenX, y: screenY)
    }

    private func selectNearestStroke(at location: CGPoint, in canvasSize: CGSize) {
        guard !strokes.isEmpty else { return }
        guard let nearest = nearestStroke(to: location, in: canvasSize, threshold: 26) else {
            if !multiSelectEnabled {
                selectedStrokeIDs.removeAll()
            }
            return
        }

        if multiSelectEnabled {
            if selectedStrokeIDs.contains(nearest.0) {
                selectedStrokeIDs.remove(nearest.0)
            } else {
                selectedStrokeIDs.insert(nearest.0)
            }
        } else {
            selectedStrokeIDs = [nearest.0]
        }
    }

    private func eraseNearestStroke(at location: CGPoint, in canvasSize: CGSize) {
        guard !strokes.isEmpty else { return }
        let threshold = max(16, min(58, brushSize * 1.1))
        guard let nearest = nearestStroke(to: location, in: canvasSize, threshold: threshold) else { return }
        guard let index = strokes.firstIndex(where: { $0.id == nearest.0 }) else { return }
        let removed = strokes.remove(at: index)
        selectedStrokeIDs.remove(removed.id)
        redoBuffer.append(removed)
        markDirty()
    }

    private func computeBounds(dots: [DraftExportDot]) -> DraftBounds? {
        guard let first = dots.first else { return nil }
        var minX = first.x
        var minY = first.y
        var minZ = first.z
        var maxX = first.x
        var maxY = first.y
        var maxZ = first.z

        for dot in dots.dropFirst() {
            minX = min(minX, dot.x)
            minY = min(minY, dot.y)
            minZ = min(minZ, dot.z)
            maxX = max(maxX, dot.x)
            maxY = max(maxY, dot.y)
            maxZ = max(maxZ, dot.z)
        }

        return DraftBounds(
            minX: minX,
            minY: minY,
            minZ: minZ,
            maxX: maxX,
            maxY: maxY,
            maxZ: maxZ
        )
    }

    private func nearestStroke(
        to location: CGPoint,
        in canvasSize: CGSize,
        threshold: Double
    ) -> (UUID, Double)? {
        guard canvasSize.width > 0, canvasSize.height > 0 else { return nil }
        guard threshold > 0 else { return nil }

        let thresholdSquared = threshold * threshold
        let nearest = strokes
            .compactMap { stroke -> (UUID, Double)? in
                let projected = projectedPoints(
                    stroke: stroke,
                    strokeOrdinal: 0,
                    in: canvasSize,
                    camera: mainCameraState
                )
                guard projected.count >= 2 else { return nil }
                let distanceSquared = squaredDistance(from: location, toPolyline: projected)
                return (stroke.id, distanceSquared)
            }
            .min(by: { $0.1 < $1.1 })

        guard let nearest, nearest.1 <= thresholdSquared else { return nil }
        return nearest
    }

    private func squaredDistance(from point: CGPoint, toPolyline polyline: [CGPoint]) -> Double {
        guard polyline.count > 1 else { return .greatestFiniteMagnitude }
        var best = Double.greatestFiniteMagnitude
        for index in 0..<(polyline.count - 1) {
            let candidate = squaredDistance(point: point, segmentStart: polyline[index], segmentEnd: polyline[index + 1])
            if candidate < best {
                best = candidate
            }
        }
        return best
    }

    private func squaredDistance(point: CGPoint, segmentStart a: CGPoint, segmentEnd b: CGPoint) -> Double {
        let abX = b.x - a.x
        let abY = b.y - a.y
        let abSquared = (abX * abX) + (abY * abY)
        guard abSquared > 0.000001 else {
            let dx = point.x - a.x
            let dy = point.y - a.y
            return Double((dx * dx) + (dy * dy))
        }

        let apX = point.x - a.x
        let apY = point.y - a.y
        let t = max(0, min(1, (apX * abX + apY * abY) / abSquared))
        let projectionX = a.x + (abX * t)
        let projectionY = a.y + (abY * t)
        let dx = point.x - projectionX
        let dy = point.y - projectionY
        return Double((dx * dx) + (dy * dy))
    }

    private func activeDrawPlaneDepth(for view: ViewID) -> Double {
        guard sliceEnabled else { return 0 }
        guard activeSliceAxis == Self.planeAxis(for: view) else { return 0 }
        return max(-1, min(1, activeSliceDepth / 6))
    }

    private func ensureStackedScenePoints() {
        guard stackedGeometryDirty else { return }

        var maps: [ViewID: [StackCellKey: Double]] = [:]
        for view in Self.viewOrder {
            maps[view] = [:]
        }

        var nextScenePoints: [UUID: [ScenePoint]] = [:]
        var globalDots: [StackDot] = []

        for stroke in strokes {
            guard !stroke.points.isEmpty else {
                nextScenePoints[stroke.id] = []
                continue
            }

            var map = maps[stroke.view] ?? [:]
            let depositRadius = strokeDepositRadius(stroke)
            let depositAmount = strokeDepositAmount(stroke)
            var points: [ScenePoint] = []
            points.reserveCapacity(stroke.points.count)

            for point in stroke.points {
                let uv = normalizedToPlaneUV(point)
                let supportHeight = sampleHeight(from: map, u: uv.u, v: uv.v)
                let basePoint = scenePointForPlaneCoordinates(
                    u: uv.u,
                    v: uv.v,
                    view: stroke.view,
                    depth: stroke.sliceDepth
                )
                let crossSupport = sampleCrossViewSupport(
                    basePoint: basePoint,
                    view: stroke.view,
                    dots: globalDots
                )
                let liftedDepth = stroke.sliceDepth + max(supportHeight, crossSupport)

                points.append(
                    scenePointForPlaneCoordinates(
                        u: uv.u,
                        v: uv.v,
                        view: stroke.view,
                        depth: max(-3.2, min(3.2, liftedDepth))
                    )
                )
                if let latestPoint = points.last {
                    globalDots.append(
                        StackDot(
                            point: latestPoint,
                            radius: depositRadius
                        )
                    )
                }

                depositHeight(
                    in: &map,
                    u: uv.u,
                    v: uv.v,
                    radius: depositRadius,
                    amount: depositAmount
                )
            }

            maps[stroke.view] = map
            nextScenePoints[stroke.id] = points
        }

        stackedScenePoints = nextScenePoints
        stackHeightMapsByView = maps
        stackedGlobalDots = globalDots
        stackedGeometryDirty = false
    }

    private func normalizedToPlaneUV(_ point: NormalizedPoint) -> (u: Double, v: Double) {
        let u = (point.u * 2) - 1
        let v = ((1 - point.v) * 2) - 1
        return (u, v)
    }

    private func scenePointForPlaneCoordinates(
        u: Double,
        v: Double,
        view: ViewID,
        depth: Double
    ) -> ScenePoint {
        switch view {
        case .front:
            return ScenePoint(x: u, y: v, z: depth)
        case .back:
            return ScenePoint(x: -u, y: v, z: -depth)
        case .right:
            return ScenePoint(x: depth, y: v, z: u)
        case .left:
            return ScenePoint(x: -depth, y: v, z: -u)
        case .top:
            return ScenePoint(x: u, y: depth, z: v)
        }
    }

    private func normalComponent(of point: ScenePoint, for view: ViewID) -> Double {
        switch view {
        case .front:
            return point.z
        case .back:
            return -point.z
        case .right:
            return point.x
        case .left:
            return -point.x
        case .top:
            return point.y
        }
    }

    private func viewNormal(for view: ViewID) -> ScenePoint {
        switch view {
        case .front:
            return ScenePoint(x: 0, y: 0, z: 1)
        case .back:
            return ScenePoint(x: 0, y: 0, z: -1)
        case .right:
            return ScenePoint(x: 1, y: 0, z: 0)
        case .left:
            return ScenePoint(x: -1, y: 0, z: 0)
        case .top:
            return ScenePoint(x: 0, y: 1, z: 0)
        }
    }

    private func sampleCrossViewSupport(
        basePoint: ScenePoint,
        view: ViewID,
        dots: [StackDot]
    ) -> Double {
        guard !dots.isEmpty else { return 0 }
        let normal = viewNormal(for: view)
        var maxHeight = 0.0

        for dot in dots {
            let delta = subtract(dot.point, basePoint)
            let along = dotProduct(delta, normal)
            let radialSq = max(0, lengthSquared(delta) - (along * along))
            let supportRadius = max(dot.radius * 0.74, 0.035)
            let radiusSq = supportRadius * supportRadius
            if radialSq > radiusSq { continue }

            let cap = sqrt(max(0, radiusSq - radialSq))
            let candidate = along + cap
            if candidate > maxHeight {
                maxHeight = candidate
            }
        }

        return maxHeight
    }

    private func subtract(_ a: ScenePoint, _ b: ScenePoint) -> ScenePoint {
        ScenePoint(
            x: a.x - b.x,
            y: a.y - b.y,
            z: a.z - b.z
        )
    }

    private func dotProduct(_ a: ScenePoint, _ b: ScenePoint) -> Double {
        (a.x * b.x) + (a.y * b.y) + (a.z * b.z)
    }

    private func lengthSquared(_ value: ScenePoint) -> Double {
        (value.x * value.x) + (value.y * value.y) + (value.z * value.z)
    }

    private func sampleHeight(from map: [StackCellKey: Double], u: Double, v: Double) -> Double {
        let gx = u / Self.stackCellSize
        let gy = v / Self.stackCellSize
        let i0 = Int(floor(gx))
        let j0 = Int(floor(gy))
        let i1 = i0 + 1
        let j1 = j0 + 1
        let tx = gx - Double(i0)
        let ty = gy - Double(j0)

        let h00 = map[StackCellKey(ix: i0, iy: j0)] ?? 0
        let h10 = map[StackCellKey(ix: i1, iy: j0)] ?? 0
        let h01 = map[StackCellKey(ix: i0, iy: j1)] ?? 0
        let h11 = map[StackCellKey(ix: i1, iy: j1)] ?? 0

        let hx0 = (h00 * (1 - tx)) + (h10 * tx)
        let hx1 = (h01 * (1 - tx)) + (h11 * tx)
        return (hx0 * (1 - ty)) + (hx1 * ty)
    }

    private func depositHeight(
        in map: inout [StackCellKey: Double],
        u: Double,
        v: Double,
        radius: Double,
        amount: Double
    ) {
        guard radius > 0, amount > 0 else { return }
        let centerI = Int(floor(u / Self.stackCellSize))
        let centerJ = Int(floor(v / Self.stackCellSize))
        let range = Int(ceil(radius / Self.stackCellSize)) + 1

        for di in -range...range {
            for dj in -range...range {
                let ix = centerI + di
                let iy = centerJ + dj
                let sampleU = Double(ix) * Self.stackCellSize
                let sampleV = Double(iy) * Self.stackCellSize
                let distance = hypot(sampleU - u, sampleV - v)
                if distance > radius { continue }
                let normalized = distance / radius
                let falloff = 1 - (normalized * normalized)
                let key = StackCellKey(ix: ix, iy: iy)
                map[key] = (map[key] ?? 0) + (amount * falloff)
            }
        }
    }

    private func strokeDepositRadius(_ stroke: EditorStroke) -> Double {
        depositRadius(forLineWidth: stroke.lineWidth)
    }

    private func strokeDepositAmount(_ stroke: EditorStroke) -> Double {
        depositAmount(forLineWidth: stroke.lineWidth, strength: stroke.depositStrength)
    }

    private func depositRadius(forLineWidth lineWidth: Double) -> Double {
        max(0.06, min(0.28, lineWidth / 105))
    }

    private func depositAmount(forLineWidth lineWidth: Double, strength: Double) -> Double {
        let amount = max(0.05, min(1, strength)) * (lineWidth / 95)
        return max(0.02, min(0.26, amount))
    }

    private func selectedCentroid() -> NormalizedPoint? {
        centroid(forStrokeIDs: selectedStrokeIDs)
    }

    private func centroid(forStrokeIDs strokeIDs: Set<UUID>) -> NormalizedPoint? {
        let points = strokes
            .filter { strokeIDs.contains($0.id) }
            .flatMap(\.points)
        guard !points.isEmpty else { return nil }
        let sumU = points.reduce(0) { $0 + $1.u }
        let sumV = points.reduce(0) { $0 + $1.v }
        return NormalizedPoint(
            u: sumU / Double(points.count),
            v: sumV / Double(points.count)
        )
    }

    private func effectiveTransformStrokeIDs() -> Set<UUID> {
        guard !selectedStrokeIDs.isEmpty else { return [] }
        var expanded = selectedStrokeIDs
        let selectedGroupIDs = Set(
            strokes
                .filter { selectedStrokeIDs.contains($0.id) }
                .compactMap(\.groupID)
        )
        guard !selectedGroupIDs.isEmpty else { return expanded }
        for stroke in strokes {
            guard let groupID = stroke.groupID else { continue }
            if selectedGroupIDs.contains(groupID) {
                expanded.insert(stroke.id)
            }
        }
        return expanded
    }

    private func groupCentroids(forStrokeIDs strokeIDs: Set<UUID>) -> [String: NormalizedPoint] {
        var groupedPoints: [String: [NormalizedPoint]] = [:]
        for stroke in strokes where strokeIDs.contains(stroke.id) {
            guard let groupID = stroke.groupID else { continue }
            groupedPoints[groupID, default: []].append(contentsOf: stroke.points)
        }
        var centers: [String: NormalizedPoint] = [:]
        for (groupID, points) in groupedPoints {
            guard !points.isEmpty else { continue }
            let sumU = points.reduce(0) { $0 + $1.u }
            let sumV = points.reduce(0) { $0 + $1.v }
            centers[groupID] = NormalizedPoint(
                u: sumU / Double(points.count),
                v: sumV / Double(points.count)
            )
        }
        return centers
    }

    private var clampedGridSnapStep: Double {
        min(max(gridSnapStep, 0.005), 0.2)
    }

    private var clampedAngleSnapDegrees: Double {
        min(max(angleSnapDegrees, 1), 90)
    }

    private func transformPivot(
        for stroke: EditorStroke,
        selectionCenter: NormalizedPoint,
        groupCentroids: [String: NormalizedPoint]
    ) -> NormalizedPoint {
        switch transformPivotMode {
        case .object:
            if let groupID = stroke.groupID, let groupCenter = groupCentroids[groupID] {
                return groupCenter
            }
            return strokeCentroid(stroke) ?? selectionCenter
        case .selection:
            return selectionCenter
        case .world:
            return NormalizedPoint(u: 0.5, v: 0.5)
        }
    }

    private func strokeCentroid(_ stroke: EditorStroke) -> NormalizedPoint? {
        guard !stroke.points.isEmpty else { return nil }
        let sumU = stroke.points.reduce(0) { $0 + $1.u }
        let sumV = stroke.points.reduce(0) { $0 + $1.v }
        return NormalizedPoint(
            u: sumU / Double(stroke.points.count),
            v: sumV / Double(stroke.points.count)
        )
    }

    private func snapDelta(_ value: Double, step: Double) -> Double {
        guard value != 0 else { return 0 }
        let ratio = value / step
        let snappedRatio = ratio > 0 ? ceil(ratio) : floor(ratio)
        return snappedRatio * step
    }

    private func snapValue(_ value: Double, step: Double) -> Double {
        guard step > 0 else { return value }
        return (value / step).rounded() * step
    }

    private func markDirty() {
        markGeometryDirty()
        scheduleAutosave()
    }

    private func markGeometryDirty() {
        stackedGeometryDirty = true
    }

    private func persistOnSettingChange<T: Equatable>(oldValue: T, newValue: T) {
        guard !isRestoringSnapshot else { return }
        guard oldValue != newValue else { return }
        markDirty()
    }

    private func scheduleAutosave() {
        autosaveTask?.cancel()
        isAutosavePending = true
        autosaveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: Self.autosaveDebounceNanos)
            guard let self else { return }
            await self.persistAutosave()
        }
    }

    private func persistAutosave() async {
        let snapshot = EditorAutosaveSnapshot(
            strokes: strokes,
            brushSize: brushSize,
            brushStrength: brushStrength,
            brushColorHex: brushColorHex,
            drawTool: drawTool,
            inputMode: inputMode,
            activeView: activeView,
            drawPlaneAxis: drawPlaneAxis,
            transformPivotMode: transformPivotMode,
            gridSnapEnabled: gridSnapEnabled,
            gridSnapStep: gridSnapStep,
            angleSnapEnabled: angleSnapEnabled,
            angleSnapDegrees: angleSnapDegrees,
            mirrorDraw: mirrorDraw,
            smoothMeshView: smoothMeshView,
            autoFillClosedStroke: autoFillClosedStroke,
            stabilizerEnabled: stabilizerEnabled,
            stabilizerMode: stabilizerMode,
            stabilizerStrength: stabilizerStrength,
            stylusPalmRejectionEnabled: stylusPalmRejectionEnabled,
            undoByTwoFingerTapEnabled: undoByTwoFingerTapEnabled,
            redoByThreeFingerTapEnabled: redoByThreeFingerTapEnabled,
            quickEyedropperEnabled: quickEyedropperEnabled,
            quickEyedropperDelay: quickEyedropperDelay,
            sliceEnabled: sliceEnabled,
            multiSelectEnabled: multiSelectEnabled,
            activeSliceLayerID: activeSliceLayerID,
            sliceLayers: sliceLayers,
            selectedStrokeIDs: Array(selectedStrokeIDs),
            mainCameraState: mainCameraState,
            pipCameraState: pipCameraState,
            showPIP: showPIP,
            pipOffsetX: pipOffset.width,
            pipOffsetY: pipOffset.height,
            savedAtMillis: Int64(Date().timeIntervalSince1970 * 1000)
        )

        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(snapshot) else {
            isAutosavePending = false
            return
        }

        UserDefaults.standard.set(data, forKey: Self.autosaveKey)
        let savedDate = Date(timeIntervalSince1970: TimeInterval(snapshot.savedAtMillis) / 1000)
        lastSavedAt = savedDate
        isAutosavePending = false
    }

    private func restoreAutosaveIfNeeded() {
        guard let data = UserDefaults.standard.data(forKey: Self.autosaveKey) else { return }
        let decoder = JSONDecoder()
        guard let snapshot = try? decoder.decode(EditorAutosaveSnapshot.self, from: data) else { return }

        isRestoringSnapshot = true
        strokes = snapshot.strokes
        brushSize = snapshot.brushSize
        brushStrength = snapshot.brushStrength
        brushColorHex = snapshot.brushColorHex
        drawTool = snapshot.drawTool
        inputMode = snapshot.inputMode
        activeView = snapshot.activeView
        drawPlaneAxis = snapshot.drawPlaneAxis
        transformPivotMode = snapshot.transformPivotMode
        gridSnapEnabled = snapshot.gridSnapEnabled
        gridSnapStep = snapshot.gridSnapStep
        angleSnapEnabled = snapshot.angleSnapEnabled
        angleSnapDegrees = snapshot.angleSnapDegrees
        mirrorDraw = snapshot.mirrorDraw
        smoothMeshView = snapshot.smoothMeshView
        autoFillClosedStroke = snapshot.autoFillClosedStroke
        stabilizerEnabled = snapshot.stabilizerEnabled
        stabilizerMode = snapshot.stabilizerMode
        stabilizerStrength = snapshot.stabilizerStrength
        stylusPalmRejectionEnabled = snapshot.stylusPalmRejectionEnabled
        undoByTwoFingerTapEnabled = snapshot.undoByTwoFingerTapEnabled
        redoByThreeFingerTapEnabled = snapshot.redoByThreeFingerTapEnabled
        quickEyedropperEnabled = snapshot.quickEyedropperEnabled
        quickEyedropperDelay = snapshot.quickEyedropperDelay
        sliceEnabled = snapshot.sliceEnabled
        multiSelectEnabled = snapshot.multiSelectEnabled
        sliceLayers = snapshot.sliceLayers.isEmpty ? Self.defaultSliceLayers() : snapshot.sliceLayers
        activeSliceLayerID = snapshot.activeSliceLayerID
        selectedStrokeIDs = Set(snapshot.selectedStrokeIDs).intersection(Set(strokes.map(\.id)))
        mainCameraState = snapshot.mainCameraState
        pipCameraState = snapshot.pipCameraState
        showPIP = snapshot.showPIP
        pipOffset = CGSize(width: snapshot.pipOffsetX, height: snapshot.pipOffsetY)
        if !sliceLayers.contains(where: { $0.id == activeSliceLayerID }) {
            activeSliceLayerID = sliceLayers.first?.id ?? ""
        }
        lastSavedAt = Date(timeIntervalSince1970: TimeInterval(snapshot.savedAtMillis) / 1000)
        markGeometryDirty()
        isRestoringSnapshot = false
    }

    private static func cameraPreset(for view: ViewID) -> EditorCameraState {
        switch view {
        case .front:
            return .front
        case .back:
            return .back
        case .left:
            return .left
        case .right:
            return .right
        case .top:
            return .top
        }
    }

    private static func planeAxis(for view: ViewID) -> SliceAxis {
        switch view {
        case .front, .back:
            return .z
        case .left, .right:
            return .x
        case .top:
            return .y
        }
    }

    private func normalizedDegrees(_ degrees: Double) -> Double {
        var value = degrees.truncatingRemainder(dividingBy: 360)
        if value > 180 {
            value -= 360
        } else if value < -180 {
            value += 360
        }
        return value
    }

    private func preferredPIPSize(for size: CGSize) -> CGSize {
        CGSize(
            width: min(220, size.width * 0.42),
            height: min(160, size.height * 0.3)
        )
    }

    private func clampedPIPOffset(_ offset: CGSize, pipSize: CGSize) -> CGSize {
        guard canvasSize.width > 0, canvasSize.height > 0 else {
            return .zero
        }
        let horizontalTravel = max(0, canvasSize.width - pipSize.width - (Self.pipMargin * 2))
        let verticalTravel = max(0, canvasSize.height - pipSize.height - pipTopInset - pipBottomInset)
        let minX = -horizontalTravel
        let maxX = 0.0
        let minY = 0.0
        let maxY = verticalTravel
        return CGSize(
            width: min(max(offset.width, minX), maxX),
            height: min(max(offset.height, minY), maxY)
        )
    }

    private static func defaultSliceLayers() -> [SliceLayer] {
        [
            SliceLayer(
                id: "slice-layer-z-default",
                name: "Z Layer 1",
                axis: .z,
                depth: 0,
                visible: true,
                locked: false,
                colorHex: colorHex(for: .z)
            ),
            SliceLayer(
                id: "slice-layer-x-default",
                name: "X Layer 2",
                axis: .x,
                depth: 0,
                visible: true,
                locked: false,
                colorHex: colorHex(for: .x)
            ),
            SliceLayer(
                id: "slice-layer-y-default",
                name: "Y Layer 3",
                axis: .y,
                depth: 0,
                visible: true,
                locked: false,
                colorHex: colorHex(for: .y)
            )
        ]
    }

    private static func colorHex(for axis: SliceAxis) -> String {
        switch axis {
        case .x:
            return "#ef4444"
        case .y:
            return "#22c55e"
        case .z:
            return "#3b82f6"
        }
    }
}

private struct EditorCameraState: Codable, Equatable, Sendable {
    var yaw: Double
    var pitch: Double
    var zoom: Double
    var panX: Double
    var panY: Double

    static let front = EditorCameraState(yaw: 0, pitch: 0, zoom: 1, panX: 0, panY: 0)
    static let back = EditorCameraState(yaw: 180, pitch: 0, zoom: 1, panX: 0, panY: 0)
    static let left = EditorCameraState(yaw: -90, pitch: 0, zoom: 1, panX: 0, panY: 0)
    static let right = EditorCameraState(yaw: 90, pitch: 0, zoom: 1, panX: 0, panY: 0)
    static let top = EditorCameraState(yaw: 0, pitch: -90, zoom: 1, panX: 0, panY: 0)
    static let isometric = EditorCameraState(yaw: 36, pitch: -24, zoom: 1.05, panX: 0, panY: 0)
}

private struct ScenePoint {
    var x: Double
    var y: Double
    var z: Double
}

private struct EditorStroke: Codable, Identifiable, Equatable {
    var id: UUID
    var colorHex: String
    var lineWidth: Double
    var points: [NormalizedPoint]
    var view: ViewID
    var sliceDepth: Double
    var depositStrength: Double
    var groupID: String? = nil

    init(
        id: UUID,
        colorHex: String,
        lineWidth: Double,
        points: [NormalizedPoint],
        view: ViewID = .front,
        sliceDepth: Double = 0,
        depositStrength: Double = 0.28,
        groupID: String? = nil
    ) {
        self.id = id
        self.colorHex = colorHex
        self.lineWidth = lineWidth
        self.points = points
        self.view = view
        self.sliceDepth = sliceDepth
        self.depositStrength = depositStrength
        self.groupID = groupID
    }

    enum CodingKeys: String, CodingKey {
        case id
        case colorHex
        case lineWidth
        case points
        case view
        case sliceDepth
        case depositStrength
        case groupID
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        colorHex = try container.decode(String.self, forKey: .colorHex)
        lineWidth = try container.decode(Double.self, forKey: .lineWidth)
        points = try container.decode([NormalizedPoint].self, forKey: .points)
        view = try container.decodeIfPresent(ViewID.self, forKey: .view) ?? .front
        sliceDepth = try container.decodeIfPresent(Double.self, forKey: .sliceDepth) ?? 0
        depositStrength = try container.decodeIfPresent(Double.self, forKey: .depositStrength) ?? 0.28
        groupID = try container.decodeIfPresent(String.self, forKey: .groupID)
    }
}

private struct NormalizedPoint: Codable, Equatable {
    var u: Double
    var v: Double

    static func from(location: CGPoint, in size: CGSize) -> NormalizedPoint {
        guard size.width > 0, size.height > 0 else {
            return NormalizedPoint(u: 0.5, v: 0.5)
        }
        let u = min(max(location.x / size.width, 0), 1)
        let v = min(max(location.y / size.height, 0), 1)
        return NormalizedPoint(u: u, v: v)
    }

    func cgPoint(in size: CGSize) -> CGPoint {
        CGPoint(x: u * size.width, y: v * size.height)
    }

    func mirroredX() -> NormalizedPoint {
        NormalizedPoint(u: 1 - u, v: v)
    }

    func distance(to other: NormalizedPoint) -> Double {
        let dx = u - other.u
        let dy = v - other.v
        return sqrt((dx * dx) + (dy * dy))
    }

    func toDraftExportDot(sliceDepth: Double, radius: Double, depositAmount: Double, colorHex: String) -> DraftExportDot {
        DraftExportDot(
            x: (u * 2) - 1,
            y: ((1 - v) * 2) - 1,
            z: max(-1, min(1, sliceDepth / 6)),
            radius: radius,
            depositAmount: depositAmount,
            colorHex: colorHex
        )
    }
}

private struct EditorAutosaveSnapshot: Codable {
    var schemaVersion: Int = 1
    var strokes: [EditorStroke]
    var brushSize: Double
    var brushStrength: Double
    var brushColorHex: String
    var drawTool: DrawTool
    var inputMode: InputMode
    var activeView: ViewID
    var drawPlaneAxis: SliceAxis
    var transformPivotMode: PivotMode
    var gridSnapEnabled: Bool
    var gridSnapStep: Double
    var angleSnapEnabled: Bool
    var angleSnapDegrees: Double
    var mirrorDraw: Bool
    var smoothMeshView: Bool
    var autoFillClosedStroke: Bool
    var stabilizerEnabled: Bool
    var stabilizerMode: StabilizerMode
    var stabilizerStrength: Double
    var stylusPalmRejectionEnabled: Bool
    var undoByTwoFingerTapEnabled: Bool
    var redoByThreeFingerTapEnabled: Bool
    var quickEyedropperEnabled: Bool
    var quickEyedropperDelay: Double
    var sliceEnabled: Bool
    var multiSelectEnabled: Bool
    var activeSliceLayerID: String
    var sliceLayers: [SliceLayer]
    var selectedStrokeIDs: [UUID]
    var mainCameraState: EditorCameraState
    var pipCameraState: EditorCameraState
    var showPIP: Bool
    var pipOffsetX: Double
    var pipOffsetY: Double
    var savedAtMillis: Int64

    init(
        schemaVersion: Int = 1,
        strokes: [EditorStroke],
        brushSize: Double,
        brushStrength: Double,
        brushColorHex: String,
        drawTool: DrawTool,
        inputMode: InputMode,
        activeView: ViewID,
        drawPlaneAxis: SliceAxis,
        transformPivotMode: PivotMode,
        gridSnapEnabled: Bool,
        gridSnapStep: Double,
        angleSnapEnabled: Bool,
        angleSnapDegrees: Double,
        mirrorDraw: Bool,
        smoothMeshView: Bool,
        autoFillClosedStroke: Bool,
        stabilizerEnabled: Bool,
        stabilizerMode: StabilizerMode,
        stabilizerStrength: Double,
        stylusPalmRejectionEnabled: Bool,
        undoByTwoFingerTapEnabled: Bool,
        redoByThreeFingerTapEnabled: Bool,
        quickEyedropperEnabled: Bool,
        quickEyedropperDelay: Double,
        sliceEnabled: Bool,
        multiSelectEnabled: Bool,
        activeSliceLayerID: String,
        sliceLayers: [SliceLayer],
        selectedStrokeIDs: [UUID],
        mainCameraState: EditorCameraState,
        pipCameraState: EditorCameraState,
        showPIP: Bool,
        pipOffsetX: Double,
        pipOffsetY: Double,
        savedAtMillis: Int64
    ) {
        self.schemaVersion = schemaVersion
        self.strokes = strokes
        self.brushSize = brushSize
        self.brushStrength = brushStrength
        self.brushColorHex = brushColorHex
        self.drawTool = drawTool
        self.inputMode = inputMode
        self.activeView = activeView
        self.drawPlaneAxis = drawPlaneAxis
        self.transformPivotMode = transformPivotMode
        self.gridSnapEnabled = gridSnapEnabled
        self.gridSnapStep = gridSnapStep
        self.angleSnapEnabled = angleSnapEnabled
        self.angleSnapDegrees = angleSnapDegrees
        self.mirrorDraw = mirrorDraw
        self.smoothMeshView = smoothMeshView
        self.autoFillClosedStroke = autoFillClosedStroke
        self.stabilizerEnabled = stabilizerEnabled
        self.stabilizerMode = stabilizerMode
        self.stabilizerStrength = stabilizerStrength
        self.stylusPalmRejectionEnabled = stylusPalmRejectionEnabled
        self.undoByTwoFingerTapEnabled = undoByTwoFingerTapEnabled
        self.redoByThreeFingerTapEnabled = redoByThreeFingerTapEnabled
        self.quickEyedropperEnabled = quickEyedropperEnabled
        self.quickEyedropperDelay = quickEyedropperDelay
        self.sliceEnabled = sliceEnabled
        self.multiSelectEnabled = multiSelectEnabled
        self.activeSliceLayerID = activeSliceLayerID
        self.sliceLayers = sliceLayers
        self.selectedStrokeIDs = selectedStrokeIDs
        self.mainCameraState = mainCameraState
        self.pipCameraState = pipCameraState
        self.showPIP = showPIP
        self.pipOffsetX = pipOffsetX
        self.pipOffsetY = pipOffsetY
        self.savedAtMillis = savedAtMillis
    }

    enum CodingKeys: String, CodingKey {
        case schemaVersion
        case strokes
        case brushSize
        case brushStrength
        case brushColorHex
        case drawTool
        case inputMode
        case activeView
        case drawPlaneAxis
        case transformPivotMode
        case gridSnapEnabled
        case gridSnapStep
        case angleSnapEnabled
        case angleSnapDegrees
        case mirrorDraw
        case smoothMeshView
        case autoFillClosedStroke
        case stabilizerEnabled
        case stabilizerMode
        case stabilizerStrength
        case stylusPalmRejectionEnabled
        case undoByTwoFingerTapEnabled
        case redoByThreeFingerTapEnabled
        case quickEyedropperEnabled
        case quickEyedropperDelay
        case sliceEnabled
        case multiSelectEnabled
        case activeSliceLayerID
        case sliceLayers
        case selectedStrokeIDs
        case mainCameraState
        case pipCameraState
        case showPIP
        case pipOffsetX
        case pipOffsetY
        case savedAtMillis
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        strokes = try container.decodeIfPresent([EditorStroke].self, forKey: .strokes) ?? []
        brushSize = try container.decodeIfPresent(Double.self, forKey: .brushSize) ?? 12
        brushStrength = try container.decodeIfPresent(Double.self, forKey: .brushStrength) ?? 0.28
        brushColorHex = try container.decodeIfPresent(String.self, forKey: .brushColorHex) ?? "#3b82f6"
        drawTool = try container.decodeIfPresent(DrawTool.self, forKey: .drawTool) ?? .freeDraw
        inputMode = try container.decodeIfPresent(InputMode.self, forKey: .inputMode) ?? .draw
        activeView = try container.decodeIfPresent(ViewID.self, forKey: .activeView) ?? .front
        drawPlaneAxis = try container.decodeIfPresent(SliceAxis.self, forKey: .drawPlaneAxis) ?? .z
        transformPivotMode = try container.decodeIfPresent(PivotMode.self, forKey: .transformPivotMode) ?? .selection
        gridSnapEnabled = try container.decodeIfPresent(Bool.self, forKey: .gridSnapEnabled) ?? false
        gridSnapStep = try container.decodeIfPresent(Double.self, forKey: .gridSnapStep) ?? 0.04
        angleSnapEnabled = try container.decodeIfPresent(Bool.self, forKey: .angleSnapEnabled) ?? false
        angleSnapDegrees = try container.decodeIfPresent(Double.self, forKey: .angleSnapDegrees) ?? 15
        mirrorDraw = try container.decodeIfPresent(Bool.self, forKey: .mirrorDraw) ?? false
        smoothMeshView = try container.decodeIfPresent(Bool.self, forKey: .smoothMeshView) ?? true
        autoFillClosedStroke = try container.decodeIfPresent(Bool.self, forKey: .autoFillClosedStroke) ?? false
        stabilizerEnabled = try container.decodeIfPresent(Bool.self, forKey: .stabilizerEnabled) ?? true
        stabilizerMode = try container.decodeIfPresent(StabilizerMode.self, forKey: .stabilizerMode) ?? .realtime
        stabilizerStrength = try container.decodeIfPresent(Double.self, forKey: .stabilizerStrength) ?? 0.45
        stylusPalmRejectionEnabled = try container.decodeIfPresent(Bool.self, forKey: .stylusPalmRejectionEnabled) ?? false
        undoByTwoFingerTapEnabled = try container.decodeIfPresent(Bool.self, forKey: .undoByTwoFingerTapEnabled) ?? true
        redoByThreeFingerTapEnabled = try container.decodeIfPresent(Bool.self, forKey: .redoByThreeFingerTapEnabled) ?? true
        quickEyedropperEnabled = try container.decodeIfPresent(Bool.self, forKey: .quickEyedropperEnabled) ?? true
        quickEyedropperDelay = try container.decodeIfPresent(Double.self, forKey: .quickEyedropperDelay) ?? 0.18
        sliceEnabled = try container.decodeIfPresent(Bool.self, forKey: .sliceEnabled) ?? false
        multiSelectEnabled = try container.decodeIfPresent(Bool.self, forKey: .multiSelectEnabled) ?? false
        activeSliceLayerID = try container.decodeIfPresent(String.self, forKey: .activeSliceLayerID) ?? ""
        sliceLayers = try container.decodeIfPresent([SliceLayer].self, forKey: .sliceLayers) ?? []
        selectedStrokeIDs = try container.decodeIfPresent([UUID].self, forKey: .selectedStrokeIDs) ?? []
        mainCameraState = try container.decodeIfPresent(EditorCameraState.self, forKey: .mainCameraState) ?? .front
        pipCameraState = try container.decodeIfPresent(EditorCameraState.self, forKey: .pipCameraState) ?? .isometric
        showPIP = try container.decodeIfPresent(Bool.self, forKey: .showPIP) ?? true
        pipOffsetX = try container.decodeIfPresent(Double.self, forKey: .pipOffsetX) ?? 0
        pipOffsetY = try container.decodeIfPresent(Double.self, forKey: .pipOffsetY) ?? 0
        savedAtMillis = try container.decodeIfPresent(Int64.self, forKey: .savedAtMillis) ?? Int64(Date().timeIntervalSince1970 * 1000)
    }
}

private struct WrappingRow<Item: Hashable, Content: View>: View {
    let items: [Item]
    let content: (Item) -> Content

    init(items: [Item], @ViewBuilder content: @escaping (Item) -> Content) {
        self.items = items
        self.content = content
    }

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 60), spacing: 6)], spacing: 6) {
            ForEach(items, id: \.self) { item in
                content(item)
            }
        }
    }
}

private extension DrawTool {
    var localizedLabel: String {
        switch self {
        case .freeDraw:
            return "그리기"
        case .fill:
            return "채우기"
        case .erase:
            return "지우기"
        }
    }

    var symbolName: String {
        switch self {
        case .freeDraw:
            return "pencil.tip"
        case .fill:
            return "paintbrush.fill"
        case .erase:
            return "eraser.fill"
        }
    }
}

private extension ViewID {
    var localizedLabel: String {
        switch self {
        case .front:
            return "정면"
        case .back:
            return "후면"
        case .left:
            return "좌측"
        case .right:
            return "우측"
        case .top:
            return "상단"
        }
    }
}

private extension Color {
    static var platformGroupedBackground: Color {
        #if os(iOS)
        Color(UIColor.systemGroupedBackground)
        #elseif os(macOS)
        Color(NSColor.windowBackgroundColor)
        #else
        Color.gray.opacity(0.12)
        #endif
    }

    static var platformSecondaryGroupedBackground: Color {
        #if os(iOS)
        Color(UIColor.secondarySystemGroupedBackground)
        #elseif os(macOS)
        Color(NSColor.controlBackgroundColor)
        #else
        Color.gray.opacity(0.16)
        #endif
    }

    static var platformTertiaryGroupedBackground: Color {
        #if os(iOS)
        Color(UIColor.tertiarySystemGroupedBackground)
        #elseif os(macOS)
        Color(NSColor.textBackgroundColor)
        #else
        Color.gray.opacity(0.2)
        #endif
    }

    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        let value = UInt64(cleaned, radix: 16) ?? 0x3B82F6
        let r = Double((value >> 16) & 0xFF) / 255.0
        let g = Double((value >> 8) & 0xFF) / 255.0
        let b = Double(value & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}

private extension View {
    @ViewBuilder
    func platformInlineNavigationTitle() -> some View {
        #if os(iOS)
        self.navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }
}

private extension ToolbarItemPlacement {
    static var studioLeadingPlacement: ToolbarItemPlacement {
        #if os(iOS)
        .topBarLeading
        #else
        .automatic
        #endif
    }

    static var studioTrailingPlacement: ToolbarItemPlacement {
        #if os(iOS)
        .topBarTrailing
        #else
        .automatic
        #endif
    }
}

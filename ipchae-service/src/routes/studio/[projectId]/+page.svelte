<script lang="ts">
	import { goto } from '$app/navigation';
	import { base } from '$app/paths';
	import { page } from '$app/state';
	import { onDestroy, onMount } from 'svelte';
	import type {
		DrawTool,
		InputMode,
		PivotMode,
		SliceAxis,
		SliceLayer,
		StartMode,
		StudioSnapshotV1,
		ViewId
	} from '$lib/core/contracts/studio';
	import type { DraftSummary, EditorStageHandle } from '$lib/core/contracts/editor-stage';
	import {
		loadStarterCatalog,
		type StarterCatalog,
		type StarterTemplate
	} from '$lib/core/catalog/starter-catalog';
	import {
		buildAsciiPly,
		buildAsciiStl,
		downloadTextFile
	} from '$lib/core/export/mesh-export-service';
	import {
		MeshImportError,
		importMeshFile,
		type MeshImportSummary
	} from '$lib/core/import/mesh-import-service';
	import { savePartFromDraft } from '$lib/core/parts/my-part-store';
	import { createProjectShareFromProject } from '$lib/core/share/share-service';
	import { loadStudioSnapshot, saveStudioSnapshot } from '$lib/core/persistence/project-snapshot-store';
	import {
		gamificationProfile,
		hydrateGamification,
		recordExportSuccess,
		recordToolUsed
	} from '$lib/core/gamification/gamification-store';
	import { validateDraftSummary, type ValidationReport } from '$lib/core/validation/validation-service';
	import {
		enqueueStudioSnapshotSync,
		studioLastSyncedAt,
		studioSyncStatus
	} from '$lib/core/sync/scene-sync-service';
	import type FixedDraftStageComponent from '$lib/stage/FixedDraftStage.svelte';

	type StageSliceOverlay = {
		id: string;
		axis: SliceAxis;
		depth: number;
		visible: boolean;
		active: boolean;
		colorHex: string;
	};

	const modeLabelMap: Record<string, string> = {
		blank: 'Blank',
		'free-draw': 'Free Draw First',
		starter: 'Starter Scaffold'
	};

	const drawTools: Array<{ id: DrawTool; label: string }> = [
		{ id: 'free-draw', label: 'Draw' },
		{ id: 'fill', label: 'Fill' },
		{ id: 'erase', label: 'Erase' }
	];

	const viewTabs: Array<{ id: ViewId; label: string }> = [
		{ id: 'front', label: 'Front' },
		{ id: 'right', label: 'Right' },
		{ id: 'top', label: 'Top' },
		{ id: 'left', label: 'Left' },
		{ id: 'back', label: 'Back' }
	];
	const sliceAxisTabs: Array<{ id: SliceAxis; label: string }> = [
		{ id: 'x', label: 'X' },
		{ id: 'y', label: 'Y' },
		{ id: 'z', label: 'Z' }
	];
	const axisToView: Record<SliceAxis, ViewId> = {
		x: 'right',
		y: 'top',
		z: 'front'
	};
	const axisColorMap: Record<SliceAxis, string> = {
		x: '#ef4444',
		y: '#22c55e',
		z: '#3b82f6'
	};
	const viewToAxis: Record<ViewId, SliceAxis> = {
		front: 'z',
		back: 'z',
		left: 'x',
		right: 'x',
		top: 'y'
	};
	const MAX_SLICE_LAYERS = 12;
	const AUTOSAVE_DEBOUNCE_MS = 2000;
	const UX_MODE_STORAGE_KEY = 'ipchae-studio-ux-mode-v1';

	type StageComponentType = typeof FixedDraftStageComponent;

	let StageComponent: StageComponentType | null = null;
	let stageRef: EditorStageHandle | null = null;
	let beginnerMode = true;
	let autosaveTimer: ReturnType<typeof setTimeout> | null = null;
	let hydrationDone = false;
	let localSaveStatus: 'idle' | 'saving' | 'saved' | 'error' = 'idle';
	let localSavedAt: number | null = null;
	let starterCatalog: StarterCatalog | null = null;
	let selectedStarterTemplateId = '';
	let starterHeadRatio = 1.45;
	let starterBodyRatio = 1;
	let starterLegRatio = 0.75;
	let starterApplyNote = '';
	let importStatus = '';
	let importSummary: MeshImportSummary | null = null;
	let importInputRef: HTMLInputElement | null = null;
	let exportFormat: 'stl' | 'ply' = 'stl';
	let validationReport: ValidationReport | null = null;
	let exportStatus = '';
	let partSaveStatus = '';
	let shareStatus = '';
	let editActionStatus = '';
	let selectedStrokeId: string | null = null;
	let selectedStrokeCount = 0;

	let brushSize = 20;
	let brushStrength = 0.28;
	let autoFillClosedStroke = false;
	let mirrorDraw = false;
	let smoothMeshView = true;
	let drawTool: DrawTool = 'free-draw';
	let transformPivotMode: PivotMode = 'selection';
	let gridSnapEnabled = false;
	let gridSnapStep = 0.12;
	let angleSnapEnabled = false;
	let angleSnapDegrees = 12;
	let moveInputX = 0;
	let moveInputY = 0;
	let moveInputZ = 0;
	let rotateInputDegrees = 12;
	let scaleInputFactor = 1.08;
	let activeView: ViewId = 'front';
	let inputMode: InputMode = 'draw';
	let sliceEnabled = false;
	let sliceLayerSeq = 0;
	let activeSliceLayerId = '';
	let sliceLayers: SliceLayer[] = [
		createSliceLayer('z'),
		createSliceLayer('x'),
		createSliceLayer('y')
	];
	activeSliceLayerId = sliceLayers[0]?.id ?? '';

	const paletteColors = [
		'#111827',
		'#334155',
		'#ef4444',
		'#f97316',
		'#f59e0b',
		'#22c55e',
		'#06b6d4',
		'#3b82f6',
		'#6366f1',
		'#8b5cf6',
		'#ec4899',
		'#f43f5e',
		'#f1d3b3',
		'#d5a97a',
		'#7c5132',
		'#ffffff'
	];
	const quickPalette = paletteColors.slice(0, 12);
	let brushColorHex = '#3b82f6';

	onMount(async () => {
		const projectId = page.params.projectId;
		if (!projectId) return;
		try {
			const storedMode = localStorage.getItem(UX_MODE_STORAGE_KEY);
			if (storedMode === 'advanced') {
				beginnerMode = false;
			}
		} catch {
			// localStorage access can fail in restricted contexts.
		}
		const [snapshot, catalog, stageModule] = await Promise.all([
			loadStudioSnapshot(projectId),
			loadStarterCatalog(),
			import('$lib/stage/FixedDraftStage.svelte')
		]);
		await hydrateGamification();
		StageComponent = stageModule.default;
		starterCatalog = catalog;
		if (!selectedStarterTemplateId) {
			selectedStarterTemplateId = starterCatalog.templates[0]?.id ?? '';
		}
		if (snapshot) {
			applySnapshot(snapshot);
		}
		hydrationDone = true;
	});

	onDestroy(() => {
		if (autosaveTimer) clearTimeout(autosaveTimer);
	});

	$: brushStrengthPercent = Math.round(brushStrength * 100);
	$: startMode = resolveStartMode(page.url.searchParams.get('mode'));
	$: projectIdLabel = (page.params.projectId ?? 'local').slice(0, 8);
	$: if (!sliceLayers.find((layer) => layer.id === activeSliceLayerId) && sliceLayers.length > 0) {
		activeSliceLayerId = sliceLayers[0].id;
	}
	$: activeSliceLayer = sliceLayers.find((layer) => layer.id === activeSliceLayerId) ?? null;
	$: activeSliceAxis = activeSliceLayer?.axis ?? 'z';
	$: activeSliceDepth = activeSliceLayer?.depth ?? 0;
	$: activeLayerBlocked = sliceEnabled && (!activeSliceLayer?.visible || Boolean(activeSliceLayer?.locked));
	$: stageSliceEnabled = Boolean(sliceEnabled && activeSliceLayer);
	$: stageSliceOverlays = sliceLayers.map((layer) => ({
		id: layer.id,
		axis: layer.axis,
		depth: layer.depth,
		visible: layer.visible,
		active: layer.id === activeSliceLayerId,
		colorHex: layer.colorHex
	})) satisfies StageSliceOverlay[];
	$: localSaveLabel =
		localSaveStatus === 'saved'
			? `Local ${localSavedAt ? new Date(localSavedAt).toLocaleTimeString() : 'Saved'}`
			: localSaveStatus === 'saving'
				? 'Local Saving...'
				: localSaveStatus === 'error'
					? 'Local Save Failed'
					: 'Local Idle';
	$: remoteSyncLabel =
		$studioSyncStatus === 'synced'
			? `Cloud ${$studioLastSyncedAt ? new Date($studioLastSyncedAt).toLocaleTimeString() : 'Synced'}`
			: $studioSyncStatus === 'syncing'
				? 'Cloud Syncing...'
				: $studioSyncStatus === 'failed'
					? 'Cloud Failed'
					: 'Cloud Local';
	$: levelLabel = `Lv.${$gamificationProfile.level}`;
	$: selectedStarterTemplate =
		starterCatalog?.templates.find((template) => template.id === selectedStarterTemplateId) ?? null;
	$: validationSummaryLabel = validationReport
		? `${validationReport.errors.length} errors / ${validationReport.warnings.length} warnings`
		: 'not validated';
	$: selectedStrokeLabel =
		selectedStrokeCount > 1 ? `${selectedStrokeCount}개 선택` : selectedStrokeId ? selectedStrokeId : '없음';
	$: sliceLabel = stageSliceEnabled ? `${activeSliceAxis.toUpperCase()} ${activeSliceDepth.toFixed(2)}` : 'OFF';
	$: editContextLabel = `선택 ${selectedStrokeLabel} · Slice ${sliceLabel}${activeLayerBlocked ? ' · Layer Locked/Hidden' : ''}`;
	$: autosaveSignal = [
		page.params.projectId,
		startMode,
		selectedStarterTemplateId,
		starterHeadRatio,
		starterBodyRatio,
		starterLegRatio,
		brushSize,
		brushStrength,
		brushColorHex,
		drawTool,
		mirrorDraw,
		smoothMeshView,
		autoFillClosedStroke,
		activeView,
		inputMode,
		transformPivotMode,
		gridSnapEnabled,
		gridSnapStep,
		angleSnapEnabled,
		angleSnapDegrees,
		sliceEnabled,
		activeSliceLayerId,
		sliceLayers
	];
	$: if (hydrationDone && autosaveSignal) {
		scheduleAutosave();
	}

	function createSliceLayer(axis: SliceAxis, depth = 0): SliceLayer {
		sliceLayerSeq += 1;
		return {
			id: `slice-layer-${sliceLayerSeq}`,
			name: `${axis.toUpperCase()} Layer ${sliceLayerSeq}`,
			axis,
			depth: Math.max(-6, Math.min(6, depth)),
			visible: true,
			locked: false,
			colorHex: axisColorMap[axis]
		};
	}

	function createAnotherProject() {
		void goto(`${base}/`);
	}

	function updateSliceLayer(layerId: string, patch: Partial<SliceLayer>) {
		sliceLayers = sliceLayers.map((layer) => (layer.id === layerId ? { ...layer, ...patch } : layer));
	}

	function selectView(view: ViewId, syncActiveLayerAxis = true) {
		activeView = view;
		if (syncActiveLayerAxis && activeSliceLayer) {
			const axis = viewToAxis[view];
			updateSliceLayer(activeSliceLayer.id, {
				axis,
				colorHex: axisColorMap[axis]
			});
		}
		stageRef?.updateMainView?.(view);
	}

	function selectSliceLayer(layerId: string) {
		const layer = sliceLayers.find((item) => item.id === layerId);
		if (!layer) return;
		activeSliceLayerId = layer.id;
		selectView(axisToView[layer.axis], false);
	}

	function selectSliceAxis(axis: SliceAxis) {
		if (!activeSliceLayer) return;
		updateSliceLayer(activeSliceLayer.id, {
			axis,
			colorHex: axisColorMap[axis]
		});
		selectView(axisToView[axis], false);
	}

	function toggleSliceLayerVisible(layerId: string) {
		const layer = sliceLayers.find((item) => item.id === layerId);
		if (!layer) return;
		updateSliceLayer(layerId, { visible: !layer.visible });
	}

	function toggleSliceLayerLock(layerId: string) {
		const layer = sliceLayers.find((item) => item.id === layerId);
		if (!layer) return;
		updateSliceLayer(layerId, { locked: !layer.locked });
	}

	function addSliceLayer() {
		if (sliceLayers.length >= MAX_SLICE_LAYERS) return;
		const axis = activeSliceLayer?.axis ?? 'z';
		const depth = activeSliceLayer?.depth ?? 0;
		const nextLayer = createSliceLayer(axis, depth);
		sliceLayers = [nextLayer, ...sliceLayers];
		activeSliceLayerId = nextLayer.id;
		selectView(axisToView[nextLayer.axis], false);
	}

	function removeSliceLayer(layerId: string) {
		if (sliceLayers.length <= 1) return;
		const index = sliceLayers.findIndex((layer) => layer.id === layerId);
		if (index < 0) return;
		const nextLayers = sliceLayers.filter((layer) => layer.id !== layerId);
		if (activeSliceLayerId === layerId) {
			const nextActive = nextLayers[Math.max(0, index - 1)] ?? nextLayers[0];
			activeSliceLayerId = nextActive.id;
			selectView(axisToView[nextActive.axis], false);
		}
		sliceLayers = nextLayers;
	}

	function selectInputMode(mode: InputMode) {
		inputMode = mode;
		stageRef?.setInputMode?.(mode);
	}

	function zoomIn() {
		stageRef?.zoomMain?.(1.15);
	}

	function zoomOut() {
		stageRef?.zoomMain?.(0.87);
	}

	function setActiveSliceDepth(nextDepth: number) {
		if (!activeSliceLayer) return;
		const clamped = Math.max(-6, Math.min(6, nextDepth));
		updateSliceLayer(activeSliceLayer.id, { depth: clamped });
	}

	function nudgeSlice(delta: number) {
		setActiveSliceDepth(activeSliceDepth + delta);
	}

	function resolveStartMode(mode: string | null): StartMode {
		if (mode === 'free-draw' || mode === 'starter') return mode;
		return 'blank';
	}

	function resolvePivotMode(mode: PivotMode | undefined): PivotMode {
		if (mode === 'object' || mode === 'world' || mode === 'selection') return mode;
		return 'selection';
	}

	function resolveGridSnapStep(step: number | undefined): number {
		if (step === undefined || !Number.isFinite(step)) return 0.12;
		return Math.max(0.001, Math.min(10, step));
	}

	function resolveAngleSnapDegrees(degrees: number | undefined): number {
		if (degrees === undefined || !Number.isFinite(degrees)) return 12;
		return Math.max(0.1, Math.min(180, degrees));
	}

	function applySnapshot(snapshot: StudioSnapshotV1) {
		selectedStarterTemplateId = snapshot.starterTemplateId ?? selectedStarterTemplateId;
		starterHeadRatio = snapshot.starterProportion?.headRatio ?? starterHeadRatio;
		starterBodyRatio = snapshot.starterProportion?.bodyRatio ?? starterBodyRatio;
		starterLegRatio = snapshot.starterProportion?.legRatio ?? starterLegRatio;
		brushSize = snapshot.brushSize;
		brushStrength = snapshot.brushStrength;
		brushColorHex = snapshot.brushColorHex;
		drawTool = snapshot.drawTool;
		mirrorDraw = snapshot.mirrorDraw;
		smoothMeshView = snapshot.smoothMeshView;
		autoFillClosedStroke = snapshot.autoFillClosedStroke;
		activeView = snapshot.activeView;
		inputMode = snapshot.inputMode;
		transformPivotMode = resolvePivotMode(snapshot.transformPivotMode);
		gridSnapEnabled = snapshot.gridSnapEnabled ?? false;
		gridSnapStep = resolveGridSnapStep(snapshot.gridSnapStep);
		angleSnapEnabled = snapshot.angleSnapEnabled ?? false;
		angleSnapDegrees = resolveAngleSnapDegrees(snapshot.angleSnapDegrees);
		sliceEnabled = snapshot.sliceEnabled;

		if (snapshot.sliceLayers.length > 0) {
			sliceLayers = snapshot.sliceLayers.map((layer) => ({ ...layer }));
			sliceLayerSeq = snapshot.sliceLayers.length;
			activeSliceLayerId = snapshot.activeSliceLayerId;
		}

		selectView(snapshot.activeView, false);
		selectInputMode(snapshot.inputMode);
	}

	function buildSnapshot(): StudioSnapshotV1 | null {
		const projectId = page.params.projectId;
		if (!projectId) return null;
		return {
			schemaVersion: 1,
			projectId,
			mode: startMode,
			starterTemplateId: selectedStarterTemplateId || undefined,
			starterProportion: {
				headRatio: starterHeadRatio,
				bodyRatio: starterBodyRatio,
				legRatio: starterLegRatio
			},
			brushSize,
			brushStrength,
			brushColorHex,
			drawTool,
			mirrorDraw,
			smoothMeshView,
			autoFillClosedStroke,
			activeView,
			inputMode,
			transformPivotMode,
			gridSnapEnabled,
			gridSnapStep,
			angleSnapEnabled,
			angleSnapDegrees,
			sliceEnabled,
			activeSliceLayerId,
			sliceLayers: sliceLayers.map((layer) => ({ ...layer })),
			updatedAt: Date.now()
		};
	}

	function scheduleAutosave() {
		if (autosaveTimer) clearTimeout(autosaveTimer);
		localSaveStatus = 'saving';
		autosaveTimer = setTimeout(async () => {
			const snapshot = buildSnapshot();
			if (!snapshot) return;
			try {
				await saveStudioSnapshot(snapshot);
				enqueueStudioSnapshotSync(snapshot);
				localSavedAt = Date.now();
				localSaveStatus = 'saved';
			} catch (error) {
				console.error('[studio] autosave failed', error);
				localSaveStatus = 'error';
			}
		}, AUTOSAVE_DEBOUNCE_MS);
	}

	function applyStarterTemplate(template: StarterTemplate) {
		selectedStarterTemplateId = template.id;
		starterHeadRatio = template.defaultProportion.headRatio;
		starterBodyRatio = template.defaultProportion.bodyRatio;
		starterLegRatio = template.defaultProportion.legRatio;
		starterApplyNote = `${template.name} template applied`;
		void recordToolUsed('add-blob');
	}

	function toggleUxMode() {
		beginnerMode = !beginnerMode;
		try {
			localStorage.setItem(UX_MODE_STORAGE_KEY, beginnerMode ? 'beginner' : 'advanced');
		} catch {
			// ignore storage failures; mode still applies for this session.
		}
	}

	function triggerImport() {
		importInputRef?.click();
	}

	async function onImportFileChange(event: Event) {
		const input = event.currentTarget as HTMLInputElement;
		const file = input.files?.[0];
		if (!file) return;
		importStatus = '';
		try {
			const summary = await importMeshFile(file);
			importSummary = summary;
			importStatus = [
				`Imported ${summary.format.toUpperCase()}`,
				`v:${summary.vertexCount.toLocaleString()}`,
				`f:${summary.faceCount.toLocaleString()}`,
				`tri:${summary.triangleCount.toLocaleString()}`,
				`scale:${summary.normalization.uniformScale}`
			].join(' · ');
			await recordToolUsed('import-mesh');
		} catch (error) {
			importSummary = null;
			if (error instanceof MeshImportError) {
				importStatus = `Import failed (${error.code}): ${error.message}`;
			} else {
				importStatus = error instanceof Error ? `Import failed: ${error.message}` : 'Import failed';
			}
		} finally {
			input.value = '';
		}
	}

	function selectDrawTool(nextTool: DrawTool) {
		drawTool = nextTool;
		void recordToolUsed(nextTool);
	}

	function readDraftSummary(): DraftSummary | null {
		const summary = stageRef?.getDraftSummary?.();
		if (!summary) return null;
		return summary as DraftSummary;
	}

	function syncSelectedStrokeId() {
		selectedStrokeId = stageRef?.getSelectedStrokeId?.() ?? null;
		selectedStrokeCount = stageRef?.getSelectedStrokeIds?.().length ?? (selectedStrokeId ? 1 : 0);
	}

	function onStageSelectionChange(event: CustomEvent<{ strokeId: string | null }>) {
		selectedStrokeId = event.detail.strokeId;
		selectedStrokeCount = stageRef?.getSelectedStrokeIds?.().length ?? (selectedStrokeId ? 1 : 0);
	}

	function blockedEditMessage() {
		return '활성 Slice Layer가 숨김/잠금 상태라 편집할 수 없습니다.';
	}

	function runValidation() {
		const summary = readDraftSummary();
		if (!summary) {
			exportStatus = 'Validation failed: draft summary unavailable';
			return;
		}
		validationReport = validateDraftSummary(summary);
		if (validationReport.exportAllowed) {
			exportStatus = 'Validation passed. Export is available.';
		} else {
			exportStatus = 'Validation blocked export. Fix errors and try again.';
		}
	}

	function exportCurrent(format: 'stl' | 'ply') {
		const summary = readDraftSummary();
		if (!summary) {
			exportStatus = 'Export failed: draft summary unavailable';
			return;
		}

		validationReport = validateDraftSummary(summary);
		if (!validationReport.exportAllowed) {
			exportStatus = 'Export blocked by validation errors.';
			return;
		}

		const projectId = page.params.projectId ?? 'local-project';
		const timestamp = new Date().toISOString().replaceAll(':', '-');
		const filename = `ipchae-${projectId.slice(0, 8)}-${timestamp}.${format}`;
		const content =
			format === 'stl'
				? buildAsciiStl(summary, `ipchae_${projectId.slice(0, 8)}`)
				: buildAsciiPly(summary);
		const mimeType = format === 'stl' ? 'model/stl' : 'application/octet-stream';
		downloadTextFile(content, filename, mimeType);
		exportStatus = `${format.toUpperCase()} export completed`;
		void recordExportSuccess(projectId);
	}

	async function saveCurrentPart() {
		const summary = readDraftSummary();
		const projectId = page.params.projectId;
		if (!summary || !projectId) {
			partSaveStatus = 'Save Part failed: no draft data';
			return;
		}
		const part = await savePartFromDraft({
			projectId,
			summary,
			styleFamily: selectedStarterTemplate?.targetStyle ?? 'generic'
		});
		partSaveStatus = `Saved ${part.name} as private`;
	}

	async function createShareLink() {
		const projectId = page.params.projectId;
		if (!projectId) {
			shareStatus = 'Share failed: missing project id';
			return;
		}
		const shareSlug = await createProjectShareFromProject({
			projectId,
			title: `Project ${projectId.slice(0, 8)}`,
			description: '이걸 이용해서 고쳐보시겠어요?',
			visibility: 'unlisted',
			allowClone: true
		});
		if (!shareSlug) {
			shareStatus = 'Share failed';
			return;
		}
		const shareUrl = `${window.location.origin}${base}/share/${shareSlug}`;
		try {
			await navigator.clipboard.writeText(shareUrl);
			shareStatus = `Share copied: ${shareUrl}`;
		} catch {
			shareStatus = `Share created: ${shareUrl}`;
		}
	}

	function undoLastStroke() {
		stageRef?.undoLastStroke?.();
		syncSelectedStrokeId();
		editActionStatus = '실행취소';
	}

	function redoLastStroke() {
		stageRef?.redoLastStroke?.();
		syncSelectedStrokeId();
		editActionStatus = '다시실행';
	}

	function clearAllStrokes() {
		stageRef?.clearAllStrokes?.();
		syncSelectedStrokeId();
		editActionStatus = '전체 스트로크 삭제';
	}

	function selectLastStroke() {
		const ok = stageRef?.selectLastStroke?.();
		editActionStatus = ok ? '최근 스트로크 선택' : '선택할 스트로크가 없습니다.';
		syncSelectedStrokeId();
	}

	function selectAllStrokes() {
		const ok = stageRef?.selectAllStrokes?.();
		editActionStatus = ok ? '전체 선택 (Ctrl/Cmd+A)' : '선택할 스트로크가 없습니다.';
		syncSelectedStrokeId();
	}

	function selectStrokeGroup() {
		const ok = stageRef?.selectStrokeGroup?.();
		editActionStatus = ok ? '그룹 선택' : '선택한 메시가 그룹에 속해있지 않습니다.';
		syncSelectedStrokeId();
	}

	function groupSelectedStrokes() {
		if (activeLayerBlocked) {
			editActionStatus = blockedEditMessage();
			return;
		}
		const ok = stageRef?.groupSelectedStrokes?.();
		editActionStatus = ok ? '그룹 생성 (Ctrl/Cmd+G)' : '2개 이상 선택 후 그룹화할 수 있습니다.';
		syncSelectedStrokeId();
	}

	function ungroupSelectedStrokes() {
		if (activeLayerBlocked) {
			editActionStatus = blockedEditMessage();
			return;
		}
		const ok = stageRef?.ungroupSelectedStrokes?.();
		editActionStatus = ok ? '그룹 해제 (Ctrl/Cmd+Shift+G)' : '그룹 해제할 선택이 없습니다.';
		syncSelectedStrokeId();
	}

	function copySelectedStroke() {
		const ok = stageRef?.copySelectedStroke?.();
		editActionStatus = ok ? '선택 복사 완료 (Ctrl/Cmd+C)' : '선택된 스트로크가 없습니다.';
		syncSelectedStrokeId();
	}

	function pasteStroke() {
		if (activeLayerBlocked) {
			editActionStatus = blockedEditMessage();
			return;
		}
		const ok = stageRef?.pasteCopiedStroke?.();
		editActionStatus = ok ? '붙여넣기 완료 (Ctrl/Cmd+V)' : '클립보드가 비어 있습니다.';
		syncSelectedStrokeId();
	}

	function cutSelectedStroke() {
		if (activeLayerBlocked) {
			editActionStatus = blockedEditMessage();
			return;
		}
		const ok = stageRef?.cutSelectedStroke?.();
		editActionStatus = ok ? '잘라내기 완료 (Ctrl/Cmd+X)' : '선택된 스트로크가 없습니다.';
		syncSelectedStrokeId();
	}

	function duplicateSelectedStroke() {
		if (activeLayerBlocked) {
			editActionStatus = blockedEditMessage();
			return;
		}
		const ok = stageRef?.duplicateSelectedStroke?.();
		editActionStatus = ok ? '복제 완료 (Ctrl/Cmd+D)' : '선택된 스트로크가 없습니다.';
		syncSelectedStrokeId();
	}

	function deleteSelectedStroke() {
		if (activeLayerBlocked) {
			editActionStatus = blockedEditMessage();
			return;
		}
		const ok = stageRef?.deleteSelectedStroke?.();
		editActionStatus = ok ? '삭제 완료 (Delete/Backspace)' : '선택된 스트로크가 없습니다.';
		syncSelectedStrokeId();
	}

	function insertPrimitive(kind: 'sphere' | 'box' | 'cylinder') {
		if (activeLayerBlocked) {
			editActionStatus = blockedEditMessage();
			return;
		}
		const ok = stageRef?.insertPrimitiveMesh?.(kind);
		const label = kind === 'sphere' ? 'Sphere' : kind === 'box' ? 'Box' : 'Cylinder';
		editActionStatus = ok ? `${label} 프리미티브 생성` : '프리미티브를 생성할 수 없습니다.';
		syncSelectedStrokeId();
	}

	function clearStrokeSelection() {
		stageRef?.clearStrokeSelection?.();
		editActionStatus = '선택 해제';
		syncSelectedStrokeId();
	}

	function nudgeSelection(deltaU: number, deltaV: number, deltaN = 0) {
		if (activeLayerBlocked) {
			editActionStatus = blockedEditMessage();
			return;
		}
		const ok = stageRef?.nudgeSelectedStroke?.(deltaU, deltaV, deltaN);
		editActionStatus = ok
			? `이동 (${deltaU.toFixed(2)}, ${deltaV.toFixed(2)}, ${deltaN.toFixed(2)})`
			: '선택된 스트로크가 없습니다.';
		syncSelectedStrokeId();
	}

	function scaleSelection(scaleFactor: number) {
		if (activeLayerBlocked) {
			editActionStatus = blockedEditMessage();
			return;
		}
		const ok = stageRef?.scaleSelectedStroke?.(scaleFactor);
		editActionStatus = ok ? `스케일 x${scaleFactor.toFixed(2)}` : '선택된 스트로크가 없습니다.';
		syncSelectedStrokeId();
	}

	function rotateSelection(degrees: number) {
		if (activeLayerBlocked) {
			editActionStatus = blockedEditMessage();
			return;
		}
		const ok = stageRef?.rotateSelectedStroke?.(degrees);
		editActionStatus = ok ? `회전 ${degrees > 0 ? '+' : ''}${degrees}°` : '선택된 스트로크가 없습니다.';
		syncSelectedStrokeId();
	}

	function applyNumericMove() {
		if (activeLayerBlocked) {
			editActionStatus = blockedEditMessage();
			return;
		}
		const ok = stageRef?.translateSelectedStroke?.(moveInputX, moveInputY, moveInputZ);
		editActionStatus = ok
			? `수치 이동 (${moveInputX.toFixed(2)}, ${moveInputY.toFixed(2)}, ${moveInputZ.toFixed(2)})`
			: '선택된 스트로크가 없습니다.';
		syncSelectedStrokeId();
	}

	function applyNumericRotate() {
		if (activeLayerBlocked) {
			editActionStatus = blockedEditMessage();
			return;
		}
		const ok = stageRef?.rotateSelectedStroke?.(rotateInputDegrees);
		editActionStatus = ok ? `수치 회전 ${rotateInputDegrees.toFixed(1)}°` : '선택된 스트로크가 없습니다.';
		syncSelectedStrokeId();
	}

	function applyNumericScale() {
		if (activeLayerBlocked) {
			editActionStatus = blockedEditMessage();
			return;
		}
		const ok = stageRef?.scaleSelectedStroke?.(scaleInputFactor);
		editActionStatus = ok ? `수치 스케일 x${scaleInputFactor.toFixed(3)}` : '선택된 스트로크가 없습니다.';
		syncSelectedStrokeId();
	}

	function setPivotMode(mode: PivotMode) {
		transformPivotMode = mode;
		editActionStatus =
			mode === 'object' ? 'Pivot: Object' : mode === 'selection' ? 'Pivot: Selection' : 'Pivot: World';
	}

	function resetSelectionTransform() {
		if (activeLayerBlocked) {
			editActionStatus = blockedEditMessage();
			return;
		}
		const ok = stageRef?.resetSelectedStrokeTransform?.();
		editActionStatus = ok ? '트랜스폼 초기화' : '초기화할 선택 스트로크가 없습니다.';
		syncSelectedStrokeId();
	}

	function planeCutSelection(keepSide: 'largest' | 'positive' | 'negative') {
		if (activeLayerBlocked) {
			editActionStatus = blockedEditMessage();
			return;
		}
		const ok = stageRef?.planeCutSelectedStroke?.(keepSide);
		editActionStatus = ok
			? keepSide === 'positive'
				? 'Plane Cut + 적용'
				: keepSide === 'negative'
					? 'Plane Cut - 적용'
					: 'Plane Cut(큰 쪽 유지) 적용'
			: sliceEnabled
				? '컷팅 결과가 없습니다. 슬라이스 위치를 조정하세요.'
				: '슬라이스 모드를 켜야 컷팅할 수 있습니다.';
		syncSelectedStrokeId();
	}

	function sliceCutSelection() {
		planeCutSelection('largest');
	}
</script>

<sp-theme class="studio-theme" system="spectrum-two" color="dark" scale="large">
	<main class="studio-pro">
		<header class="studio-appbar">
			<div class="appbar-group brand-group">
				<button type="button" class="app-icon-btn" on:click={createAnotherProject} aria-label="Projects">
					≡
				</button>
				<div class="brand-stack">
					<p class="brand">IPCHAE</p>
					<p class="project-name">Project {projectIdLabel}</p>
					<p class="level-badge">{levelLabel}</p>
				</div>
			</div>

			<div class="appbar-group action-group">
				<span class="mode-pill">{modeLabelMap[startMode] ?? 'Blank'}</span>
				<span class="sync-pill">{localSaveLabel}</span>
				<span class="sync-pill">{remoteSyncLabel}</span>
				<button type="button" class="app-btn mode-toggle" on:click={toggleUxMode}>
					{beginnerMode ? '초등 모드' : '고급 모드'}
				</button>
				<input
					bind:this={importInputRef}
					class="import-input"
					type="file"
					accept=".stl,.ply,.obj,.glb"
					on:change={onImportFileChange}
				/>
				{#if !beginnerMode}
					<button type="button" class="app-btn" on:click={triggerImport}>Import</button>
				{/if}
				<button type="button" class="app-btn" on:click={undoLastStroke}>실행취소</button>
				<button type="button" class="app-btn" on:click={redoLastStroke}>다시실행</button>
				<button type="button" class="app-btn" on:click={clearAllStrokes}>지우기</button>
				{#if !beginnerMode}
					<button type="button" class="app-btn" on:click={zoomOut}>-</button>
					<button type="button" class="app-btn" on:click={zoomIn}>+</button>
					<button type="button" class="app-btn" on:click={() => stageRef?.resetMainView?.()}>Reset</button>
					<button type="button" class="app-btn" on:click={saveCurrentPart}>Save Part</button>
					<button type="button" class="app-btn" on:click={createShareLink}>Share</button>
				{/if}
				<button type="button" class="app-btn primary" on:click={() => exportCurrent(exportFormat)}>
					{beginnerMode ? '내보내기' : 'Export'}
				</button>
			</div>
		</header>

		<section class="workspace-shell">
				<div class="stage-canvas">
					{#if StageComponent}
						<svelte:component
							this={StageComponent}
							bind:this={stageRef}
							on:selectionchange={onStageSelectionChange}
							bind:brushSize
							bind:brushStrength
							bind:brushColorHex
							{paletteColors}
							{autoFillClosedStroke}
							{mirrorDraw}
							{smoothMeshView}
							sliceEnabled={stageSliceEnabled}
							sliceDepth={activeSliceDepth}
							sliceLayerOverlays={stageSliceOverlays}
							drawLocked={activeLayerBlocked}
							editLocked={activeLayerBlocked}
							{drawTool}
							{transformPivotMode}
							{gridSnapEnabled}
							{gridSnapStep}
							{angleSnapEnabled}
							{angleSnapDegrees}
							showInternalChrome={false}
						/>
					{:else}
						<div class="stage-loading">Loading Stage...</div>
					{/if}
				</div>

			<aside class="overlay-panel panel-left">
				<p class="panel-title">{beginnerMode ? '도구' : 'Tools'}</p>
				{#if beginnerMode}
					<div class="mini-block kid-guide">
						<p class="mini-title">오늘의 순서</p>
						<ol>
							<li>브러시로 형태를 그려요</li>
							<li>색을 골라 꾸며요</li>
							<li>내보내기로 작품을 저장해요</li>
						</ol>
					</div>
				{/if}
				<div class="mini-block starter-block">
					<p class="mini-title">Starter</p>
					<select
						class="starter-select"
						bind:value={selectedStarterTemplateId}
						disabled={!starterCatalog || starterCatalog.templates.length === 0}
					>
						{#if !starterCatalog}
							<option>Loading...</option>
						{:else}
							{#each starterCatalog.templates as template}
								<option value={template.id}>{template.name}</option>
							{/each}
						{/if}
					</select>
					{#if !beginnerMode}
						<div class="starter-ratios">
							<label for="starter-head">Head {starterHeadRatio.toFixed(2)}</label>
							<input id="starter-head" type="range" min="1" max="2.1" step="0.01" bind:value={starterHeadRatio} />
							<label for="starter-body">Body {starterBodyRatio.toFixed(2)}</label>
							<input id="starter-body" type="range" min="0.7" max="1.4" step="0.01" bind:value={starterBodyRatio} />
							<label for="starter-leg">Leg {starterLegRatio.toFixed(2)}</label>
							<input id="starter-leg" type="range" min="0.45" max="1.25" step="0.01" bind:value={starterLegRatio} />
						</div>
					{/if}
					<button
						type="button"
						class="starter-apply-btn"
						disabled={!selectedStarterTemplate}
						on:click={() => selectedStarterTemplate && applyStarterTemplate(selectedStarterTemplate)}
					>
						{beginnerMode ? '기본 캐릭터 넣기' : 'Apply Starter'}
					</button>
					{#if starterApplyNote}
						<p class="starter-note">{starterApplyNote}</p>
					{/if}
				</div>
				{#if !beginnerMode}
					<div class="mini-block">
						<p class="mini-title">View</p>
						<div class="mini-segment" role="tablist" aria-label="View">
							{#each viewTabs as view}
								<button
									type="button"
									class="mini-btn {activeView === view.id ? 'active' : ''}"
									on:click={() => selectView(view.id)}
								>
									{view.label}
								</button>
							{/each}
						</div>
					</div>
					<div class="mini-block">
						<p class="mini-title">Input</p>
						<div class="mini-segment" role="tablist" aria-label="Input mode">
							<button
								type="button"
								class="mini-btn {inputMode === 'draw' ? 'active' : ''}"
								on:click={() => selectInputMode('draw')}
							>
								Draw
							</button>
							<button
								type="button"
								class="mini-btn {inputMode === 'pan' ? 'active' : ''}"
								on:click={() => selectInputMode('pan')}
							>
								Pan
							</button>
						</div>
					</div>
					<div class="mini-block slicer-block">
						<p class="mini-title">Slicer</p>
						<label class="toggle-row" for="slice-enabled">
							<span>Slice Mode</span>
							<input id="slice-enabled" type="checkbox" bind:checked={sliceEnabled} />
						</label>
						<div class="layer-toolbar">
							<button type="button" class="layer-add-btn" on:click={addSliceLayer} disabled={sliceLayers.length >= MAX_SLICE_LAYERS}>
								+ Layer
							</button>
							<span class="layer-count">{sliceLayers.length}/{MAX_SLICE_LAYERS}</span>
						</div>
						<div class="layer-list" role="list" aria-label="Slice layers">
							{#each sliceLayers as layer}
								<div class="layer-item {activeSliceLayerId === layer.id ? 'active' : ''}" role="listitem">
									<button
										type="button"
										class="layer-main"
										on:click={() => selectSliceLayer(layer.id)}
										aria-label={`Select ${layer.name}`}
									>
										<span class="layer-dot" style={`--layer-color:${layer.colorHex};`}></span>
										<span class="layer-name">{layer.name}</span>
										<span class="layer-meta">{layer.axis.toUpperCase()} {layer.depth.toFixed(2)}</span>
									</button>
									<div class="layer-actions">
										<button
											type="button"
											class="layer-action-btn {layer.visible ? 'on' : ''}"
											on:click={() => toggleSliceLayerVisible(layer.id)}
											aria-label={layer.visible ? 'Hide layer' : 'Show layer'}
										>
											{layer.visible ? 'Hide' : 'Show'}
										</button>
										<button
											type="button"
											class="layer-action-btn {layer.locked ? 'on' : ''}"
											on:click={() => toggleSliceLayerLock(layer.id)}
											aria-label={layer.locked ? 'Unlock layer' : 'Lock layer'}
										>
											{layer.locked ? 'Unlock' : 'Lock'}
										</button>
										<button
											type="button"
											class="layer-action-btn danger"
											on:click={() => removeSliceLayer(layer.id)}
											disabled={sliceLayers.length <= 1}
											aria-label="Remove layer"
										>
											-
										</button>
									</div>
								</div>
							{/each}
						</div>
						<div class="mini-segment" role="tablist" aria-label="Slice axis">
							{#each sliceAxisTabs as axis}
								<button
									type="button"
									class="mini-btn {activeSliceAxis === axis.id ? 'active' : ''}"
									on:click={() => selectSliceAxis(axis.id)}
									disabled={!activeSliceLayer}
								>
									{axis.label}
								</button>
							{/each}
						</div>
						<div class="slice-row">
							<button
								type="button"
								class="slice-step"
								on:click={() => nudgeSlice(-0.25)}
								disabled={!sliceEnabled}
								aria-label="Slice down"
							>
								-
							</button>
							<input
								class="slice-range"
								type="range"
								min="-6"
								max="6"
								step="0.02"
								value={activeSliceDepth}
								on:input={(event) => setActiveSliceDepth(Number((event.currentTarget as HTMLInputElement).value))}
								disabled={!sliceEnabled}
							/>
							<button
								type="button"
								class="slice-step"
								on:click={() => nudgeSlice(0.25)}
								disabled={!sliceEnabled}
								aria-label="Slice up"
							>
								+
							</button>
						</div>
						<div class="slice-meta">
							<span>{activeSliceAxis.toUpperCase()} {activeSliceDepth.toFixed(2)}</span>
							<button
								type="button"
								class="slice-reset"
								on:click={() => setActiveSliceDepth(0)}
								disabled={!sliceEnabled}
							>
								Reset
							</button>
						</div>
					</div>
				{/if}
				<div class="tool-stack {beginnerMode ? 'beginner' : ''}">
						{#each drawTools as tool}
							<button
								type="button"
								class="tool-btn {drawTool === tool.id ? 'active' : ''}"
								on:click={() => selectDrawTool(tool.id)}
							>
								{tool.label}
							</button>
					{/each}
				</div>
				<div class="mini-block edit-block">
					<p class="mini-title">{beginnerMode ? '선택/복제' : 'Edit Actions'}</p>
					<div class="edit-actions {beginnerMode ? 'beginner' : ''}">
						<button type="button" class="tool-btn" on:click={selectLastStroke}>Select</button>
						<button type="button" class="tool-btn" on:click={selectAllStrokes}>Select All</button>
						<button type="button" class="tool-btn" on:click={duplicateSelectedStroke}>Duplicate</button>
						<button type="button" class="tool-btn" on:click={copySelectedStroke}>Copy</button>
						<button type="button" class="tool-btn" on:click={pasteStroke}>Paste</button>
						{#if !beginnerMode}
							<button type="button" class="tool-btn" on:click={selectStrokeGroup}>Select Group</button>
							<button type="button" class="tool-btn" on:click={groupSelectedStrokes}>Group</button>
							<button type="button" class="tool-btn" on:click={ungroupSelectedStrokes}>Ungroup</button>
							<button type="button" class="tool-btn" on:click={cutSelectedStroke}>Cut</button>
							<button type="button" class="tool-btn" on:click={deleteSelectedStroke}>Delete</button>
							<button type="button" class="tool-btn" on:click={clearStrokeSelection}>Clear Select</button>
						{/if}
					</div>
					{#if !beginnerMode}
						<div class="transform-grid primitive-grid">
							<button type="button" class="mini-export-btn" on:click={() => insertPrimitive('sphere')}>Sphere</button>
							<button type="button" class="mini-export-btn" on:click={() => insertPrimitive('box')}>Box</button>
							<button type="button" class="mini-export-btn" on:click={() => insertPrimitive('cylinder')}>Cylinder</button>
						</div>
						<div class="mini-segment pivot-segment" role="tablist" aria-label="Transform pivot">
							<button
								type="button"
								class="mini-btn {transformPivotMode === 'selection' ? 'active' : ''}"
								on:click={() => setPivotMode('selection')}
							>
								Pivot Sel
							</button>
							<button
								type="button"
								class="mini-btn {transformPivotMode === 'object' ? 'active' : ''}"
								on:click={() => setPivotMode('object')}
							>
								Pivot Obj
							</button>
							<button
								type="button"
								class="mini-btn {transformPivotMode === 'world' ? 'active' : ''}"
								on:click={() => setPivotMode('world')}
							>
								Pivot World
							</button>
						</div>
						<div class="snap-grid">
							<label class="toggle-row compact" for="grid-snap-enabled">
								<span>Grid Snap</span>
								<input id="grid-snap-enabled" type="checkbox" bind:checked={gridSnapEnabled} />
							</label>
							<input
								class="snap-input"
								type="number"
								min="0.01"
								max="2"
								step="0.01"
								bind:value={gridSnapStep}
								disabled={!gridSnapEnabled}
								aria-label="Grid snap step"
							/>
							<label class="toggle-row compact" for="angle-snap-enabled">
								<span>Angle Snap</span>
								<input id="angle-snap-enabled" type="checkbox" bind:checked={angleSnapEnabled} />
							</label>
							<input
								class="snap-input"
								type="number"
								min="1"
								max="90"
								step="1"
								bind:value={angleSnapDegrees}
								disabled={!angleSnapEnabled}
								aria-label="Angle snap degrees"
							/>
						</div>
						<div class="transform-grid">
							<button type="button" class="mini-export-btn" on:click={() => nudgeSelection(-0.12, 0)}>Move L</button>
							<button type="button" class="mini-export-btn" on:click={() => nudgeSelection(0.12, 0)}>Move R</button>
							<button type="button" class="mini-export-btn" on:click={() => nudgeSelection(0, 0.12)}>Move U</button>
							<button type="button" class="mini-export-btn" on:click={() => nudgeSelection(0, -0.12)}>Move D</button>
							<button type="button" class="mini-export-btn" on:click={() => rotateSelection(12)}>Rotate +</button>
							<button type="button" class="mini-export-btn" on:click={() => rotateSelection(-12)}>Rotate -</button>
							<button type="button" class="mini-export-btn" on:click={() => scaleSelection(1.08)}>Scale +</button>
							<button type="button" class="mini-export-btn" on:click={() => scaleSelection(0.92)}>Scale -</button>
							<button type="button" class="mini-export-btn" on:click={resetSelectionTransform}>Reset Xform</button>
							<button type="button" class="mini-export-btn" on:click={() => planeCutSelection('positive')}>Plane Cut +</button>
							<button type="button" class="mini-export-btn" on:click={() => planeCutSelection('negative')}>Plane Cut -</button>
							<button type="button" class="mini-export-btn primary" on:click={sliceCutSelection}>Slice Cut</button>
						</div>
						<div class="numeric-panel">
							<p class="mini-title">Numeric Transform</p>
							<div class="numeric-row">
								<input type="number" step="0.01" bind:value={moveInputX} aria-label="Move X" />
								<input type="number" step="0.01" bind:value={moveInputY} aria-label="Move Y" />
								<input type="number" step="0.01" bind:value={moveInputZ} aria-label="Move Z" />
								<button type="button" class="mini-export-btn" on:click={applyNumericMove}>Move</button>
							</div>
							<div class="numeric-row">
								<input type="number" step="1" bind:value={rotateInputDegrees} aria-label="Rotate deg" />
								<button type="button" class="mini-export-btn" on:click={applyNumericRotate}>Rotate</button>
								<input type="number" step="0.01" min="0.1" bind:value={scaleInputFactor} aria-label="Scale factor" />
								<button type="button" class="mini-export-btn" on:click={applyNumericScale}>Scale</button>
							</div>
						</div>
					{/if}
					<p class="edit-help">{editContextLabel}</p>
					<p class="edit-help">Shift+Click 단일 선택 · Ctrl/Cmd+Shift+Click 추가/제거 · Ctrl/Cmd+A 전체선택</p>
					<p class="edit-help">Ctrl/Cmd+G 그룹 · Ctrl/Cmd+Shift+G 그룹해제</p>
					<p class="edit-help">Pivot 모드 + Grid/Angle Snap + Numeric Transform 지원</p>
					<p class="edit-help">Ctrl/Cmd+Z,Shift+Z,Y · Ctrl/Cmd+C,V,X,D · Delete/Backspace</p>
				</div>
				<div class="toggle-stack">
					{#if !beginnerMode}
						<label class="toggle-row" for="auto-fill">
							<span>Auto Fill</span>
							<input id="auto-fill" type="checkbox" bind:checked={autoFillClosedStroke} />
						</label>
					{/if}
					<label class="toggle-row" for="mirror-draw">
						<span>Mirror X</span>
						<input id="mirror-draw" type="checkbox" bind:checked={mirrorDraw} />
					</label>
					{#if !beginnerMode}
						<label class="toggle-row" for="smooth-mesh">
							<span>Smooth Mesh</span>
							<input id="smooth-mesh" type="checkbox" bind:checked={smoothMeshView} />
						</label>
					{/if}
				</div>
			</aside>

			<aside class="overlay-panel panel-right">
				<p class="panel-title">{beginnerMode ? '브러시' : 'Brush'}</p>
				<label class="field-label" for="size">{beginnerMode ? '굵기' : 'Size'}</label>
				<input id="size" type="range" min="1" max="60" bind:value={brushSize} />
				<p class="field-value">{Math.round(brushSize)}</p>

				{#if !beginnerMode}
					<label class="field-label" for="strength">Depth</label>
					<input id="strength" type="range" min="0.05" max="1" step="0.01" bind:value={brushStrength} />
					<p class="field-value">{brushStrengthPercent}%</p>
				{/if}

				<label class="field-label" for="brush-color">{beginnerMode ? '색상' : 'Color'}</label>
				<div class="color-row">
					<input id="brush-color" class="color-input" type="color" bind:value={brushColorHex} />
					<span class="hex-code">{brushColorHex.toUpperCase()}</span>
				</div>

				<div class="export-block">
					<p class="field-label">{beginnerMode ? '작품 저장' : 'Validation & Export'}</p>
					{#if beginnerMode}
						<button type="button" class="mini-export-btn primary beginner-export" on:click={() => exportCurrent('stl')}>
							STL 내보내기
						</button>
					{:else}
						<div class="export-row">
							<select bind:value={exportFormat}>
								<option value="stl">STL</option>
								<option value="ply">PLY</option>
							</select>
							<button type="button" class="mini-export-btn" on:click={runValidation}>Validate</button>
							<button type="button" class="mini-export-btn primary" on:click={() => exportCurrent(exportFormat)}>
								Export
							</button>
						</div>
						<p class="field-value">{validationSummaryLabel}</p>
						{#if validationReport && validationReport.all.length > 0}
							<ul class="validation-list">
								{#each validationReport.all as issue}
									<li class={issue.severity}>{issue.code}: {issue.message}</li>
								{/each}
							</ul>
						{/if}
					{/if}
					{#if exportStatus}
						<p class="export-status">{exportStatus}</p>
					{/if}
					{#if editActionStatus}
						<p class="export-status">{editActionStatus}</p>
					{/if}
					{#if !beginnerMode}
						{#if partSaveStatus}
							<p class="export-status">{partSaveStatus}</p>
						{/if}
						{#if shareStatus}
							<p class="export-status">{shareStatus}</p>
						{/if}
						{#if importStatus}
							<p class="export-status">{importStatus}</p>
						{/if}
						{#if importSummary && importSummary.warnings.length > 0}
							<ul class="validation-list">
								{#each importSummary.warnings as warning}
									<li class="warning">{warning}</li>
								{/each}
							</ul>
						{/if}
					{/if}
				</div>
			</aside>

			<div class="overlay-panel panel-bottom">
				<div class="palette-strip" role="list" aria-label="Quick palette">
					{#each quickPalette as color}
						<button
							type="button"
							class="swatch {brushColorHex === color ? 'active' : ''}"
							style={`--swatch:${color};`}
							on:click={() => (brushColorHex = color)}
							aria-label={`Color ${color}`}
						></button>
					{/each}
				</div>
			</div>
		</section>
	</main>
</sp-theme>

<style>
	:global(sp-theme.studio-theme) {
		display: block;
		width: 100vw;
		height: 100vh;
	}

	.studio-pro {
		width: 100%;
		height: 100%;
		display: grid;
		grid-template-rows: auto 1fr;
		background: radial-gradient(circle at 18% -20%, rgba(64, 78, 98, 0.35), transparent 38%), #181c23;
		color: #f5f7fb;
	}

	.studio-appbar {
		height: 58px;
		padding: 8px 12px;
		display: flex;
		justify-content: space-between;
		align-items: center;
		gap: 10px;
		border-bottom: 1px solid rgba(255, 255, 255, 0.12);
		background: rgba(20, 24, 31, 0.9);
		backdrop-filter: blur(12px);
	}

	.appbar-group {
		display: flex;
		align-items: center;
		gap: 8px;
		min-width: 0;
	}

	.brand-group {
		gap: 10px;
	}

	.app-icon-btn {
		width: 34px;
		height: 34px;
		border: 1px solid rgba(255, 255, 255, 0.14);
		border-radius: 8px;
		background: #232833;
		color: #edf2fb;
		cursor: pointer;
	}

	.brand-stack {
		display: grid;
		gap: 2px;
	}

	.brand,
	.project-name {
		margin: 0;
		line-height: 1.1;
	}

	.brand {
		font-size: 0.78rem;
		font-weight: 800;
		letter-spacing: 0.08em;
		color: #9cc8ff;
	}

	.project-name {
		font-size: 0.84rem;
		font-weight: 700;
		color: #eef3fa;
	}

	.level-badge {
		margin: 2px 0 0;
		font-size: 0.68rem;
		font-weight: 800;
		letter-spacing: 0.05em;
		color: #8fd8ff;
	}

	.action-group {
		justify-content: flex-end;
		flex-wrap: nowrap;
	}

	.import-input {
		display: none;
	}

	.mode-pill {
		padding: 4px 10px;
		border-radius: 999px;
		background: rgba(92, 255, 186, 0.16);
		border: 1px solid rgba(110, 255, 193, 0.35);
		color: #afffd7;
		font-size: 0.7rem;
		font-weight: 700;
	}

	.sync-pill {
		padding: 4px 10px;
		border-radius: 999px;
		background: rgba(59, 130, 246, 0.16);
		border: 1px solid rgba(125, 179, 255, 0.34);
		color: #cfe3ff;
		font-size: 0.68rem;
		font-weight: 700;
	}

	.app-btn {
		height: 30px;
		padding: 0 10px;
		border: 1px solid rgba(255, 255, 255, 0.16);
		border-radius: 8px;
		background: #232a36;
		color: #e7ecf8;
		font-size: 0.72rem;
		font-weight: 700;
		cursor: pointer;
	}

	.app-btn.primary {
		border-color: rgba(92, 170, 255, 0.95);
		background: #1f4f87;
		color: #f9fcff;
	}

	.app-btn.mode-toggle {
		border-color: rgba(253, 230, 138, 0.7);
		background: rgba(146, 64, 14, 0.76);
		color: #fff7dd;
	}

	.workspace-shell {
		position: relative;
		min-height: 0;
	}

	.stage-canvas {
		position: absolute;
		inset: 0;
	}

	.stage-loading {
		position: absolute;
		inset: 0;
		display: grid;
		place-items: center;
		color: #b8cae8;
		font-weight: 700;
		font-size: 0.9rem;
		letter-spacing: 0.04em;
		background: radial-gradient(circle at 20% 20%, rgba(68, 94, 127, 0.3), transparent 46%),
			#1b1f27;
	}

	.overlay-panel {
		position: absolute;
		z-index: 24;
		border: 1px solid rgba(255, 255, 255, 0.14);
		border-radius: 12px;
		background: rgba(24, 28, 35, 0.8);
		backdrop-filter: blur(11px);
		box-shadow: 0 16px 40px rgba(0, 0, 0, 0.28);
	}

	.panel-title {
		margin: 0 0 10px;
		font-size: 0.75rem;
		font-weight: 800;
		letter-spacing: 0.08em;
		text-transform: uppercase;
		color: #b4c7e7;
	}

	.panel-left {
		left: 14px;
		top: 14px;
		width: 242px;
		padding: 12px;
	}

	.mini-block {
		display: grid;
		gap: 6px;
		margin-bottom: 10px;
	}

	.kid-guide {
		padding: 8px;
		border: 1px solid rgba(253, 230, 138, 0.45);
		border-radius: 10px;
		background: rgba(120, 53, 15, 0.32);
	}

	.kid-guide ol {
		margin: 0;
		padding-left: 18px;
		display: grid;
		gap: 3px;
		font-size: 0.72rem;
		color: #fff4cf;
	}

	.starter-block {
		padding-bottom: 8px;
		border-bottom: 1px solid rgba(255, 255, 255, 0.12);
	}

	.starter-select {
		height: 30px;
		border-radius: 8px;
		border: 1px solid rgba(255, 255, 255, 0.15);
		background: rgba(35, 42, 53, 0.95);
		color: #e5eefc;
		padding: 0 8px;
		font-size: 0.72rem;
	}

	.starter-ratios {
		display: grid;
		gap: 4px;
		font-size: 0.68rem;
		color: #bacbe8;
	}

	.starter-ratios input {
		width: 100%;
	}

	.starter-apply-btn {
		height: 28px;
		border-radius: 8px;
		border: 1px solid rgba(96, 169, 255, 0.72);
		background: rgba(34, 99, 189, 0.78);
		color: #f2f7ff;
		font-weight: 700;
		font-size: 0.7rem;
		cursor: pointer;
	}

	.starter-apply-btn:disabled {
		opacity: 0.45;
		cursor: not-allowed;
	}

	.starter-note {
		margin: 0;
		font-size: 0.66rem;
		color: #9fcbff;
	}

	.slicer-block {
		padding-top: 2px;
		border-top: 1px solid rgba(255, 255, 255, 0.12);
	}

	.layer-toolbar {
		display: flex;
		align-items: center;
		justify-content: space-between;
		gap: 8px;
	}

	.layer-add-btn {
		height: 26px;
		padding: 0 8px;
		border: 1px solid rgba(255, 255, 255, 0.18);
		border-radius: 7px;
		background: #2a303b;
		color: #deebff;
		font-size: 0.68rem;
		font-weight: 700;
		cursor: pointer;
	}

	.layer-add-btn:disabled {
		opacity: 0.45;
		cursor: not-allowed;
	}

	.layer-count {
		font-size: 0.66rem;
		font-weight: 700;
		color: #91a6c8;
	}

	.layer-list {
		display: grid;
		gap: 6px;
		max-height: 180px;
		overflow: auto;
		padding-right: 2px;
	}

	.layer-item {
		display: grid;
		grid-template-columns: 1fr;
		gap: 4px;
		padding: 6px;
		border: 1px solid rgba(255, 255, 255, 0.1);
		border-radius: 8px;
		background: rgba(39, 45, 56, 0.9);
	}

	.layer-item.active {
		border-color: rgba(96, 169, 255, 0.92);
		background: rgba(35, 67, 106, 0.9);
	}

	.layer-main {
		display: grid;
		grid-template-columns: auto 1fr auto;
		align-items: center;
		gap: 6px;
		border: none;
		background: transparent;
		padding: 0;
		color: #eef4ff;
		cursor: pointer;
		text-align: left;
	}

	.layer-dot {
		width: 10px;
		height: 10px;
		border-radius: 999px;
		background: var(--layer-color);
	}

	.layer-name {
		font-size: 0.68rem;
		font-weight: 700;
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
	}

	.layer-meta {
		font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
		font-size: 0.64rem;
		font-weight: 700;
		color: #a3badf;
	}

	.layer-actions {
		display: grid;
		grid-template-columns: repeat(3, minmax(0, 1fr));
		gap: 4px;
	}

	.layer-action-btn {
		height: 22px;
		border: 1px solid rgba(255, 255, 255, 0.15);
		border-radius: 6px;
		background: #2a303b;
		color: #dbe6f7;
		font-size: 0.62rem;
		font-weight: 700;
		cursor: pointer;
	}

	.layer-action-btn.on {
		border-color: rgba(96, 169, 255, 0.82);
		background: #254469;
		color: #f4f9ff;
	}

	.layer-action-btn.danger {
		color: #f8b4bc;
	}

	.layer-action-btn:disabled {
		opacity: 0.42;
		cursor: not-allowed;
	}

	.mini-title {
		margin: 0;
		font-size: 0.68rem;
		font-weight: 800;
		letter-spacing: 0.08em;
		text-transform: uppercase;
		color: #8fa6cb;
	}

	.mini-segment {
		display: grid;
		grid-template-columns: repeat(3, minmax(0, 1fr));
		gap: 4px;
	}

	.mini-btn {
		height: 28px;
		padding: 0 6px;
		border: 1px solid rgba(255, 255, 255, 0.14);
		border-radius: 7px;
		background: #2a303b;
		color: #dbe6f7;
		font-size: 0.67rem;
		font-weight: 700;
		cursor: pointer;
	}

	.mini-btn.active {
		border-color: rgba(87, 158, 255, 0.88);
		background: #244468;
		color: #f3f8ff;
	}

	.slice-row {
		display: grid;
		grid-template-columns: 24px 1fr 24px;
		align-items: center;
		gap: 6px;
	}

	.slice-step,
	.slice-reset {
		height: 24px;
		border: 1px solid rgba(255, 255, 255, 0.16);
		border-radius: 6px;
		background: #2a303b;
		color: #dbe6f7;
		font-size: 0.7rem;
		font-weight: 800;
		cursor: pointer;
	}

	.slice-range {
		width: 100%;
	}

	.slice-meta {
		display: flex;
		align-items: center;
		justify-content: space-between;
		gap: 6px;
		font-size: 0.7rem;
		font-weight: 700;
		color: #b8c9e4;
	}

	.slice-reset {
		padding: 0 8px;
		width: auto;
	}

	.slice-step:disabled,
	.slice-reset:disabled {
		opacity: 0.45;
		cursor: not-allowed;
	}

	.tool-stack {
		display: grid;
		gap: 6px;
	}

	.tool-stack.beginner .tool-btn {
		height: 42px;
		font-size: 0.9rem;
	}

	.edit-block {
		margin-top: 8px;
		padding-top: 8px;
		border-top: 1px solid rgba(255, 255, 255, 0.12);
	}

	.edit-actions {
		display: grid;
		grid-template-columns: repeat(2, minmax(0, 1fr));
		gap: 6px;
	}

	.edit-actions.beginner {
		grid-template-columns: repeat(2, minmax(0, 1fr));
	}

	.transform-grid {
		margin-top: 8px;
		display: grid;
		grid-template-columns: repeat(3, minmax(0, 1fr));
		gap: 6px;
	}

	.primitive-grid {
		margin-top: 10px;
	}

	.pivot-segment {
		margin-top: 8px;
	}

	.snap-grid {
		margin-top: 8px;
		display: grid;
		grid-template-columns: minmax(0, 1fr) 72px;
		gap: 6px;
		align-items: center;
	}

	.toggle-row.compact {
		font-size: 0.68rem;
	}

	.snap-input {
		height: 26px;
		border-radius: 6px;
		border: 1px solid rgba(255, 255, 255, 0.15);
		background: rgba(35, 42, 53, 0.95);
		color: #e5eefc;
		padding: 0 6px;
		font-size: 0.66rem;
	}

	.numeric-panel {
		margin-top: 10px;
		display: grid;
		gap: 6px;
		padding: 8px;
		border: 1px solid rgba(255, 255, 255, 0.12);
		border-radius: 8px;
		background: rgba(24, 30, 40, 0.55);
	}

	.numeric-row {
		display: grid;
		grid-template-columns: repeat(4, minmax(0, 1fr));
		gap: 6px;
	}

	.numeric-row input {
		height: 28px;
		border-radius: 6px;
		border: 1px solid rgba(255, 255, 255, 0.15);
		background: rgba(35, 42, 53, 0.95);
		color: #e5eefc;
		padding: 0 6px;
		font-size: 0.66rem;
		min-width: 0;
	}

	.edit-help {
		margin: 8px 0 0;
		font-size: 0.64rem;
		color: #9fb3d3;
	}

	.tool-btn {
		height: 34px;
		padding: 0 10px;
		border: 1px solid rgba(255, 255, 255, 0.16);
		border-radius: 8px;
		background: #2a303b;
		color: #e5ebf8;
		font-size: 0.78rem;
		font-weight: 700;
		text-align: left;
		cursor: pointer;
	}

	.tool-btn.active {
		border-color: rgba(87, 158, 255, 0.88);
		background: #254269;
	}

	.toggle-stack {
		margin-top: 12px;
		display: grid;
		gap: 6px;
	}

	.toggle-row {
		display: flex;
		align-items: center;
		justify-content: space-between;
		gap: 10px;
		font-size: 0.74rem;
		font-weight: 700;
		color: #d2dced;
	}

	.panel-right {
		right: 14px;
		bottom: 92px;
		width: 220px;
		padding: 12px;
	}

	.field-label {
		display: block;
		margin: 0 0 4px;
		font-size: 0.72rem;
		font-weight: 700;
		color: #bbcae4;
	}

	.field-value {
		margin: 4px 0 10px;
		font-size: 0.7rem;
		font-weight: 700;
		color: #8fa2c3;
	}

	.color-row {
		display: flex;
		align-items: center;
		gap: 8px;
	}

	.color-input {
		width: 42px;
		height: 30px;
		padding: 0;
		border: 1px solid rgba(255, 255, 255, 0.2);
		border-radius: 8px;
		background: #1f2430;
	}

	.hex-code {
		font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
		font-size: 0.72rem;
		font-weight: 700;
		color: #c8d3e8;
	}

	.export-block {
		margin-top: 12px;
		padding-top: 10px;
		border-top: 1px solid rgba(255, 255, 255, 0.15);
		display: grid;
		gap: 6px;
	}

	.export-row {
		display: grid;
		grid-template-columns: 1fr auto auto;
		gap: 6px;
	}

	.export-row select {
		height: 30px;
		border-radius: 8px;
		border: 1px solid rgba(255, 255, 255, 0.15);
		background: rgba(35, 42, 53, 0.95);
		color: #e5eefc;
		padding: 0 8px;
		font-size: 0.72rem;
	}

	.mini-export-btn {
		height: 30px;
		padding: 0 8px;
		border: 1px solid rgba(255, 255, 255, 0.18);
		border-radius: 8px;
		background: #2a303b;
		color: #deebff;
		font-size: 0.68rem;
		font-weight: 700;
		cursor: pointer;
	}

	.mini-export-btn.primary {
		border-color: rgba(96, 169, 255, 0.82);
		background: rgba(35, 87, 160, 0.84);
	}

	.beginner-export {
		height: 36px;
		font-size: 0.8rem;
	}

	.validation-list {
		margin: 0;
		padding-left: 16px;
		display: grid;
		gap: 4px;
		font-size: 0.66rem;
	}

	.validation-list li.error {
		color: #fecaca;
	}

	.validation-list li.warning {
		color: #fde68a;
	}

	.export-status {
		margin: 0;
		font-size: 0.66rem;
		color: #9fcbff;
	}

	.panel-bottom {
		left: 50%;
		transform: translateX(-50%);
		bottom: 14px;
		padding: 10px 12px;
		width: min(720px, calc(100% - 258px));
	}

	.palette-strip {
		display: grid;
		grid-template-columns: repeat(12, minmax(0, 1fr));
		gap: 8px;
	}

	.swatch {
		width: 100%;
		aspect-ratio: 1 / 1;
		border-radius: 9px;
		border: 1px solid rgba(255, 255, 255, 0.16);
		background: var(--swatch);
		cursor: pointer;
	}

	.swatch.active {
		outline: 2px solid #82bdff;
		outline-offset: 1px;
	}

	@media (max-width: 1200px) {
		.studio-appbar {
			height: 54px;
			padding: 8px 10px;
		}

		.action-group {
			justify-content: flex-start;
			gap: 6px;
		}

		.panel-bottom {
			width: min(640px, calc(100% - 238px));
		}
	}

	@media (max-width: 900px) {
		.panel-left {
			width: 210px;
		}

		.panel-right {
			width: 192px;
		}

		.mode-pill,
		.sync-pill {
			display: none;
		}

		.panel-bottom {
			left: 12px;
			right: 12px;
			transform: none;
			width: auto;
		}
	}

	@media (max-width: 740px) {
		.workspace-shell {
			padding: 0;
		}

		.panel-left,
		.panel-right {
			display: none;
		}

		.panel-bottom {
			left: 8px;
			right: 8px;
			bottom: 8px;
		}

		.palette-strip {
			grid-template-columns: repeat(8, minmax(0, 1fr));
			gap: 6px;
		}

		.app-btn {
			height: 34px;
		}

		.studio-appbar {
			height: auto;
			flex-wrap: wrap;
		}

		.brand-group {
			width: 100%;
		}

		.action-group {
			width: 100%;
			justify-content: flex-start;
			flex-wrap: wrap;
		}
	}
</style>

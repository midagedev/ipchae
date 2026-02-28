<script lang="ts">
	import { createEventDispatcher, onDestroy, onMount } from 'svelte';
	import type { DraftBounds, DraftExportDot, DraftSummary } from '$lib/core/contracts/editor-stage';
	import * as THREE from 'three';
	import { OrbitControls } from 'three/examples/jsm/controls/OrbitControls.js';
	import { MarchingCubes } from 'three/examples/jsm/objects/MarchingCubes.js';

	type ViewId = 'front' | 'back' | 'left' | 'right' | 'top';
	type SliceAxis = 'x' | 'y' | 'z';

	type ViewConfig = {
		label: string;
		position: [number, number, number];
		up: [number, number, number];
		normal: [number, number, number];
	};
	type SliceLayerOverlay = {
		id: string;
		axis: SliceAxis;
		depth: number;
		visible?: boolean;
		active?: boolean;
		colorHex?: string;
	};

	const VIEW_CONFIGS: Record<ViewId, ViewConfig> = {
		front: {
			label: 'Front',
			position: [0, 0, 8],
			up: [0, 1, 0],
			normal: [0, 0, 1]
		},
		back: {
			label: 'Back',
			position: [0, 0, -8],
			up: [0, 1, 0],
			normal: [0, 0, -1]
		},
		left: {
			label: 'Left',
			position: [-8, 0, 0],
			up: [0, 1, 0],
			normal: [-1, 0, 0]
		},
		right: {
			label: 'Right',
			position: [8, 0, 0],
			up: [0, 1, 0],
			normal: [1, 0, 0]
		},
		top: {
			label: 'Top',
			position: [0, 8, 0],
			up: [0, 0, -1],
			normal: [0, 1, 0]
		}
	};
	const AXIS_NORMALS: Record<SliceAxis, THREE.Vector3> = {
		x: new THREE.Vector3(1, 0, 0),
		y: new THREE.Vector3(0, 1, 0),
		z: new THREE.Vector3(0, 0, 1)
	};
	const AXIS_UPS: Record<SliceAxis, THREE.Vector3> = {
		x: new THREE.Vector3(0, 1, 0),
		y: new THREE.Vector3(0, 0, -1),
		z: new THREE.Vector3(0, 1, 0)
	};

	const viewOrder: ViewId[] = ['front', 'right', 'top', 'left', 'back'];

	export let brushSize = 20;
	export let brushStrength = 0.28;
	export let brushColorHex = '#2563eb';
	export let paletteColors: string[] = [];
	export let autoFillClosedStroke = false;
	export let mirrorDraw = false;
	export let smoothMeshView = true;
	export let showInternalChrome = true;
	export let sliceEnabled = false;
	export let sliceDepth = 0;
	export let sliceLayerOverlays: SliceLayerOverlay[] = [];
	export let drawLocked = false;
	export let editLocked = false;
	export let drawTool: DrawTool = 'free-draw';

	type DrawTool = 'free-draw' | 'fill' | 'erase';
	type PrimitiveKind = 'sphere' | 'box' | 'cylinder';
	type InputMode = 'draw' | 'pan';
	type BrushDotMesh = THREE.Mesh<THREE.SphereGeometry, THREE.MeshStandardMaterial>;
	type SmoothSurfaceMesh = MarchingCubes;
	type StrokeDot = {
		id: string;
		mesh: BrushDotMesh;
		basePoint: THREE.Vector3;
		position: THREE.Vector3;
		u: number;
		v: number;
		height: number;
		radius: number;
		depositRadius: number;
		depositAmount: number;
		view: ViewId;
		strokeId: string;
	};
	type StrokeSnapshotDot = {
		basePoint: [number, number, number];
		radius: number;
		depositRadius: number;
		depositAmount: number;
		view: ViewId;
		colorHex: string;
	};
	type StrokeSnapshot = {
		strokeId: string;
		dots: StrokeSnapshotDot[];
	};
	type EraseChange = {
		dotId: string;
		beforeAmount: number;
		afterAmount: number;
	};
	type HistoryEntry =
		| {
				kind: 'draw';
				snapshot: StrokeSnapshot;
		  }
		| {
				kind: 'erase';
				changes: EraseChange[];
		  }
		| {
				kind: 'delete';
				snapshot: StrokeSnapshot;
		  }
		| {
				kind: 'snapshot';
				strokeId: string;
				before: StrokeSnapshot;
				after: StrokeSnapshot | null;
		  };

	let activeView: ViewId = 'front';
	let cameraLock = true;
	let inputMode: InputMode = 'draw';
	let isCoarsePointer = false;

	let mainWrap: HTMLDivElement | undefined;
	let mainCanvas: HTMLCanvasElement | undefined;
	let pipCanvas: HTMLCanvasElement | undefined;
	let pipWrap: HTMLDivElement | undefined;

	let mainRenderer: THREE.WebGLRenderer | null = null;
	let pipRenderer: THREE.WebGLRenderer | null = null;
	let scene: THREE.Scene | null = null;
	let mainCamera: THREE.OrthographicCamera | null = null;
	let pipCamera: THREE.PerspectiveCamera | null = null;
	let pipControls: OrbitControls | null = null;
	let smoothSurface: SmoothSurfaceMesh | null = null;
	let smoothSurfaceMaterial: THREE.MeshStandardMaterial | null = null;
	let smoothSurfaceDirty = true;

	let animationFrame = 0;
	let resizeObserver: ResizeObserver | null = null;

	let guidePlane: THREE.Mesh<THREE.PlaneGeometry, THREE.MeshBasicMaterial> | null = null;
	let guideGrid: THREE.LineSegments<THREE.BufferGeometry, THREE.LineBasicMaterial> | null = null;
	let guideAxes: THREE.Group | null = null;
	let pipSliceOverlayGroup: THREE.Group | null = null;
	const drawPlane = new THREE.Plane(new THREE.Vector3(0, 0, 1), 0);
	const activeNormal = new THREE.Vector3(...VIEW_CONFIGS.front.normal).normalize();
	const activeTangentU = new THREE.Vector3(1, 0, 0);
	const activeTangentV = new THREE.Vector3(0, 1, 0);
	const raycaster = new THREE.Raycaster();
	const pointer = new THREE.Vector2();
	const stageTarget = new THREE.Vector3(0, 0, 0);
	const tmpSampleDelta = new THREE.Vector3();
	const tmpEraseDelta = new THREE.Vector3();
	const tmpSlicePoint = new THREE.Vector3();

	const strokeRoot = new THREE.Group();
	const actionHistory: HistoryEntry[] = [];
	const redoHistory: HistoryEntry[] = [];
	const strokeDots: StrokeDot[] = [];
	const strokeOriginSnapshots = new Map<string, StrokeSnapshot>();
	const dispatch = createEventDispatcher<{
		selectionchange: { strokeId: string | null };
	}>();
	let selectedStrokeId: string | null = null;
	const selectedStrokeIds = new Set<string>();
	let clipboardStrokeSnapshots: StrokeSnapshot[] = [];
	let pasteSerial = 0;
	const stackHeightMaps: Record<ViewId, Map<string, number>> = {
		front: new Map(),
		back: new Map(),
		left: new Map(),
		right: new Map(),
		top: new Map()
	};
	const wetnessMaps: Record<ViewId, Map<string, number>> = {
		front: new Map(),
		back: new Map(),
		left: new Map(),
		right: new Map(),
		top: new Map()
	};
	const unitSphere = new THREE.SphereGeometry(1, 14, 14);

	let activeStroke: THREE.Group | null = null;
	let lastSurfacePoint: THREE.Vector3 | null = null;
	const strokeInputPoints: THREE.Vector3[] = [];
	let lastSmoothedPoint: THREE.Vector3 | null = null;
	let strokeSupportMap: Map<string, number> | null = null;
	let strokeSupportView: ViewId | null = null;
	let activeStrokeTool: DrawTool = 'free-draw';
	let lastEraseSurfacePoint: THREE.Vector3 | null = null;
	let lastRawStrokePoint: THREE.Vector3 | null = null;
	let strokeArcCarry = 0;
	let flowPauseSec = 0;
	let eraseDotSeq = 0;
	const pendingEraseChanges = new Map<string, EraseChange>();
	let isDrawing = false;
	let isPanning = false;
	let panStartX = 0;
	let panStartY = 0;
	let pipViewportWidth = 220;
	let pipViewportHeight = 145;
	let pipPosX = 12;
	let pipPosY = 12;
	let pipMovedByUser = false;
	let pipDragging = false;
	let pipDragPointerId = -1;
	let pipDragOffsetX = 0;
	let pipDragOffsetY = 0;
	let pipDragCaptureEl: HTMLElement | null = null;

	const ORTHO_HALF_HEIGHT = 5.5;
	const MIN_ZOOM = 0.55;
	const MAX_ZOOM = 6;
	const PIP_MARGIN = 8;
	const PIP_SLICE_LAYER = 1;
	const SLICE_DEPTH_MIN = -6;
	const SLICE_DEPTH_MAX = 6;
	const STACK_CELL_SIZE = 0.1;
	const PATH_SAMPLE_STEP_RATIO = 0.3;
	const MIN_PATH_SAMPLE_STEP = 0.009;
	const MAX_PATH_STEPS = 260;
	const ARC_RESAMPLE_STEP_RATIO = 0.22;
	const ARC_RESAMPLE_MIN_STEP = 0.006;
	const FLOW_NEIGHBORS: Array<[number, number]> = [
		[1, 0],
		[-1, 0],
		[0, 1],
		[0, -1]
	];
	const SAND_REPOSE_GRADIENT = Math.tan(THREE.MathUtils.degToRad(30));
	const FLOW_RATE = 6.4;
	const FLOW_ITERATIONS = 3;
	const FLOW_HARDEN_TAU = 0.9;
	const FLOW_MIN_WETNESS = 0.016;
	const FLOW_MAX_TRANSFER_RATIO = 0.68;
	const FLOW_CARRY_RATIO = 0.95;
	const FLOW_PAUSE_AFTER_STROKE_SEC = 0.16;
	const SMOOTH_MESH_RESOLUTION = 48;
	const SMOOTH_MESH_MAX_POLYGONS = 120000;
	const SMOOTH_MESH_PADDING = 0.24;
	const SMOOTH_MESH_MIN_SPAN = 1.2;
	const SMOOTH_MESH_MAX_BALLS = 1800;
	const SMOOTH_MESH_ISOLATION = 68;
	const SMOOTH_MESH_SUBTRACT = 12;
	const AUTO_FILL_MIN_POINTS = 16;
	const AUTO_FILL_CLOSE_DISTANCE_FACTOR = 1.8;
	const AUTO_FILL_CLOSE_DISTANCE_MIN = 0.12;
	const AUTO_FILL_STEP_RATIO = 0.72;
	const AUTO_FILL_MIN_STEP = 0.02;
	const AUTO_FILL_MAX_SAMPLES = 2400;
	const AUTO_FILL_MIN_AREA_FACTOR = 7;
	const BRUSH_WIDTH_SCALE = 1.2;
	const BRUSH_DEPTH_SCALE = 0.42;
	const BRUSH_DEPOSIT_RADIUS_SCALE = 1.18;
	const FILL_TOOL_RADIUS_SCALE = 1.34;
	const FILL_TOOL_DEPTH_SCALE = 0.62;
	const FILL_TOOL_RADIUS_SPREAD = 1.35;
	const FILL_TOOL_SPACING_RATIO = 0.1;
	const FILL_TOOL_STEP_SCALE = 0.72;
	const STAMP_DEPTH_BOOST = 2.1;
	const STAMP_RADIUS_SHRINK = 0.84;
	const STAMP_WETNESS_SCALE = 0.38;
	const ERASER_RADIUS_SCALE = 1.4;
	const ERASER_DEPTH_RANGE_SCALE = 1.7;
	const ERASER_POWER_SCALE = 0.38;
	const ERASER_POINT_SPACING_RATIO = 0.16;
	const ERASER_SEGMENT_STEP_RATIO = 0.4;
	const MIRROR_AXIS_EPSILON_SQ = 1e-8;
	const CROSS_VIEW_SUPPORT_RADIUS_SCALE = 0.72;
	const CROSS_VIEW_SUPPORT_HEADROOM_SCALE = 0.95;

	$: brushRadius = (0.02 + (Math.max(1, Math.min(brushSize, 60)) / 60) * 0.18) * BRUSH_WIDTH_SCALE;
	$: brushRoughness = THREE.MathUtils.clamp(0.7 - brushStrength * 0.35, 0.2, 0.75);
	$: quickPalette =
		(paletteColors.length
			? paletteColors
			: ['#111827', '#ef4444', '#f59e0b', '#22c55e', '#06b6d4', '#3b82f6', '#8b5cf6', '#ffffff']
		).slice(0, 10);

	$: if (smoothMeshView !== undefined) {
		syncDotVisibilityByRenderMode();
		markSmoothSurfaceDirty();
	}

	$: {
		sliceEnabled;
		sliceDepth;
		sliceLayerOverlays;
		if (mainCamera) {
			syncDrawPlane();
			syncGuideAnchorsToSlice();
			syncPipSliceOverlays();
		}
	}

	function markSmoothSurfaceDirty() {
		smoothSurfaceDirty = true;
	}

	function isDotVisible(dot: StrokeDot) {
		if (dot.depositAmount <= 1e-6) return false;
		if (!smoothMeshView) return true;
		return selectedStrokeIds.has(dot.strokeId);
	}

	function syncDotVisibilityByRenderMode() {
		for (const dot of strokeDots) {
			dot.mesh.visible = isDotVisible(dot);
		}
	}

	function resolveBrushColor() {
		const color = new THREE.Color();
		color.set(brushColorHex || '#2563eb');
		return color;
	}

	function getActiveSliceOffset() {
		if (!sliceEnabled) return 0;
		return THREE.MathUtils.clamp(sliceDepth, SLICE_DEPTH_MIN, SLICE_DEPTH_MAX);
	}

	function getActiveSlicePoint() {
		return tmpSlicePoint.copy(stageTarget).addScaledVector(activeNormal, getActiveSliceOffset());
	}

	function syncGuideAnchorsToSlice() {
		const slicePoint = getActiveSlicePoint();
		guidePlane?.position.copy(slicePoint);
		guideGrid?.position.copy(slicePoint);
		guideAxes?.position.copy(slicePoint);
		pipSliceOverlayGroup?.position.copy(stageTarget);
	}

	function applyLayerRecursive(target: THREE.Object3D, layer: number) {
		target.layers.set(layer);
		for (const child of target.children) {
			applyLayerRecursive(child, layer);
		}
	}

	function getAxisBasis(axis: SliceAxis) {
		const normal = AXIS_NORMALS[axis].clone().normalize();
		const tangentV = AXIS_UPS[axis].clone().normalize();
		tangentV.addScaledVector(normal, -tangentV.dot(normal)).normalize();
		const tangentU = new THREE.Vector3().crossVectors(tangentV, normal).normalize();
		return { normal, tangentU, tangentV };
	}

	function disposePipSliceOverlay() {
		if (!pipSliceOverlayGroup) return;
		scene?.remove(pipSliceOverlayGroup);
		pipSliceOverlayGroup.traverse((object) => {
			if (object instanceof THREE.Mesh) {
				object.geometry.dispose();
				if (Array.isArray(object.material)) {
					for (const item of object.material) item.dispose();
				} else {
					object.material.dispose();
				}
			}
			if (object instanceof THREE.Line || object instanceof THREE.LineSegments) {
				object.geometry.dispose();
				if (Array.isArray(object.material)) {
					for (const item of object.material) item.dispose();
				} else {
					object.material.dispose();
				}
			}
		});
		pipSliceOverlayGroup = null;
	}

	function syncPipSliceOverlays() {
		if (!scene) return;

		disposePipSliceOverlay();
		if (!sliceEnabled) return;

		const visibleLayers = sliceLayerOverlays.filter((layer) => layer.visible !== false);
		if (!visibleLayers.length) return;

		const overlaysGroup = new THREE.Group();
		overlaysGroup.position.copy(stageTarget);
		for (const layer of visibleLayers) {
			const { normal, tangentU, tangentV } = getAxisBasis(layer.axis);
			const layerDepth = THREE.MathUtils.clamp(layer.depth, SLICE_DEPTH_MIN, SLICE_DEPTH_MAX);
			const baseColor = new THREE.Color(layer.colorHex || '#3b82f6');
			const active = Boolean(layer.active);
			const layerGroup = new THREE.Group();
			layerGroup.position.copy(normal).multiplyScalar(layerDepth);
			layerGroup.quaternion.setFromRotationMatrix(
				new THREE.Matrix4().makeBasis(tangentU, tangentV, normal)
			);

			const overlayPlaneGeometry = new THREE.PlaneGeometry(16, 16);
			const overlayPlane = new THREE.Mesh(
				overlayPlaneGeometry,
				new THREE.MeshBasicMaterial({
					color: baseColor,
					transparent: true,
					opacity: active ? 0.2 : 0.09,
					side: THREE.DoubleSide,
					depthTest: false,
					depthWrite: false
				})
			);
			overlayPlane.renderOrder = active ? 26 : 20;

			const overlayOutline = new THREE.LineSegments(
				new THREE.EdgesGeometry(overlayPlaneGeometry),
				new THREE.LineBasicMaterial({
					color: active ? new THREE.Color('#f8fbff') : baseColor,
					transparent: true,
					opacity: active ? 0.95 : 0.58,
					depthTest: false,
					depthWrite: false
				})
			);
			overlayOutline.renderOrder = active ? 27 : 21;

			const normalIndicator = new THREE.Line(
				new THREE.BufferGeometry().setFromPoints([new THREE.Vector3(0, 0, 0), new THREE.Vector3(0, 0, 1.2)]),
				new THREE.LineBasicMaterial({
					color: active ? new THREE.Color('#0ea5e9') : baseColor,
					transparent: true,
					opacity: active ? 0.92 : 0.5,
					depthTest: false,
					depthWrite: false
				})
			);
			normalIndicator.renderOrder = active ? 28 : 22;

			const centerMarker = new THREE.Mesh(
				new THREE.CircleGeometry(active ? 0.1 : 0.07, 16),
				new THREE.MeshBasicMaterial({
					color: active ? new THREE.Color('#f8fbff') : baseColor,
					transparent: true,
					opacity: active ? 0.95 : 0.72,
					depthTest: false,
					depthWrite: false
				})
			);
			centerMarker.position.z = 0.001;
			centerMarker.renderOrder = active ? 29 : 23;

			layerGroup.add(overlayPlane, overlayOutline, normalIndicator, centerMarker);
			overlaysGroup.add(layerGroup);
		}

		applyLayerRecursive(overlaysGroup, PIP_SLICE_LAYER);
		scene.add(overlaysGroup);
		pipSliceOverlayGroup = overlaysGroup;
	}

	function setupStage() {
		if (!mainCanvas || !pipCanvas || !mainWrap) return;

		scene = new THREE.Scene();

		mainRenderer = new THREE.WebGLRenderer({
			canvas: mainCanvas,
			antialias: true,
			alpha: false
		});
		mainRenderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
		mainRenderer.setClearColor(0xf8fafc, 1);

		pipRenderer = new THREE.WebGLRenderer({
			canvas: pipCanvas,
			antialias: true,
			alpha: false
		});
		pipRenderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
		pipRenderer.setClearColor(0xeff6ff, 1);

		mainCamera = new THREE.OrthographicCamera(
			-ORTHO_HALF_HEIGHT,
			ORTHO_HALF_HEIGHT,
			ORTHO_HALF_HEIGHT,
			-ORTHO_HALF_HEIGHT,
			0.1,
			100
		);
		mainCamera.zoom = 1;
		mainCamera.layers.set(0);
		mainCamera.layers.disable(PIP_SLICE_LAYER);

		pipCamera = new THREE.PerspectiveCamera(45, 1, 0.1, 200);
		pipCamera.position.set(8, 6, 8);
		pipCamera.lookAt(stageTarget);
		pipCamera.layers.enable(PIP_SLICE_LAYER);

		pipControls = new OrbitControls(pipCamera, pipCanvas);
		pipControls.enableDamping = true;
		pipControls.dampingFactor = 0.08;
		pipControls.target.copy(stageTarget);
		pipControls.minDistance = 3;
		pipControls.maxDistance = 24;

		scene.add(strokeRoot);
		scene.add(new THREE.AmbientLight(0xffffff, 0.8));
		const keyLight = new THREE.DirectionalLight(0xffffff, 0.55);
		keyLight.position.set(6, 8, 6);
		scene.add(keyLight);

		smoothSurfaceMaterial = new THREE.MeshStandardMaterial({
			color: 0xcbd5e1,
			roughness: 0.54,
			metalness: 0.06
		});
		smoothSurface = new MarchingCubes(
			SMOOTH_MESH_RESOLUTION,
			smoothSurfaceMaterial,
			false,
			false,
			SMOOTH_MESH_MAX_POLYGONS
		);
		smoothSurface.isolation = SMOOTH_MESH_ISOLATION;
		smoothSurface.visible = smoothMeshView;
		smoothSurface.renderOrder = 1;
		scene.add(smoothSurface);

		// 중심 기준점을 두면 Front/Side/Top에서 2D 드로잉 좌표 감각이 안정된다.
		const originMarker = new THREE.Mesh(
			new THREE.SphereGeometry(0.06, 10, 10),
			new THREE.MeshStandardMaterial({ color: 0x0f172a, roughness: 0.8 })
		);
		scene.add(originMarker);

		updateMainView(activeView);
		handleResize();
		startRenderLoop();
	}

	function makeGuidePlane(normalTuple: [number, number, number]) {
		if (!scene) return;

		if (guidePlane) {
			scene.remove(guidePlane);
			guidePlane.geometry.dispose();
			guidePlane.material.dispose();
		}
		if (guideGrid) {
			scene.remove(guideGrid);
			guideGrid.geometry.dispose();
			guideGrid.material.dispose();
		}
		if (guideAxes) {
			scene.remove(guideAxes);
			for (const child of guideAxes.children) {
				if (child instanceof THREE.Line) {
					child.geometry.dispose();
					child.material.dispose();
				}
			}
		}

		const normal = new THREE.Vector3(...normalTuple).normalize();
		const guideTangentV = activeTangentV.clone().normalize();
		const guideTangentU = new THREE.Vector3().crossVectors(guideTangentV, normal).normalize();
		const guideRotation = new THREE.Quaternion().setFromRotationMatrix(
			new THREE.Matrix4().makeBasis(guideTangentU, guideTangentV, normal)
		);
		guidePlane = new THREE.Mesh(
			new THREE.PlaneGeometry(16, 16),
			new THREE.MeshBasicMaterial({
				color: 0x93c5fd,
				transparent: true,
				opacity: 0.08,
				side: THREE.DoubleSide,
				depthWrite: false
			})
		);
		guidePlane.quaternion.copy(guideRotation);
		guidePlane.position.copy(getActiveSlicePoint());
		scene.add(guidePlane);

		const gridExtent = 8;
		const gridStep = 0.5;
		const gridHalfSteps = Math.round(gridExtent / gridStep);
		const gridPositions: number[] = [];
		for (let i = -gridHalfSteps; i <= gridHalfSteps; i += 1) {
			const offset = i * gridStep;
			gridPositions.push(-gridExtent, offset, 0, gridExtent, offset, 0);
			gridPositions.push(offset, -gridExtent, 0, offset, gridExtent, 0);
		}

		const gridGeometry = new THREE.BufferGeometry();
		gridGeometry.setAttribute('position', new THREE.Float32BufferAttribute(gridPositions, 3));
		guideGrid = new THREE.LineSegments(
			gridGeometry,
			new THREE.LineBasicMaterial({
				color: 0x64748b,
				transparent: true,
				opacity: 0.38,
				depthTest: false,
				depthWrite: false
			})
		);
		guideGrid.quaternion.copy(guideRotation);
		guideGrid.position.copy(getActiveSlicePoint());
		guideGrid.renderOrder = 2;
		scene.add(guideGrid);

		const axisLength = 4.6;
		const axisNormalLength = 1.7;
		const makeAxisLine = (a: THREE.Vector3, b: THREE.Vector3, color: number) => {
			const axisGeometry = new THREE.BufferGeometry().setFromPoints([a, b]);
			return new THREE.Line(
				axisGeometry,
				new THREE.LineBasicMaterial({
					color,
					transparent: true,
					opacity: 0.92,
					depthTest: false,
					depthWrite: false
				})
			);
		};

		guideAxes = new THREE.Group();
		guideAxes.add(
			makeAxisLine(new THREE.Vector3(-axisLength, 0, 0), new THREE.Vector3(axisLength, 0, 0), 0xef4444)
		);
		guideAxes.add(
			makeAxisLine(new THREE.Vector3(0, -axisLength, 0), new THREE.Vector3(0, axisLength, 0), 0x22c55e)
		);
		guideAxes.add(
			makeAxisLine(
				new THREE.Vector3(0, 0, -axisNormalLength * 0.35),
				new THREE.Vector3(0, 0, axisNormalLength),
				0x0ea5e9
			)
		);
		guideAxes.quaternion.copy(guideRotation);
		guideAxes.position.copy(getActiveSlicePoint());
		guideAxes.renderOrder = 3;
		scene.add(guideAxes);
		syncPipSliceOverlays();
	}

	function syncDrawPlane() {
		const config = VIEW_CONFIGS[activeView];
		activeNormal.set(...config.normal).normalize();
		activeTangentV.set(...config.up).normalize();
		activeTangentV.addScaledVector(activeNormal, -activeTangentV.dot(activeNormal)).normalize();
		activeTangentU.crossVectors(activeNormal, activeTangentV).normalize();
		drawPlane.setFromNormalAndCoplanarPoint(activeNormal, getActiveSlicePoint());
	}

	export function updateMainView(nextView: ViewId) {
		if (!mainCamera) return;

		activeView = nextView;
		const config = VIEW_CONFIGS[nextView];
		const cameraOffset = new THREE.Vector3(...config.position);

		mainCamera.position.copy(stageTarget).add(cameraOffset);
		mainCamera.up.set(...config.up);
		mainCamera.lookAt(stageTarget);
		mainCamera.updateProjectionMatrix();

		syncDrawPlane();
		makeGuidePlane(config.normal);
	}

	function resetQuarterView() {
		if (!pipCamera || !pipControls) return;
		pipCamera.position.set(8, 6, 8);
		pipControls.target.copy(stageTarget);
		pipControls.update();
	}

	function clampPipPosition(snapToTopRight = false) {
		if (!mainWrap || !pipWrap) return;
		const maxX = Math.max(PIP_MARGIN, mainWrap.clientWidth - pipWrap.offsetWidth - PIP_MARGIN);
		const maxY = Math.max(PIP_MARGIN, mainWrap.clientHeight - pipWrap.offsetHeight - PIP_MARGIN);
		if (snapToTopRight) {
			pipPosX = maxX;
			pipPosY = PIP_MARGIN;
			return;
		}
		pipPosX = THREE.MathUtils.clamp(pipPosX, PIP_MARGIN, maxX);
		pipPosY = THREE.MathUtils.clamp(pipPosY, PIP_MARGIN, maxY);
	}

	function startPipDrag(event: PointerEvent) {
		if (!mainWrap || !pipWrap) return;
		pipDragging = true;
		pipDragPointerId = event.pointerId;
		pipDragCaptureEl = event.currentTarget as HTMLElement;
		const pipRect = pipWrap.getBoundingClientRect();
		pipDragOffsetX = event.clientX - pipRect.left;
		pipDragOffsetY = event.clientY - pipRect.top;
		pipDragCaptureEl.setPointerCapture(event.pointerId);
		event.preventDefault();
		event.stopPropagation();
	}

	function movePipDrag(event: PointerEvent) {
		if (!pipDragging || event.pointerId !== pipDragPointerId || !mainWrap || !pipWrap) return;
		const mainRect = mainWrap.getBoundingClientRect();
		const nextX = event.clientX - mainRect.left - pipDragOffsetX;
		const nextY = event.clientY - mainRect.top - pipDragOffsetY;
		pipPosX = nextX;
		pipPosY = nextY;
		clampPipPosition(false);
		pipMovedByUser = true;
	}

	function endPipDrag(event: PointerEvent) {
		if (!pipDragging || event.pointerId !== pipDragPointerId) return;
		if (pipDragCaptureEl?.hasPointerCapture(event.pointerId)) {
			pipDragCaptureEl.releasePointerCapture(event.pointerId);
		}
		pipDragging = false;
		pipDragPointerId = -1;
		pipDragCaptureEl = null;
	}

	export function setInputMode(nextMode: InputMode) {
		inputMode = nextMode;
	}

	export function zoomMain(zoomFactor: number) {
		if (!mainCamera) return;
		mainCamera.zoom = THREE.MathUtils.clamp(mainCamera.zoom * zoomFactor, MIN_ZOOM, MAX_ZOOM);
		mainCamera.updateProjectionMatrix();
	}

	export function resetMainView() {
		if (!mainCamera || !pipControls || !pipCamera) return;
		stageTarget.set(0, 0, 0);
		mainCamera.zoom = 1;
		updateMainView(activeView);
		resetQuarterView();
	}

	function getWorldPoint(event: PointerEvent) {
		if (!mainCanvas || !mainCamera) return null;
		const rect = mainCanvas.getBoundingClientRect();
		pointer.x = ((event.clientX - rect.left) / rect.width) * 2 - 1;
		pointer.y = -((event.clientY - rect.top) / rect.height) * 2 + 1;
		raycaster.setFromCamera(pointer, mainCamera);
		const hit = new THREE.Vector3();
		return raycaster.ray.intersectPlane(drawPlane, hit) ? hit : null;
	}

	function nextDotId() {
		eraseDotSeq += 1;
		return `dot-${eraseDotSeq}`;
	}

	function getStrokeObject(strokeId: string) {
		for (const child of strokeRoot.children) {
			const candidateStrokeId = String((child as THREE.Group).userData?.strokeId ?? child.name);
			if (candidateStrokeId === strokeId) return child as THREE.Group;
		}
		return null;
	}

	function strokeExists(strokeId: string) {
		return Boolean(getStrokeObject(strokeId));
	}

	function setDotSelectionVisual(dot: StrokeDot, selected: boolean) {
		dot.mesh.material.emissive.set(selected ? '#f59e0b' : '#000000');
		dot.mesh.material.emissiveIntensity = selected ? 0.38 : 0;
		dot.mesh.material.needsUpdate = true;
	}

	function applySelectionVisuals() {
		for (const dot of strokeDots) {
			setDotSelectionVisual(dot, selectedStrokeIds.has(dot.strokeId));
		}
	}

	function setSelectedStroke(
		nextStrokeId: string | null,
		options?: {
			additive?: boolean;
			toggle?: boolean;
		}
	) {
		const additive = Boolean(options?.additive);
		const toggle = Boolean(options?.toggle);
		if (!additive) {
			selectedStrokeIds.clear();
			if (nextStrokeId) {
				selectedStrokeIds.add(nextStrokeId);
			}
		} else if (nextStrokeId) {
			if (toggle && selectedStrokeIds.has(nextStrokeId)) {
				selectedStrokeIds.delete(nextStrokeId);
			} else {
				selectedStrokeIds.add(nextStrokeId);
			}
		}
		if (!selectedStrokeIds.size) {
			selectedStrokeId = null;
		} else if (nextStrokeId && selectedStrokeIds.has(nextStrokeId)) {
			selectedStrokeId = nextStrokeId;
		} else {
			selectedStrokeId = Array.from(selectedStrokeIds).at(-1) ?? null;
		}
		applySelectionVisuals();
		syncDotVisibilityByRenderMode();
		dispatch('selectionchange', { strokeId: selectedStrokeId });
	}

	function findLastSelectableStrokeId() {
		for (let i = actionHistory.length - 1; i >= 0; i -= 1) {
			const entry = actionHistory[i];
			if (entry.kind !== 'draw') continue;
			if (strokeExists(entry.snapshot.strokeId)) return entry.snapshot.strokeId;
		}
		const fallback = strokeRoot.children[strokeRoot.children.length - 1];
		if (!fallback) return null;
		return String((fallback as THREE.Group).userData?.strokeId ?? fallback.name);
	}

	function projectPointToViewUV(point: THREE.Vector3, view: ViewId) {
		const config = VIEW_CONFIGS[view];
		const normal = new THREE.Vector3(...config.normal).normalize();
		const tangentV = new THREE.Vector3(...config.up).normalize();
		tangentV.addScaledVector(normal, -tangentV.dot(normal)).normalize();
		const tangentU = new THREE.Vector3().crossVectors(normal, tangentV).normalize();
		return {
			u: point.dot(tangentU),
			v: point.dot(tangentV)
		};
	}

	function resolveViewFromDirection(direction: THREE.Vector3): ViewId {
		let bestView: ViewId = activeView;
		let bestDot = -Infinity;
		for (const view of viewOrder) {
			const normal = new THREE.Vector3(...VIEW_CONFIGS[view].normal).normalize();
			const dot = direction.dot(normal);
			if (dot > bestDot) {
				bestDot = dot;
				bestView = view;
			}
		}
		return bestView;
	}

	function createPrimitiveSnapshot(kind: PrimitiveKind): StrokeSnapshot {
		const strokeId = `stroke-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
		const center = getActiveSlicePoint().clone();
		const size = THREE.MathUtils.clamp(brushRadius * 7.2, 0.26, 1.64);
		const dotRadius = THREE.MathUtils.clamp(brushRadius * 0.58, 0.03, 0.22);
		const depositRadius = dotRadius * 1.22;
		const depositAmount = Math.max(dotRadius * 0.78, 0.016);
		const points: THREE.Vector3[] = [];
		const pointKeys = new Set<string>();
		const pushPoint = (point: THREE.Vector3) => {
			const key = `${point.x.toFixed(3)}:${point.y.toFixed(3)}:${point.z.toFixed(3)}`;
			if (pointKeys.has(key)) return;
			pointKeys.add(key);
			points.push(point);
		};

		if (kind === 'sphere') {
			const rings = 7;
			const segments = 14;
			for (let r = 0; r <= rings; r += 1) {
				const phi = -Math.PI / 2 + (r / rings) * Math.PI;
				const cosPhi = Math.cos(phi);
				const sinPhi = Math.sin(phi);
				for (let s = 0; s < segments; s += 1) {
					const theta = (s / segments) * Math.PI * 2;
					const cosTheta = Math.cos(theta);
					const sinTheta = Math.sin(theta);
					const point = center
						.clone()
						.addScaledVector(activeTangentU, size * cosPhi * cosTheta)
						.addScaledVector(activeTangentV, size * sinPhi)
						.addScaledVector(activeNormal, size * cosPhi * sinTheta);
					pushPoint(point);
				}
			}
		} else if (kind === 'box') {
			const half = size * 0.92;
			const steps = 4;
			const values: number[] = [];
			for (let i = 0; i <= steps; i += 1) {
				values.push(-half + (i / steps) * (half * 2));
			}
			for (const a of values) {
				for (const b of values) {
					pushPoint(
						center
							.clone()
							.addScaledVector(activeTangentU, a)
							.addScaledVector(activeTangentV, b)
							.addScaledVector(activeNormal, half)
					);
					pushPoint(
						center
							.clone()
							.addScaledVector(activeTangentU, a)
							.addScaledVector(activeTangentV, b)
							.addScaledVector(activeNormal, -half)
					);
					pushPoint(
						center
							.clone()
							.addScaledVector(activeTangentU, a)
							.addScaledVector(activeTangentV, half)
							.addScaledVector(activeNormal, b)
					);
					pushPoint(
						center
							.clone()
							.addScaledVector(activeTangentU, a)
							.addScaledVector(activeTangentV, -half)
							.addScaledVector(activeNormal, b)
					);
					pushPoint(
						center
							.clone()
							.addScaledVector(activeTangentU, half)
							.addScaledVector(activeTangentV, a)
							.addScaledVector(activeNormal, b)
					);
					pushPoint(
						center
							.clone()
							.addScaledVector(activeTangentU, -half)
							.addScaledVector(activeTangentV, a)
							.addScaledVector(activeNormal, b)
					);
				}
			}
		} else {
			const radius = size * 0.88;
			const halfHeight = size * 0.94;
			const segments = 18;
			const levels = 5;
			for (let level = 0; level < levels; level += 1) {
				const y = -halfHeight + (level / (levels - 1)) * (halfHeight * 2);
				for (let s = 0; s < segments; s += 1) {
					const theta = (s / segments) * Math.PI * 2;
					pushPoint(
						center
							.clone()
							.addScaledVector(activeTangentU, Math.cos(theta) * radius)
							.addScaledVector(activeNormal, Math.sin(theta) * radius)
							.addScaledVector(activeTangentV, y)
					);
				}
			}
			const capRings = 3;
			for (const sign of [-1, 1]) {
				for (let ring = 0; ring <= capRings; ring += 1) {
					const ringRadius = radius * (1 - ring / (capRings + 1));
					for (let s = 0; s < segments; s += 1) {
						const theta = (s / segments) * Math.PI * 2;
						pushPoint(
							center
								.clone()
								.addScaledVector(activeTangentU, Math.cos(theta) * ringRadius)
								.addScaledVector(activeNormal, Math.sin(theta) * ringRadius)
								.addScaledVector(activeTangentV, sign * halfHeight)
						);
					}
				}
			}
		}

		const colorHex = brushColorHex || '#2563eb';
		const dots: StrokeSnapshotDot[] = points.map((point) => {
			const direction = point.clone().sub(center);
			const view = resolveViewFromDirection(direction.lengthSq() > 1e-8 ? direction.normalize() : activeNormal);
			return {
				basePoint: [point.x, point.y, point.z],
				radius: dotRadius,
				depositRadius,
				depositAmount,
				view,
				colorHex
			};
		});

		return {
			strokeId,
			dots
		};
	}

	function captureStrokeSnapshot(strokeId: string): StrokeSnapshot | null {
		const dots = strokeDots.filter((dot) => dot.strokeId === strokeId && dot.depositAmount > 1e-6);
		if (dots.length === 0) return null;
		return {
			strokeId,
			dots: dots.map((dot) => ({
				basePoint: [dot.basePoint.x, dot.basePoint.y, dot.basePoint.z],
				radius: dot.radius,
				depositRadius: dot.depositRadius,
				depositAmount: dot.depositAmount,
				view: dot.view,
				colorHex: `#${dot.mesh.material.color.getHexString()}`
			}))
		};
	}

	function cloneStrokeSnapshot(snapshot: StrokeSnapshot): StrokeSnapshot {
		return {
			strokeId: snapshot.strokeId,
			dots: snapshot.dots.map((dot) => ({
				basePoint: [...dot.basePoint] as [number, number, number],
				radius: dot.radius,
				depositRadius: dot.depositRadius,
				depositAmount: dot.depositAmount,
				view: dot.view,
				colorHex: dot.colorHex
			}))
		};
	}

	function strokeSnapshotsEqual(a: StrokeSnapshot, b: StrokeSnapshot) {
		if (a.strokeId !== b.strokeId) return false;
		if (a.dots.length !== b.dots.length) return false;
		for (let i = 0; i < a.dots.length; i += 1) {
			const left = a.dots[i];
			const right = b.dots[i];
			if (left.basePoint[0] !== right.basePoint[0]) return false;
			if (left.basePoint[1] !== right.basePoint[1]) return false;
			if (left.basePoint[2] !== right.basePoint[2]) return false;
			if (left.radius !== right.radius) return false;
			if (left.depositRadius !== right.depositRadius) return false;
			if (left.depositAmount !== right.depositAmount) return false;
			if (left.view !== right.view) return false;
			if (left.colorHex !== right.colorHex) return false;
		}
		return true;
	}

	function pushHistory(entry: HistoryEntry) {
		actionHistory.push(entry);
		redoHistory.length = 0;
	}

	function disposeStrokeMeshes(stroke: THREE.Group) {
		for (const child of stroke.children) {
			if (child instanceof THREE.Mesh) {
				child.material.dispose();
			}
		}
	}

	function removeStrokeById(strokeId: string) {
		const stroke = getStrokeObject(strokeId);
		if (stroke) {
			strokeRoot.remove(stroke);
			disposeStrokeMeshes(stroke);
		}

		for (let i = strokeDots.length - 1; i >= 0; i -= 1) {
			if (strokeDots[i].strokeId === strokeId) {
				strokeDots.splice(i, 1);
			}
		}

		if (selectedStrokeIds.has(strokeId)) {
			selectedStrokeIds.delete(strokeId);
			selectedStrokeId = Array.from(selectedStrokeIds).at(-1) ?? null;
			applySelectionVisuals();
			syncDotVisibilityByRenderMode();
			dispatch('selectionchange', { strokeId: selectedStrokeId });
		}
	}

	function restoreStrokeFromSnapshot(
		snapshot: StrokeSnapshot,
		{
			strokeId = `stroke-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`,
			offset = new THREE.Vector3()
		}: {
			strokeId?: string;
			offset?: THREE.Vector3;
		} = {}
	) {
		const stroke = new THREE.Group();
		stroke.name = strokeId;
		stroke.userData.strokeId = strokeId;
		strokeRoot.add(stroke);

		for (const dotSnapshot of snapshot.dots) {
			const basePoint = new THREE.Vector3(...dotSnapshot.basePoint).add(offset);
			const brushDot: BrushDotMesh = new THREE.Mesh(
				unitSphere,
				new THREE.MeshStandardMaterial({
					color: dotSnapshot.colorHex,
					roughness: brushRoughness,
					metalness: 0.06
				})
			);
			brushDot.position.copy(basePoint);
			brushDot.scale.setScalar(dotSnapshot.radius);
			brushDot.visible = !smoothMeshView;
			stroke.add(brushDot);

			const { u, v } = projectPointToViewUV(basePoint, dotSnapshot.view);
			const dot: StrokeDot = {
				id: nextDotId(),
				mesh: brushDot,
				basePoint,
				position: basePoint.clone(),
				u,
				v,
				height: 0,
				radius: dotSnapshot.radius,
				depositRadius: dotSnapshot.depositRadius,
				depositAmount: dotSnapshot.depositAmount,
				view: dotSnapshot.view,
				strokeId
			};
			strokeDots.push(dot);
		}

		rebuildHeightMaps();
		refreshAllDotHeights();
		markSmoothSurfaceDirty();
		setSelectedStroke(strokeId);
		if (!strokeOriginSnapshots.has(strokeId)) {
			const origin = captureStrokeSnapshot(strokeId);
			if (origin) {
				strokeOriginSnapshots.set(strokeId, cloneStrokeSnapshot(origin));
			}
		}

		return {
			stroke,
			strokeId
		};
	}

	function applySnapshotToStroke(snapshot: StrokeSnapshot | null, strokeId: string) {
		removeStrokeById(strokeId);
		if (snapshot) {
			restoreStrokeFromSnapshot(snapshot, { strokeId });
		} else {
			setSelectedStroke(null);
		}
	}

	function applyEraseChanges(changes: EraseChange[], useAfter: boolean) {
		for (const change of changes) {
			const dot = findDotById(change.dotId);
			if (!dot) continue;
			dot.depositAmount = useAfter ? change.afterAmount : change.beforeAmount;
			dot.mesh.visible = isDotVisible(dot);
		}
	}

	function resolveSelectedStrokeIds() {
		const validSelection = Array.from(selectedStrokeIds).filter((strokeId) => strokeExists(strokeId));
		if (validSelection.length > 0) {
			selectedStrokeIds.clear();
			for (const strokeId of validSelection) {
				selectedStrokeIds.add(strokeId);
			}
			if (!selectedStrokeId || !selectedStrokeIds.has(selectedStrokeId)) {
				selectedStrokeId = validSelection[validSelection.length - 1] ?? null;
			}
			applySelectionVisuals();
			syncDotVisibilityByRenderMode();
			dispatch('selectionchange', { strokeId: selectedStrokeId });
			return validSelection;
		}

		const fallback = findLastSelectableStrokeId();
		if (!fallback) {
			setSelectedStroke(null);
			return [];
		}
		setSelectedStroke(fallback);
		return [fallback];
	}

	function resolveSelectedStrokeId() {
		const selected = resolveSelectedStrokeIds();
		return selected[0] ?? null;
	}

	function getStrokeIdAtPointer(event: PointerEvent) {
		if (!mainCanvas || !mainCamera) return null;
		const rect = mainCanvas.getBoundingClientRect();
		pointer.x = ((event.clientX - rect.left) / rect.width) * 2 - 1;
		pointer.y = -((event.clientY - rect.top) / rect.height) * 2 + 1;
		raycaster.setFromCamera(pointer, mainCamera);

		let bestStrokeId: string | null = null;
		let bestDistSq = Number.POSITIVE_INFINITY;
		for (const dot of strokeDots) {
			if (dot.depositAmount <= 1e-6) continue;
			const distSq = raycaster.ray.distanceSqToPoint(dot.position);
			const maxDist = Math.max(dot.radius * 1.6, brushRadius * 0.8);
			if (distSq > maxDist * maxDist) continue;
			if (distSq < bestDistSq) {
				bestDistSq = distSq;
				bestStrokeId = dot.strokeId;
			}
		}
		return bestStrokeId;
	}

	export function getSelectedStrokeId() {
		return selectedStrokeId;
	}

	export function getSelectedStrokeIds() {
		return Array.from(selectedStrokeIds);
	}

	export function selectLastStroke() {
		const strokeId = findLastSelectableStrokeId();
		setSelectedStroke(strokeId);
		return Boolean(strokeId);
	}

	export function selectAllStrokes() {
		const ids: string[] = [];
		const seen = new Set<string>();
		for (const dot of strokeDots) {
			if (dot.depositAmount <= 1e-6) continue;
			if (seen.has(dot.strokeId)) continue;
			if (!strokeExists(dot.strokeId)) continue;
			seen.add(dot.strokeId);
			ids.push(dot.strokeId);
		}
		if (!ids.length) return false;
		selectedStrokeIds.clear();
		for (const strokeId of ids) {
			selectedStrokeIds.add(strokeId);
		}
		selectedStrokeId = ids[ids.length - 1] ?? null;
		applySelectionVisuals();
		syncDotVisibilityByRenderMode();
		dispatch('selectionchange', { strokeId: selectedStrokeId });
		return true;
	}

	export function clearStrokeSelection() {
		setSelectedStroke(null);
		return true;
	}

	export function copySelectedStroke() {
		const strokeIds = resolveSelectedStrokeIds();
		if (strokeIds.length === 0) return false;
		const snapshots: StrokeSnapshot[] = [];
		for (const strokeId of strokeIds) {
			const snapshot = captureStrokeSnapshot(strokeId);
			if (!snapshot) continue;
			snapshots.push(snapshot);
		}
		if (!snapshots.length) return false;
		clipboardStrokeSnapshots = snapshots;
		pasteSerial = 0;
		return true;
	}

	export function cutSelectedStroke() {
		if (editLocked) return false;
		const strokeIds = resolveSelectedStrokeIds();
		if (strokeIds.length === 0) return false;
		const snapshots: StrokeSnapshot[] = [];
		for (const strokeId of strokeIds) {
			const snapshot = captureStrokeSnapshot(strokeId);
			if (!snapshot) continue;
			snapshots.push(snapshot);
		}
		if (!snapshots.length) return false;
		clipboardStrokeSnapshots = snapshots;
		pasteSerial = 0;
		for (const strokeId of strokeIds) {
			removeStrokeById(strokeId);
		}
		rebuildHeightMaps();
		refreshAllDotHeights();
		markSmoothSurfaceDirty();
		for (const snapshot of snapshots) {
			pushHistory({
				kind: 'delete',
				snapshot
			});
		}
		return true;
	}

	export function deleteSelectedStroke() {
		if (editLocked) return false;
		const strokeIds = resolveSelectedStrokeIds();
		if (strokeIds.length === 0) return false;
		const snapshots: StrokeSnapshot[] = [];
		for (const strokeId of strokeIds) {
			const snapshot = captureStrokeSnapshot(strokeId);
			if (!snapshot) continue;
			snapshots.push(snapshot);
			removeStrokeById(strokeId);
		}
		if (!snapshots.length) return false;
		rebuildHeightMaps();
		refreshAllDotHeights();
		markSmoothSurfaceDirty();
		for (const snapshot of snapshots) {
			pushHistory({
				kind: 'delete',
				snapshot
			});
		}
		return true;
	}

	export function pasteCopiedStroke() {
		if (editLocked) return false;
		if (!clipboardStrokeSnapshots.length) return false;
		pasteSerial += 1;
		const shiftDistance = brushRadius * (1.6 + pasteSerial * 0.9);
		const baseOffset = activeTangentU
			.clone()
			.multiplyScalar(shiftDistance)
			.add(activeTangentV.clone().multiplyScalar(shiftDistance * 0.45));
		let pastedAny = false;
		for (let index = 0; index < clipboardStrokeSnapshots.length; index += 1) {
			const snapshot = clipboardStrokeSnapshots[index];
			const spreadOffset = activeTangentU
				.clone()
				.multiplyScalar(index * brushRadius * 0.36)
				.add(activeTangentV.clone().multiplyScalar(index * brushRadius * 0.14));
			const offset = baseOffset.clone().add(spreadOffset);
			const pasted = restoreStrokeFromSnapshot(snapshot, { offset });
			const committed = captureStrokeSnapshot(pasted.strokeId);
			if (!committed) continue;
			pushHistory({
				kind: 'draw',
				snapshot: committed
			});
			pastedAny = true;
		}
		return pastedAny;
	}

	export function duplicateSelectedStroke() {
		if (editLocked) return false;
		const selectedIds = resolveSelectedStrokeIds();
		if (!selectedIds.length) return false;
		const snapshots: StrokeSnapshot[] = [];
		for (const strokeId of selectedIds) {
			const snapshot = captureStrokeSnapshot(strokeId);
			if (!snapshot) continue;
			snapshots.push(snapshot);
		}
		if (!snapshots.length) return false;
		pasteSerial += 1;
		const shiftDistance = brushRadius * (1.6 + pasteSerial * 0.9);
		const baseOffset = activeTangentU
			.clone()
			.multiplyScalar(shiftDistance)
			.add(activeTangentV.clone().multiplyScalar(shiftDistance * 0.45));
		let duplicatedAny = false;
		for (let index = 0; index < snapshots.length; index += 1) {
			const snapshot = snapshots[index];
			const spreadOffset = activeTangentU
				.clone()
				.multiplyScalar(index * brushRadius * 0.36)
				.add(activeTangentV.clone().multiplyScalar(index * brushRadius * 0.14));
			const offset = baseOffset.clone().add(spreadOffset);
			const duplicated = restoreStrokeFromSnapshot(snapshot, { offset });
			const duplicatedSnapshot = captureStrokeSnapshot(duplicated.strokeId);
			if (!duplicatedSnapshot) continue;
			pushHistory({
				kind: 'draw',
				snapshot: duplicatedSnapshot
			});
			duplicatedAny = true;
		}
		return duplicatedAny;
	}

	export function insertPrimitiveMesh(kind: PrimitiveKind) {
		if (editLocked) return false;
		const snapshot = createPrimitiveSnapshot(kind);
		if (snapshot.dots.length === 0) return false;
		restoreStrokeFromSnapshot(snapshot, {
			strokeId: snapshot.strokeId
		});
		const committed = captureStrokeSnapshot(snapshot.strokeId);
		if (!committed) return false;
		pushHistory({
			kind: 'draw',
			snapshot: committed
		});
		return true;
	}

	function getStrokeDots(strokeId: string) {
		return strokeDots.filter((dot) => dot.strokeId === strokeId);
	}

	function commitSnapshotMutation(
		strokeId: string,
		before: StrokeSnapshot,
		mutate: (targetStrokeId: string) => boolean
	) {
		const changed = mutate(strokeId);
		if (!changed) return false;
		rebuildHeightMaps();
		refreshAllDotHeights();
		markSmoothSurfaceDirty();
		const after = strokeExists(strokeId) ? captureStrokeSnapshot(strokeId) : null;
		setSelectedStroke(strokeExists(strokeId) ? strokeId : null);
		pushHistory({
			kind: 'snapshot',
			strokeId,
			before,
			after
		});
		return true;
	}

	function computeStrokeCenter(strokeId: string) {
		const dots = getStrokeDots(strokeId).filter((dot) => dot.depositAmount > 1e-6);
		if (dots.length === 0) return null;
		const center = new THREE.Vector3();
		for (const dot of dots) {
			center.add(dot.basePoint);
		}
		center.divideScalar(dots.length);
		return center;
	}

	function refreshStrokeUvCoordinates(strokeId: string) {
		for (const dot of strokeDots) {
			if (dot.strokeId !== strokeId) continue;
			const uv = projectPointToViewUV(dot.basePoint, dot.view);
			dot.u = uv.u;
			dot.v = uv.v;
		}
	}

	export function translateSelectedStroke(dx: number, dy: number, dz: number) {
		if (editLocked) return false;
		const offset = new THREE.Vector3(dx, dy, dz);
		const strokeIds = resolveSelectedStrokeIds();
		if (!strokeIds.length) return false;
		let changedAny = false;
		for (const strokeId of strokeIds) {
			const before = captureStrokeSnapshot(strokeId);
			if (!before) continue;
			const changed = commitSnapshotMutation(strokeId, before, (targetStrokeId) => {
				const dots = getStrokeDots(targetStrokeId);
				if (dots.length === 0) return false;
				for (const dot of dots) {
					dot.basePoint.add(offset);
				}
				refreshStrokeUvCoordinates(targetStrokeId);
				return true;
			});
			if (changed) changedAny = true;
		}
		return changedAny;
	}

	export function nudgeSelectedStroke(deltaU: number, deltaV: number, deltaN = 0) {
		const offset = activeTangentU
			.clone()
			.multiplyScalar(deltaU)
			.add(activeTangentV.clone().multiplyScalar(deltaV))
			.add(activeNormal.clone().multiplyScalar(deltaN));
		return translateSelectedStroke(offset.x, offset.y, offset.z);
	}

	export function scaleSelectedStroke(scaleFactor: number) {
		if (editLocked) return false;
		if (!Number.isFinite(scaleFactor) || Math.abs(scaleFactor - 1) <= 1e-6) return false;
		const strokeIds = resolveSelectedStrokeIds();
		if (!strokeIds.length) return false;
		let changedAny = false;
		for (const strokeId of strokeIds) {
			const before = captureStrokeSnapshot(strokeId);
			if (!before) continue;
			const center = computeStrokeCenter(strokeId);
			if (!center) continue;
			const changed = commitSnapshotMutation(strokeId, before, (targetStrokeId) => {
				const dots = getStrokeDots(targetStrokeId);
				if (dots.length === 0) return false;
				const safeScale = THREE.MathUtils.clamp(scaleFactor, 0.25, 4);
				for (const dot of dots) {
					dot.basePoint.sub(center).multiplyScalar(safeScale).add(center);
					dot.radius = Math.max(0.001, dot.radius * safeScale);
					dot.depositRadius = Math.max(0.001, dot.depositRadius * safeScale);
				}
				refreshStrokeUvCoordinates(targetStrokeId);
				return true;
			});
			if (changed) changedAny = true;
		}
		return changedAny;
	}

	export function rotateSelectedStroke(degrees: number) {
		if (editLocked) return false;
		if (!Number.isFinite(degrees) || Math.abs(degrees) <= 1e-6) return false;
		const radians = THREE.MathUtils.degToRad(degrees);
		const rotation = new THREE.Matrix4().makeRotationAxis(activeNormal.clone().normalize(), radians);
		const strokeIds = resolveSelectedStrokeIds();
		if (!strokeIds.length) return false;
		let changedAny = false;
		for (const strokeId of strokeIds) {
			const before = captureStrokeSnapshot(strokeId);
			if (!before) continue;
			const center = computeStrokeCenter(strokeId);
			if (!center) continue;
			const changed = commitSnapshotMutation(strokeId, before, (targetStrokeId) => {
				const dots = getStrokeDots(targetStrokeId);
				if (dots.length === 0) return false;
				for (const dot of dots) {
					dot.basePoint.sub(center).applyMatrix4(rotation).add(center);
				}
				refreshStrokeUvCoordinates(targetStrokeId);
				return true;
			});
			if (changed) changedAny = true;
		}
		return changedAny;
	}

	export function resetSelectedStrokeTransform() {
		if (editLocked) return false;
		const strokeIds = resolveSelectedStrokeIds();
		if (!strokeIds.length) return false;
		let resetAny = false;
		for (const strokeId of strokeIds) {
			const origin = strokeOriginSnapshots.get(strokeId);
			if (!origin) continue;
			const before = captureStrokeSnapshot(strokeId);
			if (!before) continue;
			const target = cloneStrokeSnapshot(origin);
			applySnapshotToStroke(target, strokeId);
			const after = captureStrokeSnapshot(strokeId);
			if (!after || strokeSnapshotsEqual(before, after)) continue;
			pushHistory({
				kind: 'snapshot',
				strokeId,
				before,
				after
			});
			resetAny = true;
		}
		return resetAny;
	}

	export function sliceCutSelectedStroke() {
		if (editLocked) return false;
		if (!sliceEnabled) return false;
		const strokeIds = resolveSelectedStrokeIds();
		if (!strokeIds.length) return false;
		const slicePoint = getActiveSlicePoint().clone();
		const normal = activeNormal.clone().normalize();
		let cutAny = false;
		for (const strokeId of strokeIds) {
			const before = captureStrokeSnapshot(strokeId);
			if (!before) continue;
			const dots = getStrokeDots(strokeId).filter((dot) => dot.depositAmount > 1e-6);
			if (dots.length === 0) continue;

			let positive = 0;
			let negative = 0;
			for (const dot of dots) {
				const signed = dot.basePoint.clone().sub(slicePoint).dot(normal);
				if (signed >= 0) positive += 1;
				else negative += 1;
			}
			if (positive === 0 || negative === 0) continue;
			const keepPositive = positive >= negative;

			const changed = commitSnapshotMutation(strokeId, before, (targetStrokeId) => {
				const stroke = getStrokeObject(targetStrokeId);
				if (!stroke) return false;
				let removed = 0;
				for (let i = strokeDots.length - 1; i >= 0; i -= 1) {
					const dot = strokeDots[i];
					if (dot.strokeId !== targetStrokeId) continue;
					const signed = dot.basePoint.clone().sub(slicePoint).dot(normal);
					const shouldKeep = keepPositive ? signed >= 0 : signed < 0;
					if (shouldKeep) continue;
					stroke.remove(dot.mesh);
					dot.mesh.material.dispose();
					strokeDots.splice(i, 1);
					removed += 1;
				}
				if (removed === 0) return false;

				const remaining = strokeDots.some((dot) => dot.strokeId === targetStrokeId);
				if (!remaining) {
					strokeRoot.remove(stroke);
				}
				return true;
			});
			if (changed) cutAny = true;
		}
		return cutAny;
	}

	function startStroke(point: THREE.Vector3) {
		pendingEraseChanges.clear();
		lastEraseSurfacePoint = null;
		activeStroke = new THREE.Group();
		const strokeId = `stroke-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
		activeStroke.name = strokeId;
		activeStroke.userData.strokeId = strokeId;
		strokeRoot.add(activeStroke);
		strokeSupportView = activeView;
		strokeSupportMap = new Map(stackHeightMaps[activeView]);
		lastSurfacePoint = null;
		lastRawStrokePoint = point.clone();
		strokeArcCarry = 0;
		strokeInputPoints.length = 0;
		strokeInputPoints.push(point.clone());
		lastSmoothedPoint = point.clone();
		pushBrushDotWithMirror(point, { stamp: true });
	}

	function toCell(value: number) {
		return Math.floor(value / STACK_CELL_SIZE);
	}

	function cellKey(ix: number, iy: number) {
		return `${ix}:${iy}`;
	}

	function projectToActiveUV(point: THREE.Vector3) {
		return {
			u: point.dot(activeTangentU),
			v: point.dot(activeTangentV)
		};
	}

	function mirrorAcrossVerticalAxis(point: THREE.Vector3) {
		const offsetFromCenter = point.clone().sub(stageTarget);
		const axisDistance = offsetFromCenter.dot(activeTangentU);
		return point.clone().addScaledVector(activeTangentU, -2 * axisDistance);
	}

	function sampleHeightFromMap(map: Map<string, number>, u: number, v: number) {
		const gx = u / STACK_CELL_SIZE;
		const gy = v / STACK_CELL_SIZE;
		const i0 = Math.floor(gx);
		const j0 = Math.floor(gy);
		const i1 = i0 + 1;
		const j1 = j0 + 1;
		const tx = gx - i0;
		const ty = gy - j0;

		const h00 = map.get(cellKey(i0, j0)) ?? 0;
		const h10 = map.get(cellKey(i1, j0)) ?? 0;
		const h01 = map.get(cellKey(i0, j1)) ?? 0;
		const h11 = map.get(cellKey(i1, j1)) ?? 0;

		const hx0 = h00 * (1 - tx) + h10 * tx;
		const hx1 = h01 * (1 - tx) + h11 * tx;
		return hx0 * (1 - ty) + hx1 * ty;
	}

	function sampleHeight(view: ViewId, u: number, v: number) {
		return sampleHeightFromMap(stackHeightMaps[view], u, v);
	}

	function sampleStrokeSupportHeight(view: ViewId, u: number, v: number) {
		if (strokeSupportMap && strokeSupportView === view) {
			return sampleHeightFromMap(strokeSupportMap, u, v);
		}
		return sampleHeight(view, u, v);
	}

	function sampleTopFromExistingDots(basePoint: THREE.Vector3, normal: THREE.Vector3, excludeStrokeId?: string) {
		let maxHeight = 0;
		for (const dot of strokeDots) {
			if (dot.depositAmount <= 1e-6) continue;
			if (excludeStrokeId && dot.strokeId === excludeStrokeId) continue;

			tmpSampleDelta.subVectors(dot.position, basePoint);
			const along = tmpSampleDelta.dot(normal);
			const radialSq = Math.max(0, tmpSampleDelta.lengthSq() - along * along);
			const supportRadius = Math.max(
				dot.depositRadius * CROSS_VIEW_SUPPORT_RADIUS_SCALE,
				dot.radius * 0.42
			);
			const radiusSq = supportRadius * supportRadius;
			if (radialSq > radiusSq) continue;

			const cap = Math.sqrt(Math.max(0, radiusSq - radialSq));
			const candidate = along + cap;
			const maxHeadroom = dot.height + dot.depositAmount * CROSS_VIEW_SUPPORT_HEADROOM_SCALE;
			const clampedCandidate = Math.min(candidate, maxHeadroom);
			if (clampedCandidate > maxHeight) {
				maxHeight = clampedCandidate;
			}
		}
		return maxHeight;
	}

	function depositHeight(
		view: ViewId,
		u: number,
		v: number,
		depositRadius: number,
		depositAmount: number,
		options?: { wetnessBoost?: number }
	) {
		const map = stackHeightMaps[view];
		const wetnessMap = wetnessMaps[view];
		const wetnessBoost = THREE.MathUtils.clamp(options?.wetnessBoost ?? 0, 0, 1);
		const centerI = toCell(u);
		const centerJ = toCell(v);
		const range = Math.ceil(depositRadius / STACK_CELL_SIZE) + 1;

		for (let di = -range; di <= range; di += 1) {
			for (let dj = -range; dj <= range; dj += 1) {
				const ix = centerI + di;
				const iy = centerJ + dj;
				const sampleU = ix * STACK_CELL_SIZE;
				const sampleV = iy * STACK_CELL_SIZE;
				const distance = Math.hypot(sampleU - u, sampleV - v);
				if (distance > depositRadius) continue;

				const normalized = distance / depositRadius;
				const falloff = 1 - normalized * normalized;
				const candidate = depositAmount * falloff;
				const key = cellKey(ix, iy);
				const prev = map.get(key) ?? 0;
				map.set(key, prev + candidate);
				if (wetnessBoost > 0) {
					const prevWet = wetnessMap.get(key) ?? 0;
					const nextWet = Math.min(1, prevWet + wetnessBoost * falloff);
					if (nextWet > FLOW_MIN_WETNESS) {
						wetnessMap.set(key, nextWet);
					}
				}
			}
		}
	}

	function raiseBaseline(view: ViewId, u: number, v: number, baselineHeight: number, radius: number) {
		if (baselineHeight <= 0) return;

		const map = stackHeightMaps[view];
		const centerI = toCell(u);
		const centerJ = toCell(v);
		const range = Math.ceil(radius / STACK_CELL_SIZE) + 1;

		for (let di = -range; di <= range; di += 1) {
			for (let dj = -range; dj <= range; dj += 1) {
				const ix = centerI + di;
				const iy = centerJ + dj;
				const sampleU = ix * STACK_CELL_SIZE;
				const sampleV = iy * STACK_CELL_SIZE;
				const distance = Math.hypot(sampleU - u, sampleV - v);
				if (distance > radius) continue;

				const falloff = 1 - distance / radius;
				const candidate = baselineHeight * (0.78 + 0.22 * falloff);
				const key = cellKey(ix, iy);
				const prev = map.get(key) ?? 0;
				if (candidate > prev) {
					map.set(key, candidate);
				}
			}
		}
	}

	function getViewNormal(view: ViewId) {
		return new THREE.Vector3(...VIEW_CONFIGS[view].normal).normalize();
	}

	function refreshDotHeight(dot: StrokeDot) {
		if (dot.depositAmount <= 1e-6) {
			dot.height = 0;
			dot.mesh.visible = false;
			return;
		}
		dot.mesh.visible = isDotVisible(dot);
		const normal = getViewNormal(dot.view);
		const currentHeight = sampleHeight(dot.view, dot.u, dot.v);
		dot.height = currentHeight;
		dot.position.copy(dot.basePoint).addScaledVector(normal, currentHeight);
		dot.mesh.position.copy(dot.position);
	}

	function refreshHeightsForView(view: ViewId) {
		for (const dot of strokeDots) {
			if (dot.view === view) {
				refreshDotHeight(dot);
			}
		}
		markSmoothSurfaceDirty();
	}

	function refreshAllDotHeights() {
		for (const dot of strokeDots) {
			refreshDotHeight(dot);
		}
		markSmoothSurfaceDirty();
	}

	function rebuildHeightMaps() {
		for (const view of viewOrder) {
			stackHeightMaps[view].clear();
			wetnessMaps[view].clear();
		}
		for (const dot of strokeDots) {
			if (dot.depositAmount <= 1e-6) continue;
			depositHeight(dot.view, dot.u, dot.v, dot.depositRadius, dot.depositAmount);
		}
	}

	function rebuildSmoothSurface() {
		if (!smoothSurface) return;
		smoothSurface.reset();
		if (!smoothMeshView) {
			smoothSurface.visible = false;
			return;
		}

		const activeDots = strokeDots.filter((dot) => dot.depositAmount > 1e-6);
		if (activeDots.length === 0) {
			smoothSurface.visible = false;
			return;
		}

		let minX = Infinity;
		let minY = Infinity;
		let minZ = Infinity;
		let maxX = -Infinity;
		let maxY = -Infinity;
		let maxZ = -Infinity;

		for (const dot of activeDots) {
			const radius = dot.depositRadius + SMOOTH_MESH_PADDING;
			minX = Math.min(minX, dot.position.x - radius);
			minY = Math.min(minY, dot.position.y - radius);
			minZ = Math.min(minZ, dot.position.z - radius);
			maxX = Math.max(maxX, dot.position.x + radius);
			maxY = Math.max(maxY, dot.position.y + radius);
			maxZ = Math.max(maxZ, dot.position.z + radius);
		}

		const centerX = (minX + maxX) * 0.5;
		const centerY = (minY + maxY) * 0.5;
		const centerZ = (minZ + maxZ) * 0.5;
		const spanX = Math.max(maxX - minX, SMOOTH_MESH_MIN_SPAN);
		const spanY = Math.max(maxY - minY, SMOOTH_MESH_MIN_SPAN);
		const spanZ = Math.max(maxZ - minZ, SMOOTH_MESH_MIN_SPAN);
		const minBoundX = centerX - spanX * 0.5;
		const minBoundY = centerY - spanY * 0.5;
		const minBoundZ = centerZ - spanZ * 0.5;

		smoothSurface.position.set(centerX, centerY, centerZ);
		smoothSurface.scale.set(spanX, spanY, spanZ);

		const step = Math.max(1, Math.ceil(activeDots.length / SMOOTH_MESH_MAX_BALLS));
		const sampledBalls = Math.max(1, Math.ceil(activeDots.length / step));
		const baseStrength = 1.2 / (((Math.sqrt(sampledBalls) - 1) / 4) + 1);
		const radiusReference = Math.max(0.03, brushRadius * BRUSH_DEPOSIT_RADIUS_SCALE);

		for (let i = 0; i < activeDots.length; i += step) {
			const dot = activeDots[i];
			const nx = THREE.MathUtils.clamp((dot.position.x - minBoundX) / spanX, 0.001, 0.999);
			const ny = THREE.MathUtils.clamp((dot.position.y - minBoundY) / spanY, 0.001, 0.999);
			const nz = THREE.MathUtils.clamp((dot.position.z - minBoundZ) / spanZ, 0.001, 0.999);
			const radiusFactor = THREE.MathUtils.clamp(dot.depositRadius / radiusReference, 0.55, 1.8);
			const strength = THREE.MathUtils.clamp(baseStrength * radiusFactor, 0.09, 1.35);
			smoothSurface.addBall(nx, ny, nz, strength, SMOOTH_MESH_SUBTRACT);
		}

		smoothSurface.visible = true;
	}

	function pushBrushDot(point: THREE.Vector3, options?: { force?: boolean; stamp?: boolean }) {
		if (!activeStroke) return;
		const force = options?.force ?? false;
		const stamp = options?.stamp ?? false;
		const usingFillTool = activeStrokeTool === 'fill';
		const toolRadius = brushRadius * (usingFillTool ? FILL_TOOL_RADIUS_SCALE : 1);
		const minSpacing = toolRadius * (usingFillTool ? FILL_TOOL_SPACING_RATIO : 0.16);
		if (!force && lastSurfacePoint && lastSurfacePoint.distanceToSquared(point) < minSpacing * minSpacing) {
			return;
		}

		const { u, v } = projectToActiveUV(point);
		const layerGain = THREE.MathUtils.clamp(0.22 + brushStrength * 0.74, 0.22, 1.06);
		const depthScale = stamp ? STAMP_DEPTH_BOOST : 1;
		const stampRadiusScale = stamp ? STAMP_RADIUS_SHRINK : 1;
		const layerStep =
			toolRadius * BRUSH_DEPTH_SCALE * layerGain * (usingFillTool ? FILL_TOOL_DEPTH_SCALE : 1) * depthScale;
		const depositRadius =
			toolRadius *
			BRUSH_DEPOSIT_RADIUS_SCALE *
			(usingFillTool ? FILL_TOOL_RADIUS_SPREAD : 1) *
			stampRadiusScale;
		const depositAmount = layerStep * 0.9;
		const wetnessBoost = THREE.MathUtils.clamp(
			(0.34 + brushStrength * 0.46) * (stamp ? STAMP_WETNESS_SCALE : 1),
			0.08,
			0.86
		);
		const activeStrokeId = String(activeStroke.userData.strokeId ?? activeStroke.name);
		const baseFromMap = sampleStrokeSupportHeight(activeView, u, v);
		const baseFromExistingDots = sampleTopFromExistingDots(point, activeNormal, activeStrokeId);
		const supportHeight = Math.max(baseFromMap, baseFromExistingDots);
		const currentMapHeight = sampleHeight(activeView, u, v);

		if (supportHeight > currentMapHeight) {
			raiseBaseline(activeView, u, v, supportHeight, depositRadius);
		}
		depositHeight(activeView, u, v, depositRadius, depositAmount, { wetnessBoost });
		const dotHeight = supportHeight + depositAmount;
		const liftedPoint = point.clone().addScaledVector(activeNormal, dotHeight);
		const strokeId = activeStrokeId;

		const brushDot: BrushDotMesh = new THREE.Mesh(
			unitSphere,
			new THREE.MeshStandardMaterial({
				color: resolveBrushColor(),
				roughness: brushRoughness,
				metalness: 0.06
			})
		);
		brushDot.position.copy(liftedPoint);
		brushDot.scale.setScalar(toolRadius);
		brushDot.visible = !smoothMeshView;
		activeStroke.add(brushDot);
		strokeDots.push({
			id: nextDotId(),
			mesh: brushDot,
			basePoint: point.clone(),
			position: liftedPoint.clone(),
			u,
			v,
			height: dotHeight,
			radius: toolRadius,
			depositRadius,
			depositAmount,
			view: activeView,
			strokeId
		});
		lastSurfacePoint = point.clone();
		markSmoothSurfaceDirty();
	}

	function pushBrushDotWithMirror(point: THREE.Vector3, options?: { force?: boolean; stamp?: boolean }) {
		pushBrushDot(point, options);
		if (!mirrorDraw) return;
		const mirroredPoint = mirrorAcrossVerticalAxis(point);
		if (mirroredPoint.distanceToSquared(point) <= MIRROR_AXIS_EPSILON_SQ) return;
		pushBrushDot(mirroredPoint, options);
	}

	function parseCellKey(key: string): [number, number] {
		const split = key.indexOf(':');
		return [Number(key.slice(0, split)), Number(key.slice(split + 1))];
	}

	function applyViscousFlow(view: ViewId, dtSec: number) {
		const heightMap = stackHeightMaps[view];
		const wetnessMap = wetnessMaps[view];
		if (wetnessMap.size === 0) return false;

		const decay = Math.exp(-dtSec / FLOW_HARDEN_TAU);
		const reposeThreshold = SAND_REPOSE_GRADIENT * STACK_CELL_SIZE;
		const heightDelta = new Map<string, number>();
		const nextWetness = new Map<string, number>();
		let changed = false;

		for (const [sourceKey, sourceWetness] of wetnessMap.entries()) {
			const sourceHeight = heightMap.get(sourceKey) ?? 0;
			if (sourceHeight <= 1e-6) continue;

			const wetness = THREE.MathUtils.clamp(sourceWetness * decay, 0, 1);
			if (wetness <= FLOW_MIN_WETNESS) continue;

			const [ix, iy] = parseCellKey(sourceKey);
			const flowCandidates: Array<{ key: string; amount: number }> = [];
			let totalCandidate = 0;

			for (const [dx, dy] of FLOW_NEIGHBORS) {
				const targetKey = cellKey(ix + dx, iy + dy);
				const targetHeight = heightMap.get(targetKey) ?? 0;
				const excessSlope = sourceHeight - targetHeight - reposeThreshold;
				if (excessSlope <= 0) continue;
				const amount = excessSlope * FLOW_RATE * dtSec * wetness;
				if (amount <= 1e-6) continue;
				flowCandidates.push({ key: targetKey, amount });
				totalCandidate += amount;
			}

			const maxTransfer = sourceHeight * (FLOW_MAX_TRANSFER_RATIO * wetness + 0.06);
			const transferScale = totalCandidate > maxTransfer && totalCandidate > 0 ? maxTransfer / totalCandidate : 1;
			let moved = 0;

			for (const candidate of flowCandidates) {
				const movedAmount = candidate.amount * transferScale;
				if (movedAmount <= 1e-6) continue;
				moved += movedAmount;
				heightDelta.set(sourceKey, (heightDelta.get(sourceKey) ?? 0) - movedAmount);
				heightDelta.set(candidate.key, (heightDelta.get(candidate.key) ?? 0) + movedAmount);

				const carriedWetness = THREE.MathUtils.clamp(
					(sourceHeight > 1e-6 ? movedAmount / sourceHeight : 0) * wetness * FLOW_CARRY_RATIO,
					0,
					1
				);
				if (carriedWetness > FLOW_MIN_WETNESS) {
					nextWetness.set(
						candidate.key,
						Math.min(1, (nextWetness.get(candidate.key) ?? 0) + carriedWetness)
					);
				}
			}

			const residualWetness = THREE.MathUtils.clamp(
				wetness - (sourceHeight > 1e-6 ? (moved / sourceHeight) * wetness : 0),
				0,
				1
			);
			if (residualWetness > FLOW_MIN_WETNESS) {
				nextWetness.set(sourceKey, Math.max(nextWetness.get(sourceKey) ?? 0, residualWetness));
			}
			if (moved > 1e-6) {
				changed = true;
			}
		}

		for (const [key, delta] of heightDelta.entries()) {
			const nextHeight = (heightMap.get(key) ?? 0) + delta;
			if (nextHeight > 1e-6) {
				heightMap.set(key, nextHeight);
			} else {
				heightMap.delete(key);
			}
		}

		wetnessMap.clear();
		for (const [key, wetness] of nextWetness.entries()) {
			if (wetness > FLOW_MIN_WETNESS) {
				wetnessMap.set(key, wetness);
			}
		}

		return changed;
	}

	function simulateViscousSand(dtSec: number) {
		if (dtSec <= 0) return;
		const changedViews = new Set<ViewId>();
		const stepDt = dtSec / FLOW_ITERATIONS;

		for (let i = 0; i < FLOW_ITERATIONS; i += 1) {
			for (const view of viewOrder) {
				if (applyViscousFlow(view, stepDt)) {
					changedViews.add(view);
				}
			}
		}

		if (changedViews.size === 0) return;
		for (const dot of strokeDots) {
			if (changedViews.has(dot.view)) {
				refreshDotHeight(dot);
			}
		}
		markSmoothSurfaceDirty();
	}

	function resolveSegmentSteps(length: number) {
		const toolStepScale = activeStrokeTool === 'fill' ? FILL_TOOL_STEP_SCALE : 1;
		const stepLength = Math.max(brushRadius * PATH_SAMPLE_STEP_RATIO * toolStepScale, MIN_PATH_SAMPLE_STEP);
		const maxSteps = activeStrokeTool === 'fill' ? Math.round(MAX_PATH_STEPS * 1.5) : MAX_PATH_STEPS;
		return Math.min(maxSteps, Math.max(1, Math.ceil(length / stepLength)));
	}

	function resolveArcResampleStep() {
		const toolStepScale = activeStrokeTool === 'fill' ? FILL_TOOL_STEP_SCALE : 1;
		return Math.max(brushRadius * ARC_RESAMPLE_STEP_RATIO * toolStepScale, ARC_RESAMPLE_MIN_STEP);
	}

	function appendStrokePointWithArcResample(toPoint: THREE.Vector3) {
		if (!lastRawStrokePoint) {
			lastRawStrokePoint = toPoint.clone();
			return;
		}
		const fromPoint = lastRawStrokePoint;
		const segmentLength = fromPoint.distanceTo(toPoint);
		if (segmentLength <= 1e-6) return;

		const step = resolveArcResampleStep();
		let distanceFromFrom = step - strokeArcCarry;
		while (distanceFromFrom <= segmentLength + 1e-9) {
			const t = distanceFromFrom / segmentLength;
			const samplePoint = fromPoint.clone().lerp(toPoint, t);
			fillStrokeCurve(samplePoint);
			distanceFromFrom += step;
		}

		const lastPlacedDistance = distanceFromFrom - step;
		strokeArcCarry = Math.max(0, segmentLength - lastPlacedDistance);
		lastRawStrokePoint = toPoint.clone();
	}

	function fillLinearSegment(fromPoint: THREE.Vector3, toPoint: THREE.Vector3) {
		const distance = fromPoint.distanceTo(toPoint);
		if (distance <= 1e-6) return;
		const steps = resolveSegmentSteps(distance);
		for (let step = 1; step <= steps; step += 1) {
			const t = step / steps;
			const samplePoint = fromPoint.clone().lerp(toPoint, t);
			pushBrushDotWithMirror(samplePoint, { force: true });
		}
	}

	function fillQuadraticSegment(startPoint: THREE.Vector3, controlPoint: THREE.Vector3, endPoint: THREE.Vector3) {
		const approxLength = startPoint.distanceTo(controlPoint) + controlPoint.distanceTo(endPoint);
		if (approxLength <= 1e-6) return;
		const steps = resolveSegmentSteps(approxLength);
		for (let step = 1; step <= steps; step += 1) {
			const t = step / steps;
			const invT = 1 - t;
			const samplePoint = startPoint
				.clone()
				.multiplyScalar(invT * invT)
				.add(controlPoint.clone().multiplyScalar(2 * invT * t))
				.add(endPoint.clone().multiplyScalar(t * t));
			pushBrushDotWithMirror(samplePoint, { force: true });
		}
	}

	function fillStrokeCurve(toPoint: THREE.Vector3) {
		const prevInput = strokeInputPoints[strokeInputPoints.length - 1];
		if (prevInput && prevInput.distanceToSquared(toPoint) <= 1e-8) return;
		strokeInputPoints.push(toPoint.clone());

		if (strokeInputPoints.length === 2) {
			const p0 = strokeInputPoints[0];
			const p1 = strokeInputPoints[1];
			const mid01 = p0.clone().add(p1).multiplyScalar(0.5);
			fillLinearSegment(lastSmoothedPoint ?? p0, mid01);
			lastSmoothedPoint = mid01;
			return;
		}

		if (strokeInputPoints.length < 3) return;
		const p0 = strokeInputPoints[strokeInputPoints.length - 3];
		const p1 = strokeInputPoints[strokeInputPoints.length - 2];
		const p2 = strokeInputPoints[strokeInputPoints.length - 1];
		const startPoint = p0.clone().add(p1).multiplyScalar(0.5);
		const endPoint = p1.clone().add(p2).multiplyScalar(0.5);
		fillLinearSegment(lastSmoothedPoint ?? startPoint, startPoint);
		fillQuadraticSegment(startPoint, p1, endPoint);
		lastSmoothedPoint = endPoint;
	}

	function polygonSignedArea(points: Array<{ u: number; v: number }>) {
		let sum = 0;
		for (let i = 0; i < points.length; i += 1) {
			const current = points[i];
			const next = points[(i + 1) % points.length];
			sum += current.u * next.v - next.u * current.v;
		}
		return sum * 0.5;
	}

	function pointInPolygon(u: number, v: number, polygon: Array<{ u: number; v: number }>) {
		let inside = false;
		for (let i = 0, j = polygon.length - 1; i < polygon.length; j = i, i += 1) {
			const pi = polygon[i];
			const pj = polygon[j];
			const intersects =
				pi.v > v !== pj.v > v && u < ((pj.u - pi.u) * (v - pi.v)) / (pj.v - pi.v + 1e-9) + pi.u;
			if (intersects) inside = !inside;
		}
		return inside;
	}

	function uvToWorldPoint(u: number, v: number) {
		return stageTarget
			.clone()
			.addScaledVector(activeTangentU, u)
			.addScaledVector(activeTangentV, v);
	}

	function findDotById(dotId: string) {
		for (const dot of strokeDots) {
			if (dot.id === dotId) return dot;
		}
		return null;
	}

	function recordEraseChange(dot: StrokeDot, beforeAmount: number, afterAmount: number) {
		const existing = pendingEraseChanges.get(dot.id);
		if (existing) {
			existing.afterAmount = afterAmount;
			return;
		}
		pendingEraseChanges.set(dot.id, {
			dotId: dot.id,
			beforeAmount,
			afterAmount
		});
	}

	function eraseAtPoint(point: THREE.Vector3, options?: { force?: boolean }) {
		const force = options?.force ?? false;
		const eraserRadius = brushRadius * ERASER_RADIUS_SCALE;
		const minSpacing = eraserRadius * ERASER_POINT_SPACING_RATIO;
		if (
			!force &&
			lastEraseSurfacePoint &&
			lastEraseSurfacePoint.distanceToSquared(point) < minSpacing * minSpacing
		) {
			return false;
		}

		let changed = false;
		const erasePower = eraserRadius * ERASER_POWER_SCALE * (0.7 + brushStrength * 0.6);
		const eraseDepthRange = eraserRadius * ERASER_DEPTH_RANGE_SCALE;
		const radiusSq = eraserRadius * eraserRadius;

		for (const dot of strokeDots) {
			if (dot.depositAmount <= 1e-6) continue;

			tmpEraseDelta.subVectors(dot.position, point);
			const along = tmpEraseDelta.dot(activeNormal);
			const absAlong = Math.abs(along);
			if (absAlong > eraseDepthRange) continue;

			const radialSq = Math.max(0, tmpEraseDelta.lengthSq() - along * along);
			if (radialSq > radiusSq) continue;

			const radial = Math.sqrt(radialSq);
			const radialFalloff = 1 - radial / eraserRadius;
			const depthFalloff = 1 - absAlong / eraseDepthRange;
			const falloff = radialFalloff * radialFalloff * depthFalloff;
			if (falloff <= 1e-6) continue;

			const beforeAmount = dot.depositAmount;
			const afterAmount = Math.max(0, beforeAmount - erasePower * falloff);
			if (Math.abs(afterAmount - beforeAmount) <= 1e-6) continue;

			recordEraseChange(dot, beforeAmount, afterAmount);
			dot.depositAmount = afterAmount;
			dot.mesh.visible = isDotVisible(dot);
			changed = true;
		}

		if (changed) {
			rebuildHeightMaps();
			refreshAllDotHeights();
			markSmoothSurfaceDirty();
		}
		lastEraseSurfacePoint = point.clone();
		return changed;
	}

	function eraseAtPointWithMirror(point: THREE.Vector3, options?: { force?: boolean }) {
		let changed = eraseAtPoint(point, options);
		if (!mirrorDraw) return changed;
		const mirroredPoint = mirrorAcrossVerticalAxis(point);
		if (mirroredPoint.distanceToSquared(point) <= MIRROR_AXIS_EPSILON_SQ) return changed;
		const mirrorChanged = eraseAtPoint(mirroredPoint, options);
		return changed || mirrorChanged;
	}

	function eraseAlongSegment(toPoint: THREE.Vector3) {
		const fromPoint = lastEraseSurfacePoint?.clone();
		if (!fromPoint) {
			eraseAtPointWithMirror(toPoint, { force: true });
			return;
		}

		const distance = fromPoint.distanceTo(toPoint);
		if (distance <= 1e-6) return;
		const eraserRadius = brushRadius * ERASER_RADIUS_SCALE;
		const stepLength = Math.max(eraserRadius * ERASER_SEGMENT_STEP_RATIO, MIN_PATH_SAMPLE_STEP);
		const maxSteps = Math.round(MAX_PATH_STEPS * 2);
		const steps = Math.min(maxSteps, Math.max(1, Math.ceil(distance / stepLength)));
		for (let step = 1; step <= steps; step += 1) {
			const t = step / steps;
			const samplePoint = fromPoint.clone().lerp(toPoint, t);
			eraseAtPointWithMirror(samplePoint, { force: true });
		}
	}

	function startErase(point: THREE.Vector3) {
		activeStroke = null;
		lastSurfacePoint = null;
		lastRawStrokePoint = null;
		strokeArcCarry = 0;
		strokeInputPoints.length = 0;
		lastSmoothedPoint = null;
		strokeSupportMap = null;
		strokeSupportView = null;
		pendingEraseChanges.clear();
		lastEraseSurfacePoint = null;
		eraseAtPointWithMirror(point, { force: true });
	}

	function runAutoFillForClosedStroke() {
		if (strokeInputPoints.length < AUTO_FILL_MIN_POINTS) return;

		const first = strokeInputPoints[0];
		const last = strokeInputPoints[strokeInputPoints.length - 1];
		const closeThreshold = Math.max(
			brushRadius * AUTO_FILL_CLOSE_DISTANCE_FACTOR,
			AUTO_FILL_CLOSE_DISTANCE_MIN
		);
		if (first.distanceTo(last) > closeThreshold) return;

		const polygon = strokeInputPoints.map((point) => projectToActiveUV(point));
		const area = Math.abs(polygonSignedArea(polygon));
		const minArea = brushRadius * brushRadius * AUTO_FILL_MIN_AREA_FACTOR;
		if (area < minArea) return;

		let minU = Infinity;
		let maxU = -Infinity;
		let minV = Infinity;
		let maxV = -Infinity;
		for (const p of polygon) {
			if (p.u < minU) minU = p.u;
			if (p.u > maxU) maxU = p.u;
			if (p.v < minV) minV = p.v;
			if (p.v > maxV) maxV = p.v;
		}

		let step = Math.max(brushRadius * AUTO_FILL_STEP_RATIO, AUTO_FILL_MIN_STEP);
		const boundsArea = Math.max(1e-6, (maxU - minU) * (maxV - minV));
		while (boundsArea / (step * step) > AUTO_FILL_MAX_SAMPLES) {
			step *= 1.18;
		}

		let filled = 0;
		for (let v = minV; v <= maxV; v += step) {
			for (let u = minU; u <= maxU; u += step) {
				if (!pointInPolygon(u, v, polygon)) continue;
				const point = uvToWorldPoint(u, v);
				pushBrushDotWithMirror(point, { force: true });
				filled += 1;
				if (filled >= AUTO_FILL_MAX_SAMPLES) return;
			}
		}
	}

	function finishStroke() {
		const finishedStrokeId = activeStroke
			? String(activeStroke.userData.strokeId ?? activeStroke.name)
			: null;
		if (lastRawStrokePoint) {
			fillStrokeCurve(lastRawStrokePoint);
		}
		if (activeStroke && strokeInputPoints.length >= 2 && lastSmoothedPoint) {
			const tailPoint = strokeInputPoints[strokeInputPoints.length - 1];
			fillLinearSegment(lastSmoothedPoint, tailPoint);
		}
		if (autoFillClosedStroke) {
			runAutoFillForClosedStroke();
		}
		activeStroke = null;
		lastSurfacePoint = null;
		lastRawStrokePoint = null;
		strokeArcCarry = 0;
		strokeInputPoints.length = 0;
		lastSmoothedPoint = null;
		strokeSupportMap = null;
		strokeSupportView = null;
		activeStrokeTool = 'free-draw';
		if (finishedStrokeId) {
			const snapshot = captureStrokeSnapshot(finishedStrokeId);
			if (snapshot) {
				pushHistory({
					kind: 'draw',
					snapshot
				});
				if (!strokeOriginSnapshots.has(finishedStrokeId)) {
					strokeOriginSnapshots.set(finishedStrokeId, cloneStrokeSnapshot(snapshot));
				}
			}
			setSelectedStroke(finishedStrokeId);
		}
	}

	function finishErase() {
		if (pendingEraseChanges.size > 0) {
			pushHistory({
				kind: 'erase',
				changes: Array.from(pendingEraseChanges.values())
			});
		}
		pendingEraseChanges.clear();
		lastEraseSurfacePoint = null;
		lastRawStrokePoint = null;
		strokeArcCarry = 0;
		activeStrokeTool = 'free-draw';
	}

	export function undoLastStroke() {
		const latest = actionHistory.pop();
		if (!latest) return;

		if (latest.kind === 'draw') {
			removeStrokeById(latest.snapshot.strokeId);
		} else {
			if (latest.kind === 'erase') {
				applyEraseChanges(latest.changes, false);
			} else if (latest.kind === 'delete') {
				restoreStrokeFromSnapshot(latest.snapshot, {
					strokeId: latest.snapshot.strokeId
				});
			} else {
				applySnapshotToStroke(latest.before, latest.strokeId);
			}
		}
		redoHistory.push(latest);
		rebuildHeightMaps();
		refreshAllDotHeights();
		markSmoothSurfaceDirty();
	}

	export function redoLastStroke() {
		const latest = redoHistory.pop();
		if (!latest) return;

		if (latest.kind === 'draw') {
			restoreStrokeFromSnapshot(latest.snapshot, {
				strokeId: latest.snapshot.strokeId
			});
		} else if (latest.kind === 'erase') {
			applyEraseChanges(latest.changes, true);
		} else if (latest.kind === 'delete') {
			removeStrokeById(latest.snapshot.strokeId);
		} else {
			applySnapshotToStroke(latest.after, latest.strokeId);
		}
		actionHistory.push(latest);
		rebuildHeightMaps();
		refreshAllDotHeights();
		markSmoothSurfaceDirty();
	}

	export function clearAllStrokes() {
		while (actionHistory.length > 0) {
			undoLastStroke();
		}
	}

	function toDraftExportDot(dot: StrokeDot): DraftExportDot {
		return {
			x: dot.position.x,
			y: dot.position.y,
			z: dot.position.z,
			radius: dot.radius,
			depositAmount: dot.depositAmount,
			colorHex: `#${dot.mesh.material.color.getHexString()}`
		};
	}

	function computeBounds(dots: StrokeDot[]): DraftBounds | null {
		if (dots.length === 0) return null;
		let minX = Number.POSITIVE_INFINITY;
		let minY = Number.POSITIVE_INFINITY;
		let minZ = Number.POSITIVE_INFINITY;
		let maxX = Number.NEGATIVE_INFINITY;
		let maxY = Number.NEGATIVE_INFINITY;
		let maxZ = Number.NEGATIVE_INFINITY;

		for (const dot of dots) {
			const radius = Math.max(0.0001, dot.radius);
			minX = Math.min(minX, dot.position.x - radius);
			minY = Math.min(minY, dot.position.y - radius);
			minZ = Math.min(minZ, dot.position.z - radius);
			maxX = Math.max(maxX, dot.position.x + radius);
			maxY = Math.max(maxY, dot.position.y + radius);
			maxZ = Math.max(maxZ, dot.position.z + radius);
		}

		return {
			minX,
			minY,
			minZ,
			maxX,
			maxY,
			maxZ
		};
	}

	export function getDraftSummary(maxDots = 3200): DraftSummary {
		const activeDots = strokeDots.filter((dot) => dot.depositAmount > 1e-6);
		const dotCount = activeDots.length;
		const strokeCount = strokeRoot.children.length;

		const sampledDots: DraftExportDot[] = [];
		const step = dotCount > maxDots ? Math.ceil(dotCount / maxDots) : 1;
		for (let i = 0; i < dotCount; i += step) {
			sampledDots.push(toDraftExportDot(activeDots[i]));
		}

		const sumRadius = activeDots.reduce((acc, dot) => acc + dot.radius, 0);
		const sumDeposit = activeDots.reduce((acc, dot) => acc + dot.depositAmount, 0);

		return {
			strokeCount,
			dotCount,
			averageRadius: dotCount > 0 ? sumRadius / dotCount : 0,
			averageDepositAmount: dotCount > 0 ? sumDeposit / dotCount : 0,
			bounds: computeBounds(activeDots),
			dots: sampledDots
		};
	}

	function onPointerDown(event: PointerEvent) {
		if (!mainCanvas || !cameraLock) return;

		if (event.button === 0 && event.shiftKey) {
			const hitStrokeId = getStrokeIdAtPointer(event);
			const additive = event.metaKey || event.ctrlKey;
			setSelectedStroke(hitStrokeId, {
				additive,
				toggle: additive
			});
			return;
		}

		const shouldPan = event.button === 2 || inputMode === 'pan';

		if (shouldPan) {
			isPanning = true;
			panStartX = event.clientX;
			panStartY = event.clientY;
			mainCanvas.setPointerCapture(event.pointerId);
			return;
		}

		if (event.button !== 0) return;
		if (drawLocked || editLocked) return;
		const point = getWorldPoint(event);
		if (!point) return;
		isDrawing = true;
		activeStrokeTool = drawTool;
		if (activeStrokeTool === 'erase') {
			startErase(point);
		} else {
			startStroke(point);
		}
		mainCanvas.setPointerCapture(event.pointerId);
	}

	function panCamera(deltaX: number, deltaY: number) {
		if (!mainCamera || !mainWrap) return;
		const width = Math.max(1, mainWrap.clientWidth);
		const height = Math.max(1, mainWrap.clientHeight);
		const worldW = (mainCamera.right - mainCamera.left) / mainCamera.zoom;
		const worldH = (mainCamera.top - mainCamera.bottom) / mainCamera.zoom;
		const moveX = (-deltaX / width) * worldW;
		const moveY = (deltaY / height) * worldH;

		const right = new THREE.Vector3(1, 0, 0).applyQuaternion(mainCamera.quaternion);
		const up = new THREE.Vector3(0, 1, 0).applyQuaternion(mainCamera.quaternion);
		const move = right.multiplyScalar(moveX).add(up.multiplyScalar(moveY));

		stageTarget.add(move);
		mainCamera.position.add(move);
		mainCamera.lookAt(stageTarget);
		syncDrawPlane();
		syncGuideAnchorsToSlice();

		if (pipControls) {
			pipControls.target.copy(stageTarget);
		}
	}

	function onPointerMove(event: PointerEvent) {
		if (isPanning) {
			const dx = event.clientX - panStartX;
			const dy = event.clientY - panStartY;
			panStartX = event.clientX;
			panStartY = event.clientY;
			panCamera(dx, dy);
			return;
		}

		if (!isDrawing || !cameraLock) return;
		const point = getWorldPoint(event);
		if (!point) return;
		if (activeStrokeTool === 'erase') {
			eraseAlongSegment(point);
		} else {
			appendStrokePointWithArcResample(point);
		}
	}

	function onPointerEnd(event: PointerEvent) {
		if (!mainCanvas) return;
		if (isDrawing) {
			if (activeStrokeTool === 'erase') {
				finishErase();
			} else {
				finishStroke();
			}
			flowPauseSec = FLOW_PAUSE_AFTER_STROKE_SEC;
		}
		isDrawing = false;
		isPanning = false;
		if (mainCanvas.hasPointerCapture(event.pointerId)) {
			mainCanvas.releasePointerCapture(event.pointerId);
		}
	}

	function onWheel(event: WheelEvent) {
		if (!mainCamera || !cameraLock) return;
		event.preventDefault();
		zoomMain(Math.exp(-event.deltaY * 0.0012));
	}

	function isTypingTarget(target: EventTarget | null) {
		if (!(target instanceof HTMLElement)) return false;
		const tag = target.tagName.toLowerCase();
		return tag === 'input' || tag === 'textarea' || tag === 'select' || target.isContentEditable;
	}

	function onGlobalKeyDown(event: KeyboardEvent) {
		if (isTypingTarget(event.target)) return;
		const meta = event.metaKey || event.ctrlKey;
		const key = event.key.toLowerCase();

		if (event.key === 'Escape') {
			clearStrokeSelection();
			return;
		}
		if (event.key === 'Delete' || event.key === 'Backspace') {
			if (deleteSelectedStroke()) event.preventDefault();
			return;
		}

		if (!meta) return;

		if (key === 'z') {
			if (event.shiftKey) {
				redoLastStroke();
			} else {
				undoLastStroke();
			}
			event.preventDefault();
			return;
		}
		if (key === 'y') {
			redoLastStroke();
			event.preventDefault();
			return;
		}

		if (key === 'c') {
			if (copySelectedStroke()) event.preventDefault();
			return;
		}
		if (key === 'x') {
			if (cutSelectedStroke()) event.preventDefault();
			return;
		}
		if (key === 'v') {
			if (pasteCopiedStroke()) event.preventDefault();
			return;
		}
		if (key === 'd') {
			if (duplicateSelectedStroke()) event.preventDefault();
			return;
		}
		if (key === 'a') {
			if (selectAllStrokes()) event.preventDefault();
		}
	}

	function handleResize() {
		if (!mainWrap || !mainRenderer || !pipRenderer || !mainCamera || !pipCamera) return;

		const width = Math.max(320, mainWrap.clientWidth);
		const height = Math.max(260, mainWrap.clientHeight);
		mainRenderer.setSize(width, height, false);
		const aspect = width / height;
		mainCamera.left = -ORTHO_HALF_HEIGHT * aspect;
		mainCamera.right = ORTHO_HALF_HEIGHT * aspect;
		mainCamera.top = ORTHO_HALF_HEIGHT;
		mainCamera.bottom = -ORTHO_HALF_HEIGHT;
		mainCamera.updateProjectionMatrix();

		const pipMin = width < 700 ? 132 : showInternalChrome ? 200 : 220;
		const pipMax = width < 700 ? 220 : 420;
		const pipWidth = Math.max(pipMin, Math.min(pipMax, width * (showInternalChrome ? 0.34 : 0.4)));
		const pipHeight = Math.round(pipWidth * 0.66);
		pipViewportWidth = pipWidth;
		pipViewportHeight = pipHeight;
		pipRenderer.setSize(pipWidth, pipHeight, false);
		pipCamera.aspect = pipWidth / pipHeight;
		pipCamera.updateProjectionMatrix();
		requestAnimationFrame(() => {
			clampPipPosition(!pipMovedByUser);
		});
	}

	function startRenderLoop() {
		if (!scene || !mainRenderer || !pipRenderer || !mainCamera || !pipCamera) return;
		const sceneRef = scene;
		const mainRendererRef = mainRenderer;
		const pipRendererRef = pipRenderer;
		const mainCameraRef = mainCamera;
		const pipCameraRef = pipCamera;

		let lastTimestampMs = performance.now();
		const render = (timestampMs: number) => {
			const dtSec = Math.min(0.05, Math.max(0, (timestampMs - lastTimestampMs) / 1000));
			lastTimestampMs = timestampMs;
			if (flowPauseSec > 0) {
				flowPauseSec = Math.max(0, flowPauseSec - dtSec);
			} else if (!isDrawing) {
				simulateViscousSand(dtSec);
			}
			if (smoothSurfaceDirty) {
				rebuildSmoothSurface();
				smoothSurfaceDirty = false;
			}
			pipControls?.update();
			mainRendererRef.render(sceneRef, mainCameraRef);
			pipRendererRef.render(sceneRef, pipCameraRef);
			animationFrame = requestAnimationFrame(render);
		};
		animationFrame = requestAnimationFrame(render);
	}

	function stopRenderLoop() {
		if (animationFrame) cancelAnimationFrame(animationFrame);
	}

	function disposeStage() {
		stopRenderLoop();
		resizeObserver?.disconnect();
		pipControls?.dispose();

		if (guidePlane) {
			guidePlane.geometry.dispose();
			guidePlane.material.dispose();
		}
		if (guideGrid) {
			guideGrid.geometry.dispose();
			guideGrid.material.dispose();
		}
		if (guideAxes) {
			for (const child of guideAxes.children) {
				if (child instanceof THREE.Line) {
					child.geometry.dispose();
					child.material.dispose();
				}
			}
		}
		disposePipSliceOverlay();
		if (smoothSurface) {
			scene?.remove(smoothSurface);
			smoothSurface.geometry.dispose();
			smoothSurface = null;
		}
		smoothSurfaceMaterial?.dispose();
		smoothSurfaceMaterial = null;

		unitSphere.dispose();
		mainRenderer?.dispose();
		pipRenderer?.dispose();
	}

	onMount(() => {
		isCoarsePointer = window.matchMedia('(pointer: coarse)').matches;
		setupStage();
		window.addEventListener('keydown', onGlobalKeyDown);
		if (mainWrap) {
			resizeObserver = new ResizeObserver(() => handleResize());
			resizeObserver.observe(mainWrap);
		}
	});

	onDestroy(() => {
		window.removeEventListener('keydown', onGlobalKeyDown);
		disposeStage();
	});
</script>

<div class="stage-root {showInternalChrome ? '' : 'stage-root-minimal'}">
	{#if showInternalChrome}
		<div class="stage-toolbar">
			<div class="view-tabs" role="tablist" aria-label="Fixed camera angles">
				{#each viewOrder as view}
					<button
						type="button"
						class="view-btn {activeView === view ? 'active' : ''}"
						on:click={() => updateMainView(view)}
						role="tab"
						aria-selected={activeView === view}
					>
						{VIEW_CONFIGS[view].label}
					</button>
				{/each}
			</div>
			<div class="toolbar-right">
				<div class="mode-toggle" aria-label="Input mode">
					<button
						type="button"
						class="toolbar-btn mode-btn {inputMode === 'draw' ? 'mode-active' : ''}"
						on:click={() => setInputMode('draw')}
					>
						Draw
					</button>
					<button
						type="button"
						class="toolbar-btn mode-btn {inputMode === 'pan' ? 'mode-active' : ''}"
						on:click={() => setInputMode('pan')}
					>
						Pan
					</button>
				</div>
				<span class="lock-chip">{cameraLock ? 'Locked Camera (Default)' : 'Free Camera'}</span>
				<button type="button" class="toolbar-btn" on:click={() => zoomMain(1.15)}>Zoom +</button>
				<button type="button" class="toolbar-btn" on:click={() => zoomMain(0.87)}>Zoom -</button>
				<button type="button" class="toolbar-btn desktop-only-control" on:click={resetMainView}>
					Reset View
				</button>
				<button type="button" class="toolbar-btn" on:click={undoLastStroke}>Undo Stroke</button>
				<button type="button" class="toolbar-btn desktop-only-control" on:click={clearAllStrokes}>
					Clear
				</button>
			</div>
		</div>

		<div class="mobile-quick" aria-label="모바일 퀵 브러시 패널">
			<div class="mobile-size-wrap">
				<span>Size {Math.round(brushSize)}</span>
				<input class="mobile-size" type="range" min="1" max="60" bind:value={brushSize} />
			</div>
			<div class="mobile-color-wrap">
				{#each quickPalette as color}
					<button
						type="button"
						class="mobile-swatch {brushColorHex === color ? 'active' : ''}"
						style={`--swatch:${color};`}
						on:click={() => (brushColorHex = color)}
						aria-label={`색상 ${color}`}
					></button>
				{/each}
				<input class="mobile-color-input" type="color" bind:value={brushColorHex} aria-label="커스텀 색상" />
			</div>
		</div>
	{/if}

	<div class="main-wrap" bind:this={mainWrap}>
		<canvas
			class="main-canvas"
			bind:this={mainCanvas}
			on:pointerdown={onPointerDown}
			on:pointermove={onPointerMove}
			on:pointerup={onPointerEnd}
			on:pointercancel={onPointerEnd}
			on:wheel={onWheel}
			on:contextmenu|preventDefault
		></canvas>

		<div
			class="pip-wrap {pipDragging ? 'dragging' : ''}"
			bind:this={pipWrap}
			style={`left:${pipPosX}px;top:${pipPosY}px;`}
		>
			<button
				type="button"
				class="pip-drag-handle"
				aria-label="Move PIP"
				on:pointerdown={startPipDrag}
				on:pointermove={movePipDrag}
				on:pointerup={endPipDrag}
				on:pointercancel={endPipDrag}
			>
				⋮⋮
			</button>
			<canvas
				class="pip-canvas"
				bind:this={pipCanvas}
				style={`width:${pipViewportWidth}px;height:${pipViewportHeight}px;`}
			></canvas>
			<button type="button" class="pip-mini-reset" on:click={resetQuarterView} aria-label="PIP reset">
				↺
			</button>
		</div>

			{#if showInternalChrome}
				<p class="stage-help">
					{#if isCoarsePointer}
						{inputMode === 'draw'
							? `${drawTool === 'fill' ? 'Fill' : drawTool === 'erase' ? 'Erase' : 'Draw'} 모드에서 터치 드로잉`
							: 'Pan 모드에서 터치 이동'} · {autoFillClosedStroke
							? '닫힌 선 자동 면채움 ON'
							: '드래그 경로 수동 채움'} · {mirrorDraw ? '좌우 대칭 ON' : '단일 드로우'} · {smoothMeshView
							? '스무딩 메시 ON'
							: '도트 표현 ON'} · {sliceEnabled ? `슬라이스 ${sliceDepth.toFixed(2)}` : '슬라이스 OFF'}
					{:else}
						좌클릭 {drawTool === 'fill' ? 'Fill' : drawTool === 'erase' ? 'Erase' : 'Draw'} · 우클릭 팬 · 휠 줌 · {autoFillClosedStroke
							? '닫힌 선 자동 면채움 ON'
							: '드래그 경로 수동 채움'} · {mirrorDraw ? '좌우 대칭 ON' : '단일 드로우'} · {smoothMeshView
							? '스무딩 메시 ON'
							: '도트 표현 ON'} · {sliceEnabled ? `슬라이스 ${sliceDepth.toFixed(2)}` : '슬라이스 OFF'}
					{/if}
				</p>
			{/if}
	</div>
</div>

<style>
	.stage-root {
		width: 100%;
		height: 100%;
		display: grid;
		grid-template-rows: auto 1fr;
		gap: 10px;
	}

	.stage-root-minimal {
		grid-template-rows: 1fr;
		gap: 0;
	}

	.stage-root-minimal .main-wrap {
		min-height: 100%;
		border: none;
		border-radius: 0;
	}

	.stage-root-minimal .pip-wrap {
		padding: 2px;
		border-radius: 6px;
		border: none;
		background: rgba(20, 24, 33, 0.24);
		backdrop-filter: blur(2px);
		box-shadow: none;
	}

	.stage-root-minimal .pip-canvas {
		width: 176px;
		height: 116px;
		border-radius: 5px;
	}

	.stage-root-minimal .pip-mini-reset {
		top: 2px;
		right: 2px;
		width: 18px;
		height: 18px;
		background: rgba(245, 248, 255, 0.78);
		font-size: 0.68rem;
	}

	.stage-toolbar {
		display: flex;
		justify-content: space-between;
		align-items: center;
		gap: 10px;
		flex-wrap: wrap;
	}

	.view-tabs {
		display: flex;
		gap: 6px;
		flex-wrap: wrap;
	}

	.view-btn,
	.toolbar-btn {
		border: 1px solid #d1d9ea;
		border-radius: 8px;
		background: #ffffff;
		padding: 6px 10px;
		font-size: 0.84rem;
		font-weight: 600;
		color: #1f2937;
		cursor: pointer;
	}

	.view-btn.active {
		border-color: #2563eb;
		background: #dbeafe;
		color: #1d4ed8;
	}

	.toolbar-right {
		display: flex;
		align-items: center;
		gap: 6px;
		flex-wrap: wrap;
	}

	.mode-toggle {
		display: inline-flex;
		gap: 4px;
	}

	.mode-btn.mode-active {
		border-color: #0ea5e9;
		background: #e0f2fe;
		color: #0369a1;
	}

	.mobile-quick {
		display: none;
	}

	.mobile-size-wrap {
		display: grid;
		gap: 4px;
		font-size: 0.74rem;
		font-weight: 700;
		color: #334155;
	}

	.mobile-size {
		width: 100%;
	}

	.mobile-color-wrap {
		display: flex;
		gap: 5px;
		align-items: center;
		overflow-x: auto;
		padding-bottom: 2px;
	}

	.mobile-swatch {
		flex: 0 0 auto;
		width: 20px;
		height: 20px;
		border-radius: 6px;
		border: 1px solid rgba(148, 163, 184, 0.7);
		background: var(--swatch);
	}

	.mobile-swatch.active {
		outline: 2px solid #1d4ed8;
		outline-offset: 1px;
	}

	.mobile-color-input {
		flex: 0 0 auto;
		width: 24px;
		height: 20px;
		padding: 0;
		border: none;
		background: transparent;
	}

	.lock-chip {
		font-size: 0.78rem;
		font-weight: 700;
		background: #dcfce7;
		color: #166534;
		padding: 5px 9px;
		border-radius: 999px;
	}

	.main-wrap {
		position: relative;
		width: 100%;
		height: 100%;
		min-height: 460px;
		border: 1px solid #dbe2f2;
		border-radius: 10px;
		overflow: hidden;
		background:
			linear-gradient(0deg, rgba(15, 23, 42, 0.05) 1px, transparent 1px),
			linear-gradient(90deg, rgba(15, 23, 42, 0.05) 1px, transparent 1px),
			#f8fafc;
		background-size: 24px 24px, 24px 24px, auto;
	}

	.main-canvas {
		position: absolute;
		inset: 0;
		width: 100%;
		height: 100%;
		display: block;
		touch-action: none;
	}

	.pip-wrap {
		position: absolute;
		top: 12px;
		left: 12px;
		padding: 4px;
		border-radius: 8px;
		border: 1px solid rgba(199, 210, 254, 0.6);
		background: rgba(255, 255, 255, 0.65);
		backdrop-filter: blur(3px);
		box-shadow: 0 3px 10px rgba(15, 23, 42, 0.09);
		touch-action: none;
		user-select: none;
	}

	.pip-wrap.dragging {
		cursor: grabbing;
	}

	.pip-drag-handle {
		position: absolute;
		top: 4px;
		left: 4px;
		width: 22px;
		height: 22px;
		border: none;
		border-radius: 999px;
		background: rgba(255, 255, 255, 0.82);
		color: #334155;
		font-size: 0.64rem;
		font-weight: 700;
		line-height: 1;
		cursor: grab;
		z-index: 2;
	}

	.pip-canvas {
		border-radius: 6px;
		display: block;
	}

	.pip-mini-reset {
		position: absolute;
		top: 4px;
		right: 4px;
		width: 22px;
		height: 22px;
		border: none;
		border-radius: 999px;
		background: rgba(255, 255, 255, 0.78);
		font-size: 0.8rem;
		line-height: 1;
		color: #334155;
	}

	.stage-help {
		position: absolute;
		left: 12px;
		bottom: 10px;
		margin: 0;
		padding: 6px 10px;
		border-radius: 999px;
		background: rgba(255, 255, 255, 0.94);
		border: 1px solid #dbe2f2;
		font-size: 0.76rem;
		font-weight: 600;
		color: #475569;
	}

	@media (max-width: 960px) {
		.stage-toolbar {
			align-items: flex-start;
			gap: 6px;
		}

		.view-tabs {
			max-width: 100%;
			overflow-x: auto;
			flex-wrap: nowrap;
			padding-bottom: 2px;
		}

		.toolbar-right {
			width: auto;
			margin-left: auto;
			gap: 4px;
		}

		.toolbar-btn {
			min-height: 32px;
			padding: 5px 8px;
			font-size: 0.76rem;
		}

		.lock-chip,
		.desktop-only-control {
			display: none;
		}

		.mobile-quick {
			display: grid;
			gap: 6px;
			padding: 6px 8px;
			border-radius: 9px;
			border: 1px solid #dbe2f2;
			background: rgba(255, 255, 255, 0.95);
		}

		.main-wrap {
			min-height: 67vh;
		}

		.pip-wrap {
			padding: 2px;
			border: none;
			background: rgba(255, 255, 255, 0.3);
			box-shadow: none;
		}

		.stage-help {
			display: none;
		}
	}

	@media (max-width: 640px) {
		.main-wrap {
			min-height: 70vh;
		}

		.pip-mini-reset {
			display: none;
		}

	}
</style>

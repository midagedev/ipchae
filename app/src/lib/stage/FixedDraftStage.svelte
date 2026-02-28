<script lang="ts">
	import { onDestroy, onMount } from 'svelte';
	import * as THREE from 'three';
	import { OrbitControls } from 'three/examples/jsm/controls/OrbitControls.js';

	type ViewId = 'front' | 'back' | 'left' | 'right' | 'top';

	type ViewConfig = {
		label: string;
		position: [number, number, number];
		up: [number, number, number];
		normal: [number, number, number];
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

	const viewOrder: ViewId[] = ['front', 'right', 'top', 'left', 'back'];

	export let brushSize = 40;
	export let brushStrength = 0.45;
	export let brushColorHex = '#2563eb';
	export let paletteColors: string[] = [];

	type InputMode = 'draw' | 'pan';
	type BrushDotMesh = THREE.Mesh<THREE.SphereGeometry, THREE.MeshStandardMaterial>;
	type StrokeDot = {
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

	let activeView: ViewId = 'front';
	let cameraLock = true;
	let inputMode: InputMode = 'draw';
	let isCoarsePointer = false;

	let mainWrap: HTMLDivElement | undefined;
	let mainCanvas: HTMLCanvasElement | undefined;
	let pipCanvas: HTMLCanvasElement | undefined;

	let mainRenderer: THREE.WebGLRenderer | null = null;
	let pipRenderer: THREE.WebGLRenderer | null = null;
	let scene: THREE.Scene | null = null;
	let mainCamera: THREE.OrthographicCamera | null = null;
	let pipCamera: THREE.PerspectiveCamera | null = null;
	let pipControls: OrbitControls | null = null;

	let animationFrame = 0;
	let resizeObserver: ResizeObserver | null = null;

	let guidePlane: THREE.Mesh<THREE.PlaneGeometry, THREE.MeshBasicMaterial> | null = null;
	const drawPlane = new THREE.Plane(new THREE.Vector3(0, 0, 1), 0);
	const activeNormal = new THREE.Vector3(...VIEW_CONFIGS.front.normal).normalize();
	const activeTangentU = new THREE.Vector3(1, 0, 0);
	const activeTangentV = new THREE.Vector3(0, 1, 0);
	const raycaster = new THREE.Raycaster();
	const pointer = new THREE.Vector2();
	const stageTarget = new THREE.Vector3(0, 0, 0);
	const tmpSampleDelta = new THREE.Vector3();

	const strokeRoot = new THREE.Group();
	const strokeHistory: THREE.Group[] = [];
	const strokeDots: StrokeDot[] = [];
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
	let isDrawing = false;
	let isPanning = false;
	let panStartX = 0;
	let panStartY = 0;

	const ORTHO_HALF_HEIGHT = 5.5;
	const MIN_ZOOM = 0.55;
	const MAX_ZOOM = 6;
	const STACK_CELL_SIZE = 0.1;
	const PATH_SAMPLE_STEP_RATIO = 0.45;
	const MIN_PATH_SAMPLE_STEP = 0.012;
	const MAX_PATH_STEPS = 160;
	const FLOW_NEIGHBORS: Array<[number, number]> = [
		[1, 0],
		[-1, 0],
		[0, 1],
		[0, -1]
	];
	const SAND_REPOSE_GRADIENT = Math.tan(THREE.MathUtils.degToRad(34));
	const FLOW_RATE = 5.2;
	const FLOW_ITERATIONS = 2;
	const FLOW_HARDEN_TAU = 0.65;
	const FLOW_MIN_WETNESS = 0.016;
	const FLOW_MAX_TRANSFER_RATIO = 0.58;
	const FLOW_CARRY_RATIO = 0.92;

	$: brushRadius = 0.02 + (Math.max(1, Math.min(brushSize, 60)) / 60) * 0.18;
	$: brushRoughness = THREE.MathUtils.clamp(0.7 - brushStrength * 0.35, 0.2, 0.75);
	$: quickPalette =
		(paletteColors.length
			? paletteColors
			: ['#111827', '#ef4444', '#f59e0b', '#22c55e', '#06b6d4', '#3b82f6', '#8b5cf6', '#ffffff']
		).slice(0, 10);

	function resolveBrushColor() {
		const color = new THREE.Color();
		color.set(brushColorHex || '#2563eb');
		return color;
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

		pipCamera = new THREE.PerspectiveCamera(45, 1, 0.1, 200);
		pipCamera.position.set(8, 6, 8);
		pipCamera.lookAt(stageTarget);

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

		const normal = new THREE.Vector3(...normalTuple).normalize();
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
		guidePlane.quaternion.setFromUnitVectors(new THREE.Vector3(0, 0, 1), normal);
		guidePlane.position.copy(stageTarget);
		scene.add(guidePlane);
	}

	function syncDrawPlane() {
		const config = VIEW_CONFIGS[activeView];
		activeNormal.set(...config.normal).normalize();
		activeTangentV.set(...config.up).normalize();
		activeTangentV.addScaledVector(activeNormal, -activeTangentV.dot(activeNormal)).normalize();
		activeTangentU.crossVectors(activeNormal, activeTangentV).normalize();
		drawPlane.setFromNormalAndCoplanarPoint(activeNormal, stageTarget);
	}

	function updateMainView(nextView: ViewId) {
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

	function setInputMode(nextMode: InputMode) {
		inputMode = nextMode;
	}

	function zoomMain(zoomFactor: number) {
		if (!mainCamera) return;
		mainCamera.zoom = THREE.MathUtils.clamp(mainCamera.zoom * zoomFactor, MIN_ZOOM, MAX_ZOOM);
		mainCamera.updateProjectionMatrix();
	}

	function resetMainView() {
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

	function startStroke(point: THREE.Vector3) {
		activeStroke = new THREE.Group();
		const strokeId = `stroke-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
		activeStroke.name = strokeId;
		activeStroke.userData.strokeId = strokeId;
		strokeRoot.add(activeStroke);
		strokeHistory.push(activeStroke);
		strokeSupportView = activeView;
		strokeSupportMap = new Map(stackHeightMaps[activeView]);
		lastSurfacePoint = null;
		strokeInputPoints.length = 0;
		strokeInputPoints.push(point.clone());
		lastSmoothedPoint = point.clone();
		pushBrushDot(point);
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
			if (excludeStrokeId && dot.strokeId === excludeStrokeId) continue;

			tmpSampleDelta.subVectors(dot.position, basePoint);
			const along = tmpSampleDelta.dot(normal);
			const radialSq = Math.max(0, tmpSampleDelta.lengthSq() - along * along);
			const radiusSq = dot.radius * dot.radius;
			if (radialSq > radiusSq) continue;

			const cap = Math.sqrt(Math.max(0, radiusSq - radialSq));
			const candidate = along + cap;
			if (candidate > maxHeight) {
				maxHeight = candidate;
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
	}

	function refreshAllDotHeights() {
		for (const dot of strokeDots) {
			refreshDotHeight(dot);
		}
	}

	function rebuildHeightMaps() {
		for (const view of viewOrder) {
			stackHeightMaps[view].clear();
			wetnessMaps[view].clear();
		}
		for (const dot of strokeDots) {
			depositHeight(dot.view, dot.u, dot.v, dot.depositRadius, dot.depositAmount);
		}
	}

	function pushBrushDot(point: THREE.Vector3, options?: { force?: boolean }) {
		if (!activeStroke) return;
		const force = options?.force ?? false;
		const minSpacing = brushRadius * 0.28;
		if (!force && lastSurfacePoint && lastSurfacePoint.distanceToSquared(point) < minSpacing * minSpacing) {
			return;
		}

		const { u, v } = projectToActiveUV(point);
		const layerStep = brushRadius * THREE.MathUtils.clamp(0.26 + brushStrength * 0.92, 0.26, 1.35);
		const depositRadius = brushRadius * 1.1;
		const depositAmount = layerStep * 0.9;
		const wetnessBoost = THREE.MathUtils.clamp(0.34 + brushStrength * 0.46, 0.2, 0.86);
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
		brushDot.scale.setScalar(brushRadius);
		activeStroke.add(brushDot);
		strokeDots.push({
			mesh: brushDot,
			basePoint: point.clone(),
			position: liftedPoint.clone(),
			u,
			v,
			height: dotHeight,
			radius: brushRadius,
			depositRadius,
			depositAmount,
			view: activeView,
			strokeId
		});
		lastSurfacePoint = point.clone();
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
	}

	function resolveSegmentSteps(length: number) {
		const stepLength = Math.max(brushRadius * PATH_SAMPLE_STEP_RATIO, MIN_PATH_SAMPLE_STEP);
		return Math.min(MAX_PATH_STEPS, Math.max(1, Math.ceil(length / stepLength)));
	}

	function fillLinearSegment(fromPoint: THREE.Vector3, toPoint: THREE.Vector3) {
		const distance = fromPoint.distanceTo(toPoint);
		if (distance <= 1e-6) return;
		const steps = resolveSegmentSteps(distance);
		for (let step = 1; step <= steps; step += 1) {
			const t = step / steps;
			const samplePoint = fromPoint.clone().lerp(toPoint, t);
			pushBrushDot(samplePoint, { force: true });
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
			pushBrushDot(samplePoint, { force: true });
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

	function finishStroke() {
		if (activeStroke && strokeInputPoints.length >= 2 && lastSmoothedPoint) {
			const tailPoint = strokeInputPoints[strokeInputPoints.length - 1];
			fillLinearSegment(lastSmoothedPoint, tailPoint);
		}
		activeStroke = null;
		lastSurfacePoint = null;
		strokeInputPoints.length = 0;
		lastSmoothedPoint = null;
		strokeSupportMap = null;
		strokeSupportView = null;
	}

	function undoLastStroke() {
		const latest = strokeHistory.pop();
		if (!latest) return;
		const strokeId = String(latest.userData.strokeId ?? latest.name);
		strokeRoot.remove(latest);

		for (let i = strokeDots.length - 1; i >= 0; i -= 1) {
			if (strokeDots[i].strokeId === strokeId) {
				strokeDots.splice(i, 1);
			}
		}
		rebuildHeightMaps();
		refreshAllDotHeights();

		for (const child of latest.children) {
			if (child instanceof THREE.Mesh) {
				child.material.dispose();
			}
		}
	}

	function clearAllStrokes() {
		while (strokeHistory.length > 0) {
			undoLastStroke();
		}
	}

	function onPointerDown(event: PointerEvent) {
		if (!mainCanvas || !cameraLock) return;
		const shouldPan = event.button === 2 || inputMode === 'pan';

		if (shouldPan) {
			isPanning = true;
			panStartX = event.clientX;
			panStartY = event.clientY;
			mainCanvas.setPointerCapture(event.pointerId);
			return;
		}

		if (event.button !== 0) return;
		const point = getWorldPoint(event);
		if (!point) return;
		isDrawing = true;
		startStroke(point);
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
		guidePlane?.position.copy(stageTarget);

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
		fillStrokeCurve(point);
	}

	function onPointerEnd(event: PointerEvent) {
		if (!mainCanvas) return;
		if (isDrawing) finishStroke();
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

		const pipWidth = Math.max(180, Math.min(280, width * 0.3));
		const pipHeight = Math.round(pipWidth * 0.66);
		pipRenderer.setSize(pipWidth, pipHeight, false);
		pipCamera.aspect = pipWidth / pipHeight;
		pipCamera.updateProjectionMatrix();
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
			simulateViscousSand(dtSec);
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

		unitSphere.dispose();
		mainRenderer?.dispose();
		pipRenderer?.dispose();
	}

	onMount(() => {
		isCoarsePointer = window.matchMedia('(pointer: coarse)').matches;
		setupStage();
		if (mainWrap) {
			resizeObserver = new ResizeObserver(() => handleResize());
			resizeObserver.observe(mainWrap);
		}
	});

	onDestroy(() => {
		disposeStage();
	});
</script>

<div class="stage-root">
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

		<div class="pip-wrap">
			<canvas class="pip-canvas" bind:this={pipCanvas}></canvas>
			<button type="button" class="pip-mini-reset" on:click={resetQuarterView} aria-label="PIP reset">
				↺
			</button>
		</div>

			<p class="stage-help">
				{#if isCoarsePointer}
					{inputMode === 'draw' ? 'Draw 모드에서 터치 드로잉' : 'Pan 모드에서 터치 이동'} · Zoom +/- 버튼 사용
				{:else}
					좌클릭 드로잉 · 우클릭 팬 · 휠 줌 · 드래그 이동 경로에 적층
				{/if}
			</p>
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
		right: 12px;
		padding: 4px;
		border-radius: 8px;
		border: 1px solid rgba(199, 210, 254, 0.6);
		background: rgba(255, 255, 255, 0.65);
		backdrop-filter: blur(3px);
		box-shadow: 0 3px 10px rgba(15, 23, 42, 0.09);
	}

	.pip-canvas {
		width: 220px;
		height: 145px;
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

		.pip-canvas {
			width: 132px;
			height: 88px;
		}

		.stage-help {
			display: none;
		}
	}

	@media (max-width: 640px) {
		.pip-wrap {
			top: auto;
			bottom: 8px;
			right: 8px;
		}

		.pip-canvas {
			width: 112px;
			height: 74px;
		}

		.main-wrap {
			min-height: 70vh;
		}

		.pip-mini-reset {
			display: none;
		}
	}
</style>

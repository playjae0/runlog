import MapKit
import SwiftUI

struct FullscreenReplayView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(MapTheme.storageKey) private var selectedMapThemeRawValue = MapTheme.system.rawValue

    @StateObject private var replayModel: ReplayViewModel
    @State private var isOverlayVisible = true

    private var selectedMapTheme: MapTheme {
        MapTheme(rawValue: selectedMapThemeRawValue) ?? .system
    }

    init(
        workout: RunWorkout,
        initialMapProvider: MapProvider = .apple,
        initialPlaybackSpeed: PlaybackSpeed = .ten,
        initialCameraMode: ReplayCameraMode = .standard,
        initialIsCameraFollowing: Bool = true
    ) {
        _replayModel = StateObject(
            wrappedValue: ReplayViewModel(
                workout: workout,
                initialMapProvider: initialMapProvider,
                initialPlaybackSpeed: initialPlaybackSpeed,
                initialCameraMode: initialCameraMode,
                initialIsCameraFollowing: initialIsCameraFollowing
            )
        )
    }

    var body: some View {
        ZStack {
            fullscreenMap
                .ignoresSafeArea()

            Color.clear
                .contentShape(Rectangle())
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(RunTheme.smoothAnimation) {
                        isOverlayVisible.toggle()
                    }
                }

            centerStatusOverlay

            if isOverlayVisible {
                overlayChrome
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Color.black)
        .statusBarHidden()
        .task(id: replayModel.workout.id) {
            await replayModel.loadRoute()
        }
        .onReceive(replayModel.playbackTimer) { _ in
            replayModel.advancePlaybackIfNeeded()
        }
        .onReceive(replayModel.visualTimer) { _ in
            replayModel.advanceVisualProgressIfNeeded()
        }
        .onChange(of: replayModel.mapPosition) { _, newPosition in
            replayModel.handleMapPositionChange(newPosition)
        }
    }

    private var overlayChrome: some View {
        VStack(spacing: 0) {
            topOverlay
            Spacer()
            bottomOverlay
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 18)
    }

    private var topOverlay: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(RunTheme.overlayTextPrimary)
                    .frame(width: 40, height: 40)
                    .background(RunTheme.overlayBackground)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            Spacer()

            HStack(spacing: 8) {
                RunBadge(
                    text: replayModel.mapProvider.title,
                    systemImage: "map",
                    tone: .neutral
                )

                if replayModel.mapProvider == .apple {
                    RunBadge(
                        text: replayModel.cameraMode.label,
                        systemImage: "view.3d",
                        tone: .accent
                    )
                }
            }
        }
    }

    private var bottomOverlay: some View {
        VStack(alignment: .leading, spacing: 12) {
            metricsOverlay

            if replayModel.routeState.isLoaded {
                controlsOverlay
            }
        }
    }

    private var metricsOverlay: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(replayModel.cumulativeDistanceMeters.map { WorkoutFormatter.distance($0) } ?? "거리 없음")
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .foregroundStyle(RunTheme.overlayTextPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.65)

            HStack(spacing: 16) {
                fullscreenMetric(
                    title: "시간",
                    value: replayModel.elapsedTime.map(WorkoutFormatter.duration) ?? "시간 없음"
                )
                fullscreenMetric(
                    title: "현재 페이스",
                    value: replayModel.currentPaceText
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(RunTheme.overlayBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func fullscreenMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(RunTheme.caption)
                .foregroundStyle(RunTheme.overlayTextSecondary)

            Text(value)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(RunTheme.overlayTextPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }

    private var controlsOverlay: some View {
        HStack(spacing: 10) {
            Button {
                replayModel.togglePlayback()
            } label: {
                Image(systemName: replayModel.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(RunTheme.overlayTextPrimary)
                    .frame(width: 40, height: 40)
                    .background(RunTheme.overlayControlBackground)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(!replayModel.canReplay)

            Button {
                replayModel.resetPlayback()
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(RunTheme.overlayTextPrimary)
                    .frame(width: 40, height: 40)
                    .background(RunTheme.overlayControlBackground)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(replayModel.coordinates.isEmpty)

            Picker("재생 속도", selection: speedBinding) {
                ForEach(PlaybackSpeed.allCases) { speed in
                    Text(speed.label).tag(speed)
                }
            }
            .pickerStyle(.segmented)
            .disabled(!replayModel.canReplay)
        }
        .padding(12)
        .background(RunTheme.overlayBackground)
        .clipShape(Capsule())
    }

    private var speedBinding: Binding<PlaybackSpeed> {
        Binding(
            get: { replayModel.playbackSpeed },
            set: { replayModel.playbackSpeed = $0 }
        )
    }

    @ViewBuilder
    private var centerStatusOverlay: some View {
        switch replayModel.routeState {
        case .loading:
            fullscreenStatusCard(
                systemImage: "arrow.triangle.2.circlepath",
                text: "리플레이 경로를 읽는 중입니다..."
            )

        case .empty:
            fullscreenStatusCard(
                systemImage: "map",
                text: "이 workout에는 리플레이할 코스 좌표가 없습니다."
            )

        case .failed(let message):
            fullscreenStatusCard(
                systemImage: "exclamationmark.triangle",
                text: "리플레이 경로 읽기 실패: \(message)"
            )

        case .loaded:
            EmptyView()
        }
    }

    private func fullscreenStatusCard(systemImage: String, text: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(RunTheme.overlayTextPrimary)

            Text(text)
                .font(RunTheme.body)
                .foregroundStyle(RunTheme.overlayTextPrimary)
                .multilineTextAlignment(.center)
        }
        .padding(18)
        .background(RunTheme.overlayBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, 28)
    }

    @ViewBuilder
    private var fullscreenMap: some View {
        switch replayModel.mapProvider {
        case .apple:
            Map(position: mapPositionBinding, interactionModes: []) {
                ForEach(replayModel.completedVisibleSegments) { segment in
                    MapPolyline(coordinates: segment.coordinates)
                        .stroke(segment.paceClass.color, lineWidth: 5)
                }

                if let activeSegment = replayModel.activeVisibleSegment {
                    MapPolyline(coordinates: activeSegment.coordinates)
                        .stroke(activeSegment.paceClass.color, lineWidth: 5)
                }

                if let first = replayModel.coordinates.first {
                    Marker("Start", coordinate: first)
                }

                if replayModel.coordinates.count > 1,
                   let last = replayModel.coordinates.last {
                    Marker("Finish", coordinate: last)
                }

                if let displayedCurrentCoordinate = replayModel.displayedCurrentCoordinate {
                    Annotation("Current", coordinate: displayedCurrentCoordinate) {
                        ZStack {
                            Circle()
                                .fill(RunTheme.accent)
                                .frame(width: 18, height: 18)
                            Circle()
                                .stroke(RunTheme.mapMarkerStroke, lineWidth: 3)
                                .frame(width: 18, height: 18)
                        }
                    }
                }
            }
            .mapStyle(selectedMapTheme.mapStyle)
            .runMapTheme(selectedMapTheme)

        case .google:
            if GoogleMapsBootstrap.isConfigured {
                GoogleMapView(
                    routes: [replayModel.visibleCoordinates],
                    currentCoordinate: replayModel.displayedCurrentCoordinate,
                    lineColor: UIColor(RunTheme.routeAccent),
                    mapTheme: selectedMapTheme,
                    showsStartMarker: !replayModel.coordinates.isEmpty,
                    showsEndMarker: replayModel.coordinates.count > 1,
                    startCoordinate: replayModel.coordinates.first,
                    endCoordinate: replayModel.coordinates.count > 1 ? replayModel.coordinates.last : nil,
                    cameraFitRoutes: [replayModel.coordinates],
                    isInteractionEnabled: false
                )
            } else {
                Color.black
                    .overlay {
                        Text("Google Maps API 키를 설정하면 fullscreen 비교 지도를 확인할 수 있습니다.")
                            .font(RunTheme.body)
                            .foregroundStyle(RunTheme.overlayTextPrimary)
                            .multilineTextAlignment(.center)
                            .padding(24)
                    }
            }
        }
    }

    private var mapPositionBinding: Binding<MapCameraPosition> {
        Binding(
            get: { replayModel.mapPosition },
            set: { replayModel.mapPosition = $0 }
        )
    }
}

@MainActor
final class ReplayViewModel: ObservableObject {
    let workout: RunWorkout
    let playbackTimerInterval: TimeInterval = 0.25
    let playbackTimer = Timer.publish(every: 0.25, on: .main, in: .common).autoconnect()
    let visualTimer = Timer.publish(every: 0.06, on: .main, in: .common).autoconnect()

    @Published var route: RunRoute?
    @Published var replayPoints: [RunRoutePoint] = []
    @Published var replayCoordinates: [CLLocationCoordinate2D] = []
    @Published var replaySegments: [ReplayRouteSegment] = []
    @Published var cumulativeDistances: [Double] = []
    @Published var replayElapsedTimes: [TimeInterval] = []
    @Published var routeState: ReplayRouteState = .loading
    @Published var mapPosition: MapCameraPosition = .automatic
    @Published var isPlaying = false
    @Published var currentIndex = 0
    @Published var replayElapsedTime: TimeInterval = 0
    @Published var visualProgress = 0.0
    @Published var playbackSpeed: PlaybackSpeed
    @Published var mapProvider: MapProvider
    @Published var cameraMode: ReplayCameraMode
    @Published var isCameraFollowing: Bool
    @Published var lastCameraHeading: CLLocationDirection?
    @Published var smoothedCameraHeading: CLLocationDirection?
    @Published var suppressUserCameraChangeUntil: Date?
    @Published var isScrubbing = false

    private let healthKitService = HealthKitService()
    private let followSpan = MKCoordinateSpan(latitudeDelta: 0.0042, longitudeDelta: 0.0042)
    private let maxReplayPointCount = 900
    private let cinematicCameraDistance: CLLocationDistance = 360
    private let cinematicCameraPitch: CGFloat = 64
    private let visualFramesPerPlaybackTick = 4.0
    private let headingSmoothingFactor = 0.18
    private let programmaticCameraMoveGraceInterval: TimeInterval = 0.28
    private let initialPlaybackSpeed: PlaybackSpeed
    private let initialMapProvider: MapProvider
    private let initialCameraMode: ReplayCameraMode
    private let initialIsCameraFollowing: Bool

    init(
        workout: RunWorkout,
        initialMapProvider: MapProvider = .apple,
        initialPlaybackSpeed: PlaybackSpeed = .ten,
        initialCameraMode: ReplayCameraMode = .standard,
        initialIsCameraFollowing: Bool = true
    ) {
        self.workout = workout
        self.initialMapProvider = initialMapProvider
        self.initialPlaybackSpeed = initialPlaybackSpeed
        self.initialCameraMode = initialCameraMode
        self.initialIsCameraFollowing = initialIsCameraFollowing
        self.mapProvider = initialMapProvider
        self.playbackSpeed = initialPlaybackSpeed
        self.cameraMode = initialCameraMode
        self.isCameraFollowing = initialIsCameraFollowing
    }

    var coordinates: [CLLocationCoordinate2D] {
        replayCoordinates
    }

    var routePoints: [RunRoutePoint] {
        replayPoints
    }

    var lastIndex: Int {
        max(coordinates.count - 1, 0)
    }

    var clampedCurrentIndex: Int {
        min(max(currentIndex, 0), lastIndex)
    }

    var clampedVisualProgress: Double {
        min(max(visualProgress, 0), Double(lastIndex))
    }

    var visibleCoordinates: [CLLocationCoordinate2D] {
        Array(coordinates.prefix(clampedCurrentIndex + 1))
    }

    var completedVisibleSegments: [ReplayRouteSegment] {
        replaySegments.filter { $0.endIndex <= clampedCurrentIndex }
    }

    var activeVisibleSegment: ReplayRouteSegment? {
        guard let segment = replaySegments.first(where: {
            $0.startIndex < clampedCurrentIndex && $0.endIndex > clampedCurrentIndex
        }) else {
            return nil
        }

        let visiblePointCount = clampedCurrentIndex - segment.startIndex + 1
        guard visiblePointCount > 1 else {
            return nil
        }

        return ReplayRouteSegment(
            id: segment.id,
            startIndex: segment.startIndex,
            endIndex: clampedCurrentIndex,
            coordinates: Array(segment.coordinates.prefix(visiblePointCount)),
            paceClass: segment.paceClass
        )
    }

    var currentCoordinate: CLLocationCoordinate2D? {
        guard !coordinates.isEmpty else {
            return nil
        }

        return coordinates[clampedCurrentIndex]
    }

    var displayedCurrentCoordinate: CLLocationCoordinate2D? {
        interpolatedCoordinate(at: clampedVisualProgress) ?? currentCoordinate
    }

    var currentPoint: RunRoutePoint? {
        guard routePoints.indices.contains(clampedCurrentIndex) else {
            return nil
        }

        return routePoints[clampedCurrentIndex]
    }

    var totalReplayDuration: TimeInterval {
        replayElapsedTimes.last ?? 0
    }

    var elapsedTime: TimeInterval? {
        guard replayElapsedTimes.indices.contains(clampedCurrentIndex) else {
            return nil
        }

        return replayElapsedTimes[clampedCurrentIndex]
    }

    var cumulativeDistanceMeters: Double? {
        guard cumulativeDistances.indices.contains(clampedCurrentIndex) else {
            return nil
        }

        return cumulativeDistances[clampedCurrentIndex]
    }

    var currentPaceText: String {
        guard let elapsedTime,
              let cumulativeDistanceMeters,
              cumulativeDistanceMeters > 0,
              elapsedTime > 0 else {
            return "페이스 없음"
        }

        return WorkoutFormatter.averagePace(
            distanceMeters: cumulativeDistanceMeters,
            duration: elapsedTime
        )
    }

    var canReplay: Bool {
        coordinates.count > 1
    }

    var standardMapInteractionModes: MapInteractionModes {
        if mapProvider == .google {
            return .all
        }

        if cameraMode == .cinematic || isPlaying {
            return []
        }

        return .all
    }

    var cameraFollowStatusText: String {
        if mapProvider == .google {
            return "Google 지도 비교 모드에서는 경로 표시만 비교합니다."
        }

        if cameraMode == .cinematic {
            return "진행 방향을 따라 3D 카메라가 고정됩니다."
        }

        return isCameraFollowing ? "현재 위치 중심으로 이동합니다." : "지도를 직접 움직인 상태입니다."
    }

    func loadRoute() async {
        routeState = .loading

        let result = await healthKitService.fetchRoute(for: workout.id)

        switch result {
        case .success(let route):
            let maxReplayPointCount = self.maxReplayPointCount
            let preparedData = await Task.detached(priority: .userInitiated) {
                makeReplayPreparedData(
                    from: route,
                    maxReplayPointCount: maxReplayPointCount
                )
            }.value

            guard !Task.isCancelled else {
                return
            }

            self.route = route
            replayPoints = preparedData.replayPoints
            replayCoordinates = preparedData.replayCoordinates
            replaySegments = preparedData.replaySegments
            cumulativeDistances = preparedData.cumulativeDistances
            replayElapsedTimes = preparedData.replayElapsedTimes
            resetReplayState()

            if preparedData.replayPoints.isEmpty {
                routeState = .empty
            } else {
                routeState = .loaded(preparedData.replayPoints.count)
                mapPosition = .region(
                    RunRouteMapRegion.region(for: preparedData.replayCoordinates)
                )
            }

        case .failure(let error):
            route = nil
            replayPoints = []
            replayCoordinates = []
            replaySegments = []
            cumulativeDistances = []
            replayElapsedTimes = []
            resetReplayState()
            routeState = .failed(error.localizedDescription)
        }
    }

    func togglePlayback() {
        guard canReplay else {
            return
        }

        if !isPlaying, clampedCurrentIndex >= lastIndex {
            setCurrentIndex(0)
        }

        if !isPlaying {
            syncCameraToCurrentIndexIfNeeded(force: true)
        }

        isPlaying.toggle()
    }

    func resetPlayback() {
        isPlaying = false
        setCurrentIndex(0)
        debugReplayLog("reset")
    }

    func handleCameraModeChange(_ mode: ReplayCameraMode) {
        guard mapProvider == .apple else {
            return
        }

        guard !isPlaying else {
            debugReplayLog("ignored camera mode change while playing")
            return
        }

        lastCameraHeading = nil
        smoothedCameraHeading = nil
        isCameraFollowing = true

        debugReplayLog("camera mode changed to \(mode.label)")
        syncCameraToCurrentIndexIfNeeded(force: true)
    }

    func advancePlaybackIfNeeded() {
        guard isPlaying, canReplay, !isScrubbing else {
            return
        }

        let nextElapsedTime = min(
            replayElapsedTime + (playbackTimerInterval * playbackSpeed.factor),
            totalReplayDuration
        )
        replayElapsedTime = nextElapsedTime
        let nextIndex = index(forReplayElapsedTime: nextElapsedTime, startingAt: clampedCurrentIndex)

        if nextElapsedTime >= totalReplayDuration || nextIndex >= lastIndex {
            setCurrentIndex(lastIndex, syncReplayElapsedTime: false)
            replayElapsedTime = totalReplayDuration
            isPlaying = false
            debugReplayLog("auto stopped at last index \(lastIndex)")
        } else {
            setCurrentIndex(nextIndex, syncReplayElapsedTime: false)
        }
    }

    func advanceVisualProgressIfNeeded() {
        let targetProgress = Double(clampedCurrentIndex)

        guard visualProgress != targetProgress else {
            return
        }

        guard isPlaying, !isScrubbing else {
            visualProgress = targetProgress
            return
        }

        let delta = targetProgress - visualProgress
        let maxProgressStep = max(abs(delta) / visualFramesPerPlaybackTick, 0.2)

        if abs(delta) <= maxProgressStep {
            visualProgress = targetProgress
        } else {
            visualProgress += delta > 0 ? maxProgressStep : -maxProgressStep
        }

        syncCameraToVisualProgressIfNeeded()
    }

    func handleSliderEditingChanged(_ isEditing: Bool) {
        if isEditing {
            isScrubbing = true
            isPlaying = false
        } else {
            isScrubbing = false
            setCurrentIndex(clampedCurrentIndex)
        }
    }

    func setCurrentIndex(
        _ index: Int,
        shouldFollow: Bool = true,
        syncReplayElapsedTime: Bool = true
    ) {
        let nextIndex = clampedIndex(index)
        currentIndex = nextIndex

        if syncReplayElapsedTime {
            replayElapsedTime = elapsedTime(at: nextIndex)
        }

        if !isPlaying || isScrubbing {
            visualProgress = Double(nextIndex)
        }

        if shouldFollow {
            syncCameraToCurrentIndexIfNeeded(force: !isPlaying || isScrubbing)
        }
    }

    func handleMapPositionChange(_ newPosition: MapCameraPosition) {
        guard mapProvider == .apple else {
            return
        }

        guard newPosition.positionedByUser else {
            return
        }

        if let suppressUserCameraChangeUntil,
           Date() < suppressUserCameraChangeUntil {
            return
        }

        guard cameraMode == .standard, !isPlaying else {
            return
        }

        debugReplayLog("user gesture detected, follow off")
        isCameraFollowing = false
    }

    private func resetReplayState() {
        currentIndex = 0
        replayElapsedTime = 0
        visualProgress = 0
        isPlaying = false
        playbackSpeed = initialPlaybackSpeed
        mapProvider = initialMapProvider
        cameraMode = initialCameraMode
        isCameraFollowing = initialIsCameraFollowing
        lastCameraHeading = nil
        smoothedCameraHeading = nil
        suppressUserCameraChangeUntil = nil
        isScrubbing = false
    }

    private func clampedIndex(_ index: Int) -> Int {
        min(max(index, 0), lastIndex)
    }

    private func elapsedTime(at index: Int) -> TimeInterval {
        let index = clampedIndex(index)

        guard replayElapsedTimes.indices.contains(index) else {
            return 0
        }

        return replayElapsedTimes[index]
    }

    private func index(
        forReplayElapsedTime replayElapsedTime: TimeInterval,
        startingAt startIndex: Int
    ) -> Int {
        guard canReplay else {
            return 0
        }

        let clampedElapsedTime = min(max(replayElapsedTime, 0), totalReplayDuration)
        var index = clampedIndex(startIndex)

        if elapsedTime(at: index) <= clampedElapsedTime {
            while index < lastIndex, elapsedTime(at: index + 1) <= clampedElapsedTime {
                index += 1
            }

            return index
        }

        var lowerBound = 0
        var upperBound = index

        while lowerBound < upperBound {
            let midIndex = (lowerBound + upperBound + 1) / 2

            if elapsedTime(at: midIndex) <= clampedElapsedTime {
                lowerBound = midIndex
            } else {
                upperBound = midIndex - 1
            }
        }

        return lowerBound
    }

    private func syncCameraToCurrentIndexIfNeeded(force: Bool = false) {
        guard mapProvider == .apple else {
            return
        }

        guard isCameraFollowing else {
            return
        }

        let progress = currentPlaybackProgress(forceCurrentIndex: force || !isPlaying || isScrubbing)
        guard let cameraCoordinate = interpolatedCoordinate(at: progress) ?? currentCoordinate else {
            return
        }

        let currentHeading = bearing(at: progress)
        lastCameraHeading = currentHeading
        let cameraHeading = smoothedHeading(
            toward: currentHeading,
            reset: force && !isPlaying
        )
        suppressUserCameraChangeUntil = Date().addingTimeInterval(programmaticCameraMoveGraceInterval)

        if force {
            debugReplayLog("camera sync index=\(clampedCurrentIndex) mode=\(cameraMode.label) force=true")
        }

        let nextCameraPosition = cameraPosition(
            centeredAt: cameraCoordinate,
            heading: cameraHeading
        )

        if isPlaying, cameraMode == .cinematic {
            // Repeated animated camera writes can stall MapKit during long replays.
            // Update the cinematic camera directly and let the interpolated target
            // coordinate provide the smooth movement.
            mapPosition = nextCameraPosition
        } else {
            withAnimation(isPlaying ? .linear(duration: 0.12) : RunTheme.smoothAnimation) {
                mapPosition = nextCameraPosition
            }
        }
    }

    private func syncCameraToVisualProgressIfNeeded() {
        guard isPlaying, !isScrubbing else {
            return
        }

        syncCameraToCurrentIndexIfNeeded()
    }

    private func cameraPosition(
        centeredAt coordinate: CLLocationCoordinate2D,
        heading: CLLocationDirection
    ) -> MapCameraPosition {
        switch cameraMode {
        case .standard:
            return .region(MKCoordinateRegion(center: coordinate, span: followSpan))
        case .cinematic:
            return .camera(
                MapCamera(
                    centerCoordinate: coordinate,
                    distance: cinematicCameraDistance,
                    heading: heading,
                    pitch: cinematicCameraPitch
                )
            )
        }
    }

    private func interpolatedCoordinate(at progress: Double) -> CLLocationCoordinate2D? {
        guard !coordinates.isEmpty else {
            return nil
        }

        guard coordinates.count > 1 else {
            return coordinates.first
        }

        let clampedProgress = min(max(progress, 0), Double(lastIndex))
        let lowerIndex = min(Int(floor(clampedProgress)), lastIndex)
        let upperIndex = min(lowerIndex + 1, lastIndex)
        let fraction = clampedProgress - Double(lowerIndex)

        guard coordinates.indices.contains(lowerIndex),
              coordinates.indices.contains(upperIndex) else {
            return currentCoordinate
        }

        let lowerCoordinate = coordinates[lowerIndex]
        let upperCoordinate = coordinates[upperIndex]

        return CLLocationCoordinate2D(
            latitude: lowerCoordinate.latitude + ((upperCoordinate.latitude - lowerCoordinate.latitude) * fraction),
            longitude: lowerCoordinate.longitude + ((upperCoordinate.longitude - lowerCoordinate.longitude) * fraction)
        )
    }

    private func currentPlaybackProgress(forceCurrentIndex: Bool = false) -> Double {
        if forceCurrentIndex {
            return Double(clampedCurrentIndex)
        }

        return clampedVisualProgress
    }

    private func bearing(at progress: Double) -> CLLocationDirection {
        guard coordinates.count > 1 else {
            return lastCameraHeading ?? 0
        }

        let normalizedProgress = min(max(progress, 0), Double(lastIndex))
        let lookBehindProgress = max(normalizedProgress - 0.8, 0)
        let lookAheadProgress = min(normalizedProgress + 1.2, Double(lastIndex))

        if let startCoordinate = interpolatedCoordinate(at: lookBehindProgress),
           let endCoordinate = interpolatedCoordinate(at: lookAheadProgress),
           !(startCoordinate.latitude == endCoordinate.latitude &&
             startCoordinate.longitude == endCoordinate.longitude) {
            return bearing(from: startCoordinate, to: endCoordinate)
        }

        if coordinates.indices.contains(clampedCurrentIndex + 1) {
            return bearing(
                from: coordinates[clampedCurrentIndex],
                to: coordinates[clampedCurrentIndex + 1]
            )
        }

        if coordinates.indices.contains(clampedCurrentIndex - 1) {
            return bearing(
                from: coordinates[clampedCurrentIndex - 1],
                to: coordinates[clampedCurrentIndex]
            )
        }

        return lastCameraHeading ?? 0
    }

    private func smoothedHeading(
        toward targetHeading: CLLocationDirection,
        reset: Bool = false
    ) -> CLLocationDirection {
        let normalizedTarget = normalizedHeading(targetHeading)

        guard !reset, let previousHeading = smoothedCameraHeading else {
            smoothedCameraHeading = normalizedTarget
            return normalizedTarget
        }

        let delta = signedAngularDelta(from: previousHeading, to: normalizedTarget)
        let nextHeading = normalizedHeading(previousHeading + (delta * headingSmoothingFactor))
        smoothedCameraHeading = nextHeading

        return nextHeading
    }

    private func bearing(
        from startCoordinate: CLLocationCoordinate2D,
        to endCoordinate: CLLocationCoordinate2D
    ) -> CLLocationDirection {
        let startLatitude = startCoordinate.latitude * .pi / 180
        let startLongitude = startCoordinate.longitude * .pi / 180
        let endLatitude = endCoordinate.latitude * .pi / 180
        let endLongitude = endCoordinate.longitude * .pi / 180
        let longitudeDelta = endLongitude - startLongitude
        let y = sin(longitudeDelta) * cos(endLatitude)
        let x = cos(startLatitude) * sin(endLatitude) -
            sin(startLatitude) * cos(endLatitude) * cos(longitudeDelta)
        let bearing = atan2(y, x) * 180 / .pi

        return bearing >= 0 ? bearing : bearing + 360
    }

    private func signedAngularDelta(
        from startHeading: CLLocationDirection,
        to endHeading: CLLocationDirection
    ) -> Double {
        let rawDelta = normalizedHeading(endHeading) - normalizedHeading(startHeading)

        if rawDelta > 180 {
            return rawDelta - 360
        }

        if rawDelta < -180 {
            return rawDelta + 360
        }

        return rawDelta
    }

    private func normalizedHeading(_ heading: CLLocationDirection) -> CLLocationDirection {
        let normalizedHeading = heading.truncatingRemainder(dividingBy: 360)
        return normalizedHeading >= 0 ? normalizedHeading : normalizedHeading + 360
    }

    private func debugReplayLog(_ message: String) {
        #if DEBUG
        print("[WorkoutReplayView] \(message)")
        #endif
    }
}

func makeReplayPreparedData(
    from route: RunRoute,
    maxReplayPointCount: Int
) -> ReplayPreparedData {
    let replayPoints = downsampleReplayPoints(
        from: route.points,
        maxReplayPointCount: maxReplayPointCount
    )
    let replayCoordinates = replayPoints.map(\.coordinate)
    let replayElapsedTimes = makeReplayElapsedTimes(from: replayPoints)
    let cumulativeDistances = makeCumulativeDistances(from: replayPoints)
    let replaySegments = makeReplaySegments(from: replayPoints)

    return ReplayPreparedData(
        replayPoints: replayPoints,
        replayCoordinates: replayCoordinates,
        replaySegments: replaySegments,
        cumulativeDistances: cumulativeDistances,
        replayElapsedTimes: replayElapsedTimes
    )
}

func downsampleReplayPoints(
    from points: [RunRoutePoint],
    maxReplayPointCount: Int
) -> [RunRoutePoint] {
    guard points.count > maxReplayPointCount else {
        return points
    }

    let stride = max(Int(ceil(Double(points.count) / Double(maxReplayPointCount))), 1)
    var sampledPoints = points.enumerated().compactMap { offset, point in
        offset.isMultiple(of: stride) ? point : nil
    }

    if sampledPoints.first?.id != points.first?.id, let first = points.first {
        sampledPoints.insert(first, at: 0)
    }

    if sampledPoints.last?.id != points.last?.id, let last = points.last {
        sampledPoints.append(last)
    }

    return sampledPoints
}

func makeReplayElapsedTimes(from points: [RunRoutePoint]) -> [TimeInterval] {
    guard let firstTimestamp = points.first?.timestamp else {
        return []
    }

    return points.map { point in
        max(point.timestamp.timeIntervalSince(firstTimestamp), 0)
    }
}

func makeCumulativeDistances(from points: [RunRoutePoint]) -> [Double] {
    guard !points.isEmpty else {
        return []
    }

    var distances = Array(repeating: 0.0, count: points.count)

    for index in points.indices.dropFirst() {
        let previousPoint = points[index - 1]
        let currentPoint = points[index]
        let previousLocation = CLLocation(latitude: previousPoint.latitude, longitude: previousPoint.longitude)
        let currentLocation = CLLocation(latitude: currentPoint.latitude, longitude: currentPoint.longitude)

        distances[index] = distances[index - 1] + previousLocation.distance(from: currentLocation)
    }

    return distances
}

func makeReplaySegments(from points: [RunRoutePoint]) -> [ReplayRouteSegment] {
    guard points.count > 1 else {
        return []
    }

    let segmentMetrics = points.indices.dropLast().map { index in
        let startPoint = points[index]
        let endPoint = points[index + 1]
        let startLocation = CLLocation(latitude: startPoint.latitude, longitude: startPoint.longitude)
        let endLocation = CLLocation(latitude: endPoint.latitude, longitude: endPoint.longitude)
        let distance = startLocation.distance(from: endLocation)
        let duration = endPoint.timestamp.timeIntervalSince(startPoint.timestamp)
        let pace = segmentPace(distanceMeters: distance, duration: duration)

        return ReplaySegmentMetric(
            id: index,
            startIndex: index,
            endIndex: index + 1,
            coordinates: [startPoint.coordinate, endPoint.coordinate],
            secondsPerKilometer: pace
        )
    }

    let validPaces = segmentMetrics
        .compactMap(\.secondsPerKilometer)
        .filter { $0 >= 120 && $0 <= 900 }
        .sorted()
    let fastThreshold = percentile(validPaces, 0.33)
    let slowThreshold = percentile(validPaces, 0.67)

    let coloredSegments = segmentMetrics.map { metric in
        ReplayRouteSegment(
            id: metric.id,
            startIndex: metric.startIndex,
            endIndex: metric.endIndex,
            coordinates: metric.coordinates,
            paceClass: segmentPaceClass(
                for: metric.secondsPerKilometer,
                fastThreshold: fastThreshold,
                slowThreshold: slowThreshold
            )
        )
    }

    return groupedSegments(from: coloredSegments)
}

func groupedSegments(from segments: [ReplayRouteSegment]) -> [ReplayRouteSegment] {
    segments.reduce(into: []) { groupedSegments, segment in
        guard let lastSegment = groupedSegments.last,
              lastSegment.paceClass == segment.paceClass,
              lastSegment.endIndex == segment.startIndex else {
            groupedSegments.append(segment)
            return
        }

        groupedSegments.removeLast()
        groupedSegments.append(
            ReplayRouteSegment(
                id: lastSegment.id,
                startIndex: lastSegment.startIndex,
                endIndex: segment.endIndex,
                coordinates: lastSegment.coordinates + [segment.coordinates.last].compactMap { $0 },
                paceClass: lastSegment.paceClass
            )
        )
    }
}

func segmentPace(distanceMeters: Double, duration: TimeInterval) -> Double? {
    guard distanceMeters > 0, duration > 0 else {
        return nil
    }

    let secondsPerKilometer = duration / (distanceMeters / 1_000)
    guard secondsPerKilometer.isFinite else {
        return nil
    }

    return secondsPerKilometer
}

func percentile(_ sortedValues: [Double], _ percentile: Double) -> Double? {
    guard !sortedValues.isEmpty else {
        return nil
    }

    let clampedPercentile = min(max(percentile, 0), 1)
    let index = Int((Double(sortedValues.count - 1) * clampedPercentile).rounded())
    return sortedValues[index]
}

func segmentPaceClass(
    for pace: Double?,
    fastThreshold: Double?,
    slowThreshold: Double?
) -> ReplaySegmentPaceClass {
    guard let pace,
          let fastThreshold,
          let slowThreshold,
          slowThreshold > fastThreshold else {
        return .normal
    }

    if pace <= fastThreshold {
        return .fast
    }

    if pace >= slowThreshold {
        return .slow
    }

    return .normal
}

enum ReplayRouteState: Equatable {
    case loading
    case loaded(Int)
    case empty
    case failed(String)

    var isLoaded: Bool {
        if case .loaded = self {
            return true
        }

        return false
    }
}

enum ReplayCameraMode: String, CaseIterable, Identifiable {
    case standard
    case cinematic

    var id: Self {
        self
    }

    var label: String {
        switch self {
        case .standard:
            return "Standard"
        case .cinematic:
            return "Cinematic"
        }
    }
}

struct ReplayPreparedData {
    let replayPoints: [RunRoutePoint]
    let replayCoordinates: [CLLocationCoordinate2D]
    let replaySegments: [ReplayRouteSegment]
    let cumulativeDistances: [Double]
    let replayElapsedTimes: [TimeInterval]
}

struct ReplaySegmentMetric {
    let id: Int
    let startIndex: Int
    let endIndex: Int
    let coordinates: [CLLocationCoordinate2D]
    let secondsPerKilometer: Double?
}

struct ReplayRouteSegment: Identifiable {
    let id: Int
    let startIndex: Int
    let endIndex: Int
    let coordinates: [CLLocationCoordinate2D]
    let paceClass: ReplaySegmentPaceClass
}

enum ReplaySegmentPaceClass: Equatable {
    case fast
    case normal
    case slow

    var color: Color {
        switch self {
        case .fast:
            return RunTheme.paceFast
        case .normal:
            return RunTheme.paceNormal
        case .slow:
            return RunTheme.paceSlow
        }
    }
}

enum PlaybackSpeed: String, CaseIterable, Identifiable {
    case ten
    case twenty
    case forty

    var id: Self {
        self
    }

    var label: String {
        switch self {
        case .ten:
            return "10x"
        case .twenty:
            return "20x"
        case .forty:
            return "40x"
        }
    }

    var factor: TimeInterval {
        switch self {
        case .ten:
            return 10
        case .twenty:
            return 20
        case .forty:
            return 40
        }
    }
}

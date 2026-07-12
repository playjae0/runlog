import MapKit
import SwiftUI

struct WorkoutReplayView: View {
    @AppStorage(MapTheme.storageKey) private var selectedMapThemeRawValue = MapTheme.system.rawValue
    let workout: RunWorkout

    @StateObject private var replayModel: ReplayViewModel
    @State private var isShowingFullscreenReplay = false

    private var selectedMapTheme: MapTheme {
        MapTheme(rawValue: selectedMapThemeRawValue) ?? .system
    }

    init(workout: RunWorkout) {
        self.workout = workout
        _replayModel = StateObject(wrappedValue: ReplayViewModel(workout: workout))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                routeStatus

                VStack(alignment: .leading, spacing: RunTheme.contentSpacing) {
                    HStack {
                        sectionHeader("경로")
                        Spacer()
                        Button {
                            isShowingFullscreenReplay = true
                        } label: {
                            Label("전체 화면 보기", systemImage: "arrow.up.left.and.arrow.down.right")
                                .font(RunTheme.caption)
                                .foregroundStyle(RunTheme.accent)
                        }
                        .buttonStyle(.plain)
                    }

                    MapProviderPicker(selection: mapProviderBinding)
                    replayMap
                    routeLegend
                }

                if replayModel.routeState.isLoaded {
                    VStack(alignment: .leading, spacing: RunTheme.contentSpacing) {
                        sectionHeader("현재 기록")
                        replayProgressSummary
                    }

                    VStack(alignment: .leading, spacing: RunTheme.contentSpacing) {
                        sectionHeader("리플레이 컨트롤")
                        replayControls
                    }
                }
            }
            .padding(RunTheme.pagePadding)
        }
        .background(RunTheme.screenBackground)
        .navigationTitle("Replay")
        .animation(RunTheme.smoothAnimation, value: replayModel.routeState)
        .animation(RunTheme.smoothAnimation, value: replayModel.isPlaying)
        .task(id: workout.id) {
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
        .fullScreenCover(isPresented: $isShowingFullscreenReplay) {
            FullscreenReplayView(
                workout: workout,
                initialMapProvider: replayModel.mapProvider,
                initialPlaybackSpeed: replayModel.playbackSpeed,
                initialCameraMode: .cinematic,
                initialIsCameraFollowing: replayModel.isCameraFollowing
            )
        }
    }

    @ViewBuilder
    private var routeStatus: some View {
        switch replayModel.routeState {
        case .loading:
            HStack(spacing: 10) {
                ProgressView()
                Text("리플레이 경로를 읽는 중입니다...")
                    .font(.subheadline)
                    .foregroundStyle(RunTheme.secondaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .runCard()

        case .loaded(let pointCount):
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(RunTheme.accent)
                Text("리플레이 좌표 \(pointCount)개")
                    .font(.subheadline)
                    .foregroundStyle(RunTheme.secondaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .runCard()

        case .empty:
            Label("이 workout에는 리플레이할 코스 좌표가 없습니다.", systemImage: "map")
                .font(.subheadline)
                .foregroundStyle(RunTheme.secondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .runCard()

        case .failed(let message):
            Label("리플레이 경로 읽기 실패: \(message)", systemImage: "exclamationmark.triangle")
                .font(.subheadline)
                .foregroundStyle(RunTheme.errorText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .runCard()
        }
    }

    @ViewBuilder
    private var replayMap: some View {
        Group {
            switch replayModel.mapProvider {
            case .apple:
                Map(position: mapPositionBinding, interactionModes: replayModel.standardMapInteractionModes) {
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
                            .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
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
                        cameraFitRoutes: [replayModel.coordinates]
                    )
                } else {
                    Text("Google Maps API 키를 설정하면 리플레이 경로를 비교할 수 있습니다.")
                        .font(.subheadline)
                        .foregroundStyle(RunTheme.secondaryText)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(RunTheme.subtleBackground)
                }
            }
        }
        .frame(height: 340)
        .clipShape(RoundedRectangle(cornerRadius: RunTheme.cardRadius))
        .overlay {
            RoundedRectangle(cornerRadius: RunTheme.cardRadius)
                .stroke(RunTheme.divider, lineWidth: 1)
        }
    }

    private var routeLegend: some View {
        HStack(spacing: 12) {
            legendItem(color: RunTheme.paceFast, title: "빠름")
            legendItem(color: RunTheme.paceNormal, title: "보통")
            legendItem(color: RunTheme.paceSlow, title: "느림")
            Spacer()
        }
        .font(.caption)
        .foregroundStyle(RunTheme.secondaryText)
    }

    private var replayProgressSummary: some View {
        HStack(spacing: 10) {
            progressMetric(
                title: "경과 시간",
                value: replayModel.elapsedTime.map(WorkoutFormatter.duration) ?? "시간 없음"
            )
            progressMetric(
                title: "누적 거리",
                value: replayModel.cumulativeDistanceMeters.map { WorkoutFormatter.distance($0) } ?? "거리 없음"
            )
            progressMetric(
                title: "현재 페이스",
                value: replayModel.currentPaceText
            )
        }
        .runCard()
    }

    private func progressMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(RunTheme.secondaryText)

            Text(value)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundStyle(RunTheme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var replayControls: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                Button {
                    replayModel.togglePlayback()
                } label: {
                    Label(replayModel.isPlaying ? "일시정지" : "재생", systemImage: replayModel.isPlaying ? "pause.fill" : "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!replayModel.canReplay)

                Button {
                    replayModel.resetPlayback()
                } label: {
                    Label("리셋", systemImage: "arrow.counterclockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(replayModel.coordinates.isEmpty)
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    controlTitle("타임라인")
                    Spacer()
                    Text("\(replayModel.clampedCurrentIndex + (replayModel.coordinates.isEmpty ? 0 : 1)) / \(replayModel.coordinates.count)")
                        .font(.caption)
                        .foregroundStyle(RunTheme.secondaryText)
                }

                Slider(
                    value: Binding(
                        get: { Double(replayModel.clampedCurrentIndex) },
                        set: { replayModel.setCurrentIndex(Int($0.rounded())) }
                    ),
                    in: 0...Double(max(replayModel.lastIndex, 1)),
                    step: 1,
                    onEditingChanged: replayModel.handleSliderEditingChanged
                )
                .disabled(!replayModel.canReplay)

                if replayModel.isScrubbing {
                    Text("탐색 중입니다. 손을 떼면 현재 지점에서 멈춥니다.")
                        .font(.caption)
                        .foregroundStyle(RunTheme.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                controlTitle("재생 속도")

                Picker("재생 속도", selection: playbackSpeedBinding) {
                    ForEach(PlaybackSpeed.allCases) { speed in
                        Text(speed.label).tag(speed)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(!replayModel.canReplay)
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                controlTitle("카메라 모드")

                Picker("카메라 모드", selection: cameraModeBinding) {
                    ForEach(ReplayCameraMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(!replayModel.canReplay || replayModel.isPlaying || replayModel.mapProvider == .google)
                .onChange(of: replayModel.cameraMode) { _, newMode in
                    replayModel.handleCameraModeChange(newMode)
                }

                if replayModel.mapProvider == .google {
                    Text("Google 지도 비교 모드에서는 Apple 지도 카메라 기능을 사용하지 않습니다.")
                        .font(.caption)
                        .foregroundStyle(RunTheme.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else if replayModel.isPlaying {
                    Text("일시정지 후 카메라 모드를 변경할 수 있습니다.")
                        .font(.caption)
                        .foregroundStyle(RunTheme.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            Divider()

            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    controlTitle("지도 따라가기")
                    Text(replayModel.cameraFollowStatusText)
                        .font(.caption)
                        .foregroundStyle(RunTheme.secondaryText)
                }

                Spacer()

                Toggle("지도 따라가기", isOn: isCameraFollowingBinding)
                    .labelsHidden()
                    .disabled(replayModel.coordinates.isEmpty || replayModel.cameraMode == .cinematic || replayModel.mapProvider == .google)
            }
        }
        .runCard()
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .fontWeight(.semibold)
            .foregroundStyle(RunTheme.primaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func controlTitle(_ title: String) -> some View {
        Text(title)
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundStyle(RunTheme.primaryText)
    }

    private func legendItem(color: Color, title: String) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(title)
        }
    }

    private var mapPositionBinding: Binding<MapCameraPosition> {
        Binding(
            get: { replayModel.mapPosition },
            set: { replayModel.mapPosition = $0 }
        )
    }

    private var mapProviderBinding: Binding<MapProvider> {
        Binding(
            get: { replayModel.mapProvider },
            set: { replayModel.mapProvider = $0 }
        )
    }

    private var playbackSpeedBinding: Binding<PlaybackSpeed> {
        Binding(
            get: { replayModel.playbackSpeed },
            set: { replayModel.playbackSpeed = $0 }
        )
    }

    private var cameraModeBinding: Binding<ReplayCameraMode> {
        Binding(
            get: { replayModel.cameraMode },
            set: { replayModel.cameraMode = $0 }
        )
    }

    private var isCameraFollowingBinding: Binding<Bool> {
        Binding(
            get: { replayModel.isCameraFollowing },
            set: {
                replayModel.isCameraFollowing = $0
                if $0 {
                    replayModel.setCurrentIndex(replayModel.clampedCurrentIndex)
                }
            }
        )
    }
}

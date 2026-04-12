# RunHealthPrototype

Minimal iPhone-only SwiftUI prototype for reading Apple Health running workouts.

## What It Does

- Requests HealthKit read permission for workouts and workout routes.
- Reads running workouts from Apple Health.
- Shows total runs, total distance, and this month's run count.
- Shows a recent running workout list.
- Opens a basic workout detail screen.
- Attempts to read `HKWorkoutRoute` data and displays the route on a map when available.

## Requirements

- Xcode
- iPhone running iOS 17 or later
- Apple Health running workout data
- HealthKit capability enabled in Signing & Capabilities

## Run

1. Open `RunHealthPrototype.xcodeproj` in Xcode.
2. Select the `RunHealthPrototype` scheme.
3. Set your Signing Team.
4. Connect an iPhone and select it as the run destination.
5. Press Run.

## In-App Check Flow

1. Tap `Health 권한 요청`.
2. Allow workout and route read permissions.
3. Tap `러닝 workout 조회`.
4. Tap a running workout row.
5. Tap `코스 지도 보기` to check route data.

Indoor runs or workouts without GPS data may not have route data.

//
//  ContentView.swift
//  Ellio
//
//  Created by Ethan Soh on 5/4/26.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var store = AppStore()
    @State private var flow: AppFlowStage = .alarm
    @State private var alarmTime = "06:30"
    @State private var completedPushUpReps = 0

    var body: some View {
        ZStack {
            EllioPalette.background
                .ignoresSafeArea()

            switch flow {
            case .alarm:
                AlarmView(alarmTime: alarmTime) {
                    flow = .pushUp
                }
                .transition(.opacity)

            case .pushUp:
                PushUpScreenView { reps in
                    completedPushUpReps = reps
                    flow = .analyzing
                }
                .transition(.opacity)

            case .analyzing:
                AnalysisView(
                    onSuccess: { flow = .wellDone },
                    onFailure: { flow = .tryAgain }
                )
                .transition(.opacity)

            case .tryAgain:
                TryAgainView {
                    flow = .alarm
                }
                .transition(.opacity)

            case .wellDone:
                WellDoneView {
                    flow = .alarmBriefing
                }
                .transition(.opacity)

            case .alarmBriefing:
                AlarmBriefingPagerView(onFinish: {
                    flow = .mainApp
                })
                .transition(.opacity)

            case .mainApp:
                MainAppView(
                    store: store
                )
                .transition(.opacity)
            }
        }
        .preferredColorScheme(store.theme.colorScheme)
        .animation(.easeInOut(duration: 0.3), value: flow)
    }
}

enum AppFlowStage {
    case alarm
    case pushUp
    case analyzing
    case tryAgain
    case wellDone
    case alarmBriefing
    case mainApp
}

enum EllioPalette {
    static let background = Color(red: 0.07, green: 0.08, blue: 0.09)
    static let surface = Color(red: 0.12, green: 0.13, blue: 0.15)
    static let surfaceRaised = Color(red: 0.16, green: 0.17, blue: 0.19)
    static let border = Color.white.opacity(0.08)
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.62)
    static let accent = Color(red: 0.96, green: 0.79, blue: 0.32)
    static let accentStrong = Color(red: 0.85, green: 0.64, blue: 0.16)
    static let success = Color(red: 0.52, green: 0.85, blue: 0.59)
    static let danger = Color(red: 0.96, green: 0.46, blue: 0.42)
}

struct AlarmView: View {
    let alarmTime: String
    var onStop: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.black,
                    Color(red: 0.10, green: 0.08, blue: 0.05)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 38) {
                    Text(alarmTime)
                        .font(.system(size: 98, weight: .thin, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)

                    Button("Snooze") {
                    }
                    .font(.system(size: 27, weight: .semibold, design: .rounded))
                    .foregroundStyle(.black.opacity(0.84))
                    .frame(width: 232, height: 80)
                    .background(
                        Capsule(style: .continuous)
                            .fill(EllioPalette.accent)
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(EllioPalette.accentStrong, lineWidth: 2)
                    )
                }

                Spacer()

                StopAlarmSlider(onComplete: onStop)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 34)
            }
        }
    }
}

struct StopAlarmSlider: View {
    var onComplete: () -> Void

    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false

    private let knobSize: CGFloat = 62
    private let controlHeight: CGFloat = 78

    var body: some View {
        GeometryReader { geometry in
            let maxOffset = max(geometry.size.width - knobSize - 16, 0)

            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.07))
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(Color.white.opacity(0.05), lineWidth: 1.5)
                    )

                HStack {
                    Spacer()

                    Text("Stop alarm")
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.92))
                        .opacity(isDragging ? 0 : 1)

                    Spacer()

                    Text(">>>")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.76))
                        .opacity(isDragging ? 0 : 1)
                        .padding(.trailing, 20)
                }
                .animation(.easeInOut(duration: 0.14), value: isDragging)

                Circle()
                    .fill(.white)
                    .frame(width: knobSize, height: knobSize)
                    .shadow(color: .white.opacity(0.16), radius: 4, y: 1)
                    .offset(x: dragOffset)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                isDragging = true
                                dragOffset = min(max(value.translation.width, 0), maxOffset)
                            }
                            .onEnded { _ in
                                if dragOffset >= maxOffset * 0.92 {
                                    isDragging = false
                                    dragOffset = maxOffset
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                                        onComplete()
                                    }
                                } else {
                                    withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                                        dragOffset = 0
                                        isDragging = false
                                    }
                                }
                            }
                    )
                    .padding(8)
            }
        }
        .frame(height: controlHeight)
    }
}

struct PushUpScreenView: View {
    var onComplete: (Int) -> Void

    @State private var repCount = 12
    @StateObject private var detector = PushUpDetector()

    var body: some View {
        ZStack {
            EllioPalette.background
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Push-up unlock")
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .foregroundStyle(EllioPalette.textPrimary)

                    Text("Place the phone sideways on the floor and let Ellio count your reps from the back camera.")
                        .font(.system(size: 17, weight: .medium, design: .rounded))
                        .foregroundStyle(EllioPalette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(spacing: 14) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(detector.repCount)")
                                .font(.system(size: 56, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)

                            Text("of \(repCount) reps")
                                .font(.system(size: 17, weight: .semibold, design: .rounded))
                                .foregroundStyle(EllioPalette.textSecondary)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 6) {
                            Text(detector.sessionState.rawValue)
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundStyle(detector.isReady ? EllioPalette.success : EllioPalette.accent)

                            Text("\(Int(detector.currentBodyLineScore * 100))% form")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundStyle(EllioPalette.textSecondary)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 18)

                    ZStack(alignment: .bottomLeading) {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(Color.black)

                        if detector.authorizationState == .denied {
                            permissionFallback
                        } else {
                            CameraPreviewView(session: detector.captureSession)
                                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

                            SkeletonOverlayView(points: detector.overlayPoints)
                                .padding(12)

                            LinearGradient(
                                colors: [Color.black.opacity(0), Color.black.opacity(0.78)],
                                startPoint: .center,
                                endPoint: .bottom
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

                            detector.flashState.color
                                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

                            VStack(alignment: .leading, spacing: 8) {
                                Text(detector.formFeedback)
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)

                                Text(detector.bodyVisible ? "Body detected" : "Waiting for full-body pose")
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.72))
                            }
                            .padding(18)
                        }
                    }
                    .frame(maxHeight: .infinity)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(EllioPalette.border, lineWidth: 1)
                    )

                    VStack(spacing: 12) {
                        StatRow(title: "Target", value: "\(repCount) reps")
                        StatRow(title: "Detection", value: "Vision body pose")
                        StatRow(title: "Camera", value: "Back wide-angle")
                        StatRow(title: "Left elbow", value: "\(Int(detector.leftElbowAngle))°")
                        StatRow(title: "Right elbow", value: "\(Int(detector.rightElbowAngle))°")
                        StatRow(title: "Shoulder drop", value: String(format: "%.2f", detector.shoulderDrop))

                        Stepper("Required reps: \(repCount)", value: $repCount, in: 6...25)
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundStyle(EllioPalette.textSecondary)
                    }
                    .padding(20)
                    .background(panelBackground)

                    Button {
                        onComplete(detector.repCount)
                    } label: {
                        Text("Verify and continue")
                            .font(.system(size: 19, weight: .bold, design: .rounded))
                            .frame(maxWidth: .infinity)
                            .frame(height: 58)
                    }
                    .buttonStyle(EllioPrimaryButtonStyle())
                    .disabled(detector.repCount < repCount)
                    .opacity(detector.repCount >= repCount ? 1 : 0.5)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 24)
        }
        .onAppear {
            detector.setTargetReps(repCount)
            detector.requestAccessAndStart()
        }
        .onDisappear {
            detector.stopSession()
        }
        .onChange(of: repCount) { _, newValue in
            detector.setTargetReps(newValue)
        }
        .onChange(of: detector.repCount) { _, newValue in
            if newValue >= repCount {
                onComplete(newValue)
            }
        }
    }

    private var panelBackground: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(EllioPalette.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(EllioPalette.border, lineWidth: 1)
            )
    }

    private var permissionFallback: some View {
        VStack(spacing: 12) {
            Image(systemName: "camera.fill")
                .font(.system(size: 42))
                .foregroundStyle(EllioPalette.accent)

            Text("Camera access needed")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text("Enable camera permission in Settings so Ellio can verify your push-ups.")
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(EllioPalette.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct AnalysisView: View {
    var onSuccess: () -> Void
    var onFailure: () -> Void

    @State private var progress: CGFloat = 0
    @State private var completed = false

    var body: some View {
        ZStack {
            EllioPalette.background
                .ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                Circle()
                    .fill(EllioPalette.surface)
                    .frame(width: 120, height: 120)
                    .overlay(
                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(
                                EllioPalette.accent,
                                style: StrokeStyle(lineWidth: 10, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .padding(12)
                    )
                    .overlay(
                        Image(systemName: "waveform.path.ecg")
                            .font(.system(size: 34, weight: .medium))
                            .foregroundStyle(.white)
                    )

                VStack(spacing: 10) {
                    Text("Analyzing movement")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text("Checking your reps and clearing the wake-up lock.")
                        .font(.system(size: 17, weight: .medium, design: .rounded))
                        .foregroundStyle(EllioPalette.textSecondary)
                }

                Spacer()

                Button("Simulate retry instead") {
                    guard !completed else { return }
                    completed = true
                    onFailure()
                }
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(EllioPalette.textSecondary)
                .padding(.bottom, 34)
            }
            .padding(.horizontal, 24)
        }
        .task {
            guard !completed else { return }

            withAnimation(.easeInOut(duration: 2.2)) {
                progress = 1
            }

            try? await Task.sleep(for: .seconds(2.25))
            guard !completed else { return }

            completed = true
            onSuccess()
        }
    }
}

struct WellDoneView: View {
    var onContinue: () -> Void

    var body: some View {
        ZStack {
            EllioPalette.background
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                Circle()
                    .fill(EllioPalette.success.opacity(0.18))
                    .frame(width: 116, height: 116)
                    .overlay(
                        Image(systemName: "checkmark")
                            .font(.system(size: 40, weight: .bold))
                            .foregroundStyle(EllioPalette.success)
                    )

                VStack(spacing: 10) {
                    Text("Well done")
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text("Alarm stopped. Let’s set up the rest of your morning while you’re already moving.")
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                        .foregroundStyle(EllioPalette.textSecondary)
                        .multilineTextAlignment(.center)
                }

                Spacer()

                Button("Next") {
                    onContinue()
                }
                .buttonStyle(EllioPrimaryButtonStyle())
                .padding(.bottom, 34)
            }
            .padding(.horizontal, 24)
        }
    }
}

struct TryAgainView: View {
    var onRetry: () -> Void

    var body: some View {
        ZStack {
            EllioPalette.background
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                Circle()
                    .fill(EllioPalette.danger.opacity(0.18))
                    .frame(width: 116, height: 116)
                    .overlay(
                        Image(systemName: "xmark")
                            .font(.system(size: 40, weight: .bold))
                            .foregroundStyle(EllioPalette.danger)
                    )

                VStack(spacing: 10) {
                    Text("Oops! Try again.")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text("We couldn’t verify enough motion. The alarm will ring again after 10 seconds.")
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                        .foregroundStyle(EllioPalette.textSecondary)
                        .multilineTextAlignment(.center)
                }

                Spacer()

                Button("Try again") {
                    onRetry()
                }
                .buttonStyle(EllioPrimaryButtonStyle())
                .padding(.bottom, 34)
            }
            .padding(.horizontal, 24)
        }
    }
}

struct AlarmBriefingPagerView: View {
    var onFinish: () -> Void

    @State private var page = 0

    private let pages: [IntroPage] = [
        IntroPage(
            title: "Morning",
            body: "Right after the alarm clears, Ellio shows the first few decisions of your morning.",
            items: ["06:45 shower", "07:10 breakfast", "07:40 leave home"]
        ),
        IntroPage(
            title: "Schedule",
            body: "The day ahead, surfaced while you’re already awake and moving.",
            items: ["09:00 studio critique", "13:30 project sync", "18:00 gym"]
        ),
        IntroPage(
            title: "Queue",
            body: "Loose tasks that still matter, parked here so they don’t bounce around in your head.",
            items: ["Reply to Theo", "Pick up detergent", "Review slides"]
        ),
        IntroPage(
            title: "Enjoy your day",
            body: "You’re up, your alarm is handled, and the rest of your day has shape.",
            items: ["Alarm handled", "Plan checked", "Bag ready"]
        )
    ]

    var body: some View {
        ZStack {
            EllioPalette.background
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Spacer()

                TabView(selection: $page) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                        IntroCard(page: page)
                            .padding(.horizontal, 24)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .frame(height: 420)

                Spacer()

                Button(page == pages.count - 1 ? "Open Ellio" : "Next") {
                    if page == pages.count - 1 {
                        onFinish()
                    } else {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            page += 1
                        }
                    }
                }
                .buttonStyle(EllioPrimaryButtonStyle())
                .padding(.horizontal, 24)
                .padding(.bottom, 34)
            }
        }
    }
}

struct IntroCard: View {
    let page: IntroPage

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(page.title)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text(page.body)
                .font(.system(size: 17, weight: .medium, design: .rounded))
                .foregroundStyle(EllioPalette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 12) {
                ForEach(page.items, id: \.self) { item in
                    HStack(spacing: 14) {
                        Circle()
                            .fill(EllioPalette.accent)
                            .frame(width: 8, height: 8)

                        Text(item)
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)

                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
            }

            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(EllioPalette.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(EllioPalette.border, lineWidth: 1)
                )
        )
    }
}

struct MainAppView: View {
    @ObservedObject var store: AppStore

    var body: some View {
        TabView {
            NavigationStack {
                HomeDashboardView(
                    morningTasks: $store.morningTasks,
                    packItems: $store.packItems,
                    upcomingAlarms: store.upcomingAlarms,
                    store: store
                )
            }
            .tabItem {
                Label("Home", systemImage: "house")
            }

            NavigationStack {
                AlarmListView(upcomingAlarms: $store.upcomingAlarms)
            }
            .tabItem {
                Label("Alarms", systemImage: "alarm")
            }

            NavigationStack {
                PlannerHubView(store: store)
            }
            .tabItem {
                Label("Plan", systemImage: "square.grid.2x2")
            }
        }
        .tint(EllioPalette.accent)
    }
}

struct HomeDashboardView: View {
    @Binding var morningTasks: [MorningTask]
    @Binding var packItems: [PackItem]
    let upcomingAlarms: [AlarmItem]
    @ObservedObject var store: AppStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Today")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.top, 10)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Hey there!")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text("2 of 3 morning essentials are already lined up. Keep the next hour simple.")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundStyle(EllioPalette.textSecondary)

                    ProgressView(value: 2, total: 3)
                        .tint(EllioPalette.accent)
                }
                .padding(22)
                .background(cardBackground)

                NavigationLink {
                    ScheduleView(tasks: $morningTasks)
                } label: {
                    OverviewCard(
                        title: "Next up",
                        subtitle: "07:10 Breakfast and vitamins",
                        accessory: "Schedule"
                    )
                }
                .buttonStyle(.plain)

                NavigationLink {
                    PackListView(items: $packItems)
                } label: {
                    OverviewCard(
                        title: "Bag status",
                        subtitle: "\(packItems.filter(\.isPacked).count) / \(packItems.count) items packed",
                        accessory: "Pack"
                    )
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 14) {
                    Text("Upcoming alarms")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    ForEach(upcomingAlarms.prefix(2)) { alarm in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(alarm.time)
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)

                                Text(alarm.label)
                                    .font(.system(size: 15, weight: .medium, design: .rounded))
                                    .foregroundStyle(EllioPalette.textSecondary)
                            }

                            Spacer()

                            Text(alarm.isEnabled ? "On" : "Off")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(alarm.isEnabled ? EllioPalette.accent : EllioPalette.textSecondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding(22)
                .background(cardBackground)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 28)
        }
        .background(EllioPalette.background.ignoresSafeArea())
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    SettingsEditorView(store: store)
                } label: {
                    Image(systemName: "gearshape")
                        .foregroundStyle(.white.opacity(0.88))
                }
            }
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(EllioPalette.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(EllioPalette.border, lineWidth: 1)
            )
    }
}

struct PlannerHubView: View {
    @ObservedObject var store: AppStore

    var body: some View {
        List {
            Section {
                NavigationLink("Alarms") {
                    AlarmListView(upcomingAlarms: $store.upcomingAlarms)
                }

                NavigationLink("Schedule") {
                    ScheduleView(tasks: $store.morningTasks)
                }

                NavigationLink("Pack") {
                    PackListView(items: $store.packItems)
                }

                NavigationLink("Queue") {
                    QueueView(items: $store.queueItems)
                }

                NavigationLink("Settings") {
                    SettingsEditorView(store: store)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(EllioPalette.background.ignoresSafeArea())
        .navigationTitle("Plan")
    }
}

struct AlarmListView: View {
    @Binding var upcomingAlarms: [AlarmItem]
    @State private var showingAddAlarm = false

    var body: some View {
        List {
            ForEach($upcomingAlarms) { $alarm in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(alarm.time)
                            .font(.system(size: 32, weight: .bold, design: .rounded))

                        Text(alarm.label)
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundStyle(EllioPalette.textSecondary)
                    }

                    Spacer()

                    Toggle("", isOn: $alarm.isEnabled)
                        .labelsHidden()
                        .tint(EllioPalette.accent)
                }
                .listRowBackground(EllioPalette.surface)
            }
        }
        .scrollContentBackground(.hidden)
        .background(EllioPalette.background.ignoresSafeArea())
        .navigationTitle("Alarms")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingAddAlarm = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddAlarm) {
            AlarmEditorSheet { time, label in
                upcomingAlarms.append(
                    AlarmItem(
                        id: UUID().uuidString,
                        time: time,
                        label: label,
                        isEnabled: true
                    )
                )
            }
        }
    }
}

struct ScheduleView: View {
    @Binding var tasks: [MorningTask]
    @State private var showingAddTask = false

    var body: some View {
        List {
            ForEach($tasks) { $task in
                HStack(alignment: .top, spacing: 14) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(task.time)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(EllioPalette.accent)

                        Text(task.title)
                            .font(.system(size: 19, weight: .bold, design: .rounded))

                        Text(task.note)
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(EllioPalette.textSecondary)
                    }

                    Spacer()

                    Toggle("", isOn: $task.isDone)
                        .labelsHidden()
                        .tint(EllioPalette.success)
                }
                .listRowBackground(EllioPalette.surface)
            }
        }
        .scrollContentBackground(.hidden)
        .background(EllioPalette.background.ignoresSafeArea())
        .navigationTitle("Schedule")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingAddTask = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddTask) {
            TaskEditorSheet { time, title, note in
                tasks.append(
                    MorningTask(
                        id: UUID().uuidString,
                        time: time,
                        title: title,
                        note: note,
                        isDone: false
                    )
                )
            }
        }
    }
}

struct PackListView: View {
    @Binding var items: [PackItem]
    @State private var showingAddItem = false

    var body: some View {
        List {
            ForEach($items) { $item in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.name)
                            .font(.system(size: 18, weight: .semibold, design: .rounded))

                        Text(item.category)
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(EllioPalette.textSecondary)
                    }

                    Spacer()

                    Toggle("", isOn: $item.isPacked)
                        .labelsHidden()
                        .tint(EllioPalette.accent)
                }
                .listRowBackground(EllioPalette.surface)
            }
        }
        .scrollContentBackground(.hidden)
        .background(EllioPalette.background.ignoresSafeArea())
        .navigationTitle("Pack")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingAddItem = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddItem) {
            PackItemEditorSheet { name, category in
                items.append(
                    PackItem(
                        id: UUID().uuidString,
                        name: name,
                        category: category,
                        isPacked: false
                    )
                )
            }
        }
    }
}

struct QueueView: View {
    @Binding var items: [String]
    @State private var showingAddItem = false

    var body: some View {
        List(items, id: \.self) { item in
            Text(item)
                .font(.system(size: 17, weight: .medium, design: .rounded))
                .listRowBackground(EllioPalette.surface)
        }
        .scrollContentBackground(.hidden)
        .background(EllioPalette.background.ignoresSafeArea())
        .navigationTitle("Queue")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingAddItem = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddItem) {
            QueueItemEditorSheet { item in
                items.append(item)
            }
        }
    }
}

struct SettingsView: View {
    let selectedTheme: AppTheme

    var body: some View {
        List {
            Section("Appearance") {
                HStack {
                    Text("Theme")
                    Spacer()
                    Text(selectedTheme.title)
                        .foregroundStyle(EllioPalette.textSecondary)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(EllioPalette.background.ignoresSafeArea())
        .navigationTitle("Settings")
    }
}

struct SettingsEditorView: View {
    @ObservedObject var store: AppStore

    var body: some View {
        List {
            Section("Appearance") {
                Picker("Theme", selection: $store.theme) {
                    ForEach(AppTheme.allCases, id: \.self) { theme in
                        Text(theme.title).tag(theme)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
        .scrollContentBackground(.hidden)
        .background(EllioPalette.background.ignoresSafeArea())
        .navigationTitle("Settings")
    }
}

struct AlarmEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var time = "07:00"
    @State private var label = ""

    var onSave: (String, String) -> Void

    var body: some View {
        NavigationStack {
            Form {
                TextField("Time (HH:mm)", text: $time)
                TextField("Label", text: $label)
            }
            .navigationTitle("New Alarm")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        onSave(time, label.isEmpty ? "Ellio alarm" : label)
                        dismiss()
                    }
                }
            }
        }
    }
}

struct TaskEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var time = "08:00"
    @State private var title = ""
    @State private var note = ""

    var onSave: (String, String, String) -> Void

    var body: some View {
        NavigationStack {
            Form {
                TextField("Time (HH:mm)", text: $time)
                TextField("Title", text: $title)
                TextField("Note", text: $note)
            }
            .navigationTitle("New Task")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        onSave(time, title.isEmpty ? "New task" : title, note)
                        dismiss()
                    }
                }
            }
        }
    }
}

struct PackItemEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var category = ""

    var onSave: (String, String) -> Void

    var body: some View {
        NavigationStack {
            Form {
                TextField("Item", text: $name)
                TextField("Category", text: $category)
            }
            .navigationTitle("New Pack Item")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        onSave(name.isEmpty ? "New item" : name, category.isEmpty ? "General" : category)
                        dismiss()
                    }
                }
            }
        }
    }
}

struct QueueItemEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var item = ""

    var onSave: (String) -> Void

    var body: some View {
        NavigationStack {
            Form {
                TextField("Queue item", text: $item)
            }
            .navigationTitle("New Queue Item")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        onSave(item.isEmpty ? "New queue item" : item)
                        dismiss()
                    }
                }
            }
        }
    }
}

struct OverviewCard: View {
    let title: String
    let subtitle: String
    let accessory: String

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(EllioPalette.textSecondary)

                Text(subtitle)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)
            }

            Spacer()

            Text(accessory)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(EllioPalette.accent)
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(EllioPalette.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(EllioPalette.border, lineWidth: 1)
                )
        )
    }
}

struct StatRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(EllioPalette.textSecondary)

            Spacer()

            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
    }
}

struct EllioPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.black.opacity(0.84))
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(EllioPalette.accent)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(EllioPalette.accentStrong, lineWidth: 1.5)
            )
            .opacity(configuration.isPressed ? 0.92 : 1)
    }
}

struct IntroPage {
    let title: String
    let body: String
    let items: [String]
}

struct MorningTask: Identifiable, Codable {
    let id: String
    let time: String
    let title: String
    let note: String
    var isDone: Bool

    static let sample: [MorningTask] = [
        MorningTask(id: "shower", time: "06:45", title: "Shower", note: "Quick reset before breakfast", isDone: true),
        MorningTask(id: "breakfast", time: "07:10", title: "Breakfast", note: "Eggs, toast, vitamins", isDone: false),
        MorningTask(id: "leave", time: "07:40", title: "Leave home", note: "Train buffer included", isDone: false)
    ]
}

struct PackItem: Identifiable, Codable {
    let id: String
    let name: String
    let category: String
    var isPacked: Bool

    static let sample: [PackItem] = [
        PackItem(id: "macbook", name: "MacBook", category: "Work", isPacked: true),
        PackItem(id: "sketchbook", name: "Sketchbook", category: "Studio", isPacked: false),
        PackItem(id: "water", name: "Water bottle", category: "Daily", isPacked: true),
        PackItem(id: "gymshirt", name: "Gym shirt", category: "Evening", isPacked: false)
    ]
}

struct AlarmItem: Identifiable, Codable {
    let id: String
    let time: String
    let label: String
    var isEnabled: Bool

    static let sample: [AlarmItem] = [
        AlarmItem(id: "wake", time: "06:30", label: "Wake-up challenge", isEnabled: true),
        AlarmItem(id: "backup", time: "08:00", label: "Backup reminder", isEnabled: false),
        AlarmItem(id: "sleep", time: "22:45", label: "Sleep wind-down", isEnabled: true)
    ]
}

#Preview {
    ContentView()
}

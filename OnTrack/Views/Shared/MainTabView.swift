import SwiftUI
import Supabase

struct MainTabView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: ThemeManager
    @State private var selectedTab = 0
    @State private var showCheckIn = false
    @State private var checkInVM = DailyCheckInViewModel()
    @State private var showNotificationDeniedAlert = false
    @State private var showProfile = false
    @State private var showWhatsNew = false
    @State private var showActivitySummary = false
    @State private var activityVM = ActivitySummaryViewModel()
    @State private var progressVM = ProgressViewModel()
    @State private var showQuickAdd = false
    @State private var showAddHabit = false
    @State private var showAddSupplement = false
    @State private var showSessionTypePicker = false
    @State private var showGroupPicker = false
    @State private var showCreateGroupSession = false
    @State private var showCreateSingleSession = false
    @State private var quickAddGroupVM = GroupViewModel()
    @State private var quickAddSessionVM = SessionViewModel()
    @State private var selectedQuickAddGroup: AppGroup? = nil
    @StateObject private var quickAddHabitVM = HabitViewModel()
    @State private var quickAddSupplementVM = SupplementViewModel()
    @State private var previousTab = 0
    @State private var showFoundationCard = false

    var body: some View {
        ZStack {
            // Global background — sits behind every tab's content
            GeometryReader { geo in
                Image(themeManager.currentBackgroundImage)
                    .resizable()
                    .scaledToFill()
                    .grayscale(1.0)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                    .ignoresSafeArea()

                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.black.opacity(0.55),
                        Color.black.opacity(0.25),
                        Color.clear
                    ]),
                    startPoint: .top,
                    endPoint: .center
                )
                .ignoresSafeArea()
            }

            TabView(selection: $selectedTab) {
                DailyActionsView()
                    .tabItem {
                        Label("Home", systemImage: "house.fill")
                    }
                    .tag(0)

                SocialView()
                    .tabItem {
                        Label("Social", systemImage: "person.2.fill")
                    }
                    .tag(1)

                // Dummy tab — intercepted by FAB
                Color.clear
                    .tabItem {
                        Label("", systemImage: "")
                    }
                    .tag(2)

                MentalHealthView()
                    .tabItem {
                        Label("Wellbeing", systemImage: "heart.fill")
                    }
                    .tag(3)

                SupplementsView()
                    .tabItem {
                        Label("Supps", systemImage: "pills.fill")
                    }
                    .tag(4)
            }
            .tint(themeManager.currentTheme.primary)
            .onChange(of: selectedTab) { _, newValue in
                if newValue == 2 {
                    selectedTab = previousTab
                    showQuickAdd = true
                } else {
                    previousTab = newValue
                }
            }
            // FAB button overlay
            VStack {
                Spacer()
                Button {
                    showQuickAdd = true
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color(red: 0.5, green: 0.3, blue: 0.9))
                            .frame(width: 56, height: 56)
                            .shadow(color: Color(red: 0.5, green: 0.3, blue: 0.9).opacity(0.5), radius: 10, y: 4)
                        Image(systemName: "plus")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
                .offset(y: -28)
            }
            .ignoresSafeArea(.keyboard)
            .confirmationDialog("Quick Add", isPresented: $showQuickAdd, titleVisibility: .visible) {
                Button("Add Session") {
                    showSessionTypePicker = true
                }
                Button("Add Supplement") {
                    showAddSupplement = true
                }
                Button("Log Habit") {
                    showAddHabit = true
                }
                Button("Add Friend") {
                    selectedTab = 1 // Social → Friends
                }
                Button("Cancel", role: .cancel) {}
            }
            .confirmationDialog("Session Type", isPresented: $showSessionTypePicker, titleVisibility: .visible) {
                Button("Personal Session") {
                    quickAddSessionVM.resetForm()
                    showCreateSingleSession = true
                }
                Button("Group Session") {
                    Task { await quickAddGroupVM.fetchGroups() }
                    showGroupPicker = true
                }
                Button("Recurring Personal Session") {
                    quickAddSessionVM.resetForm()
                    showCreateSingleSession = true
                }
                Button("Cancel", role: .cancel) {}
            }
            .sheet(isPresented: $showAddHabit) {
                AddHabitView(viewModel: quickAddHabitVM)
            }
            .sheet(isPresented: $showAddSupplement) {
                AddSupplementView(viewModel: quickAddSupplementVM)
            }
            .sheet(isPresented: $showCheckIn) {
                DailyCheckInView(vm: checkInVM)
            }
            .sheet(isPresented: $showProfile) {
                ProfileView()
            }
            .sheet(isPresented: $showWhatsNew) {
                WhatsNewView()
            }
            .sheet(isPresented: $showActivitySummary) {
                ActivitySummaryView(items: activityVM.items)
            }
            .fullScreenCover(isPresented: $showFoundationCard) {
                FoundationMemberCardView {
                    UserDefaults.standard.set(true, forKey: "foundation_welcome_seen")
                    showFoundationCard = false
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showProfile = true
                    } label: {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 26))
                    }
                }
            }
        }
        .environment(progressVM)
        .onAppear {
            NotificationManager.shared.requestPermission()
            if appState.currentUser?.isFoundationMember == true,
               !UserDefaults.standard.bool(forKey: "foundation_welcome_seen") {
                showFoundationCard = true
            }
        }
        // Try immediately if currentUser is already loaded
        .task {
            if HealthKitManager.shared.isAuthorized {
                await HealthKitManager.shared.fetchAll()
            }

            await checkNotificationStatus()

            if VersionChangeManager.shared.isFreshUpdate {
                showWhatsNew = true
            }

            guard appState.currentUser != nil else { return }
            await checkAndShowDailyCheckIn()
            await checkAndShowActivitySummary()
        }
        // Handle case where currentUser loads asynchronously after view appears
        .onChange(of: appState.currentUser?.id) { oldId, newId in
            guard oldId == nil, newId != nil else { return }
            Task { await checkAndShowDailyCheckIn() }
            // Foundation member card — also check here for async profile load
            if appState.currentUser?.isFoundationMember == true,
               !UserDefaults.standard.bool(forKey: "foundation_welcome_seen") {
                showFoundationCard = true
            }
        }
        .alert("Notifications Disabled", isPresented: $showNotificationDeniedAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Not Now", role: .cancel) {}
        } message: {
            Text("Enable notifications in Settings to receive session reminders and your daily check-in prompt.")
        }
        .sheet(isPresented: $showGroupPicker) {
            NavigationStack {
                List(quickAddGroupVM.groups) { group in
                    Button(group.name) {
                        quickAddSessionVM.resetForm()
                        selectedQuickAddGroup = group
                        showGroupPicker = false
                        showCreateGroupSession = true
                    }
                    .foregroundStyle(.white)
                    .listRowBackground(Color(red: 0.08, green: 0.12, blue: 0.15).opacity(0.92))
                }
                .navigationTitle("Choose Group")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Cancel") { showGroupPicker = false }
                    }
                }
                .background(themeManager.backgroundColour())
                .scrollContentBackground(.hidden)
            }
            .environmentObject(appState)
            .environmentObject(themeManager)
        }
        .sheet(isPresented: $showCreateGroupSession) {
            if let group = selectedQuickAddGroup {
                CreateSessionView(viewModel: quickAddSessionVM, group: group)
                    .environmentObject(appState)
                    .environmentObject(themeManager)
            }
        }
        .sheet(isPresented: $showCreateSingleSession) {
            CreateSingleSessionView(viewModel: quickAddSessionVM)
                .environmentObject(appState)
                .environmentObject(themeManager)
        }
    }

    private func checkNotificationStatus() async {
        let status = await NotificationManager.shared.authorizationStatus()
        if status == .denied {
            showNotificationDeniedAlert = true
        }
    }

    private func checkAndShowActivitySummary() async {
        guard let userId = appState.currentUser?.id else { return }
        let lastOpen = UserDefaults.standard.object(forKey: "last_app_open_date") as? Date
        UserDefaults.standard.set(Date(), forKey: "last_app_open_date")
        guard let lastOpen else { return }
        await activityVM.fetchSince(lastOpen: lastOpen, userId: userId)
        if !activityVM.items.isEmpty {
            showActivitySummary = true
        }
    }

    private func checkAndShowDailyCheckIn() async {
        guard let userId = appState.currentUser?.id else { return }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let today = formatter.string(from: Date())

        struct CheckInRecord: Decodable { let id: UUID }

        do {
            let records: [CheckInRecord] = try await supabase
                .from("daily_checkins")
                .select("id")
                .eq("user_id", value: userId.uuidString)
                .eq("checkin_date", value: today)
                .limit(1)
                .execute()
                .value
            if records.isEmpty {
                checkInVM.reset()
                checkInVM.prefillFromHealthKit()
                showCheckIn = true
            }
        } catch {
            print("[MainTabView] daily check-in lookup failed: \(error)")
        }
    }
}

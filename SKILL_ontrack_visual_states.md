# OnTrack UI Skill: State-Aware Cards & Bordered Completion UI

Use this skill whenever you need to add visual state feedback to a card, button, or row in OnTrack Focus — coloured borders, icon circles, and status text that reflect completion or lifecycle state.

---

## Pattern 1 — Completion Border on a Button/Card (Habit style)

Used when something is either **done** or **not done** today.

### Structure
```swift
Button { onTap() } label: {
    HStack { ... }
    .padding(16)
    .background(cardBg)
    .clipShape(RoundedRectangle(cornerRadius: 14))
    .overlay(
        RoundedRectangle(cornerRadius: 14)
            .strokeBorder(
                isCompleted ? Color.green.opacity(0.4) : themeManager.currentTheme.primary.opacity(0.6),
                lineWidth: isCompleted ? 1 : 2
            )
    )
}
.buttonStyle(.plain)
```

### Rules
- **Completed:** `Color.green.opacity(0.4)`, lineWidth `1`
- **Incomplete:** `themeManager.currentTheme.primary.opacity(0.6)`, lineWidth `2`
- Card background always: `Color(red: 0.08, green: 0.12, blue: 0.15).opacity(0.92)`
- Corner radius: `16` for full-width cards, `14` for row cards
- Never use white card backgrounds — keep the dark system

### Icon Circle
```swift
ZStack {
    Circle()
        .fill(isCompleted ? Color.green.opacity(0.15) : themeManager.currentTheme.primary.opacity(0.2))
        .frame(width: 52, height: 52)
    Image(systemName: isCompleted ? "checkmark.circle.fill" : "your.default.icon")
        .font(.title2)
        .foregroundStyle(isCompleted ? .green : themeManager.currentTheme.primary)
}
```

### Subtitle Text
```swift
Text(isCompleted ? "Completed today ✓" : "Tap to log")
    .font(.system(size: 14))
    .foregroundStyle(isCompleted ? .green : .white.opacity(0.7))
```

---

## Pattern 2 — Multi-State Lifecycle Card (Session style)

Used when something has **more than 2 states** — e.g. RSVP + attendance lifecycle.

### State enum approach
Define states and derive visual properties from them:

```swift
enum LifecycleState {
    case noRSVP, going, maybe, notGoing, attended, missed, noRecord
}

var lifecycleState: LifecycleState {
    if isPast {
        if attended == true  { return .attended }
        if attended == false { return .missed }
        return .noRecord
    } else {
        switch rsvpStatus {
        case "going":     return .going
        case "maybe":     return .maybe
        case "not_going": return .notGoing
        default:          return .noRSVP
        }
    }
}
```

### Visual mapping
| State | Icon | Icon Color | Subtitle | Border Color | Line Width |
|---|---|---|---|---|---|
| noRSVP | `bell.badge` | `.red` | "RSVP required" | `.red.opacity(0.5)` | 2 |
| going | `checkmark.circle.fill` | teal | "You're in ✓" | `teal.opacity(0.4)` | 1 |
| maybe | `questionmark.circle.fill` | `.orange` | "Maybe" | `.orange.opacity(0.4)` | 1 |
| notGoing | `xmark.circle.fill` | `.gray` | "Not attending" | `.gray.opacity(0.3)` | 1 |
| attended | `checkmark.circle.fill` | `.green` | "Attended ✓" | `.green.opacity(0.4)` | 1 |
| missed | `xmark.circle.fill` | `.red` | "Missed" | `.red.opacity(0.4)` | 1 |
| noRecord | `clock.badge.questionmark` | `.gray` | "No record" | `.gray.opacity(0.3)` | 1 |

teal = `Color(red: 0.08, green: 0.35, blue: 0.45)`

### Card structure
```swift
Button(action: onTap) {
    HStack(spacing: 16) {
        // Icon circle
        ZStack {
            Circle().fill(iconColor.opacity(0.15)).frame(width: 52, height: 52)
            Image(systemName: icon).font(.title2).foregroundStyle(iconColor)
        }
        // Text
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
            Text(subtitle)
                .font(.system(size: 14))
                .foregroundStyle(subtitleColor)
        }
        Spacer()
        Image(systemName: "chevron.right")
            .font(.subheadline)
            .foregroundStyle(.white.opacity(0.4))
    }
    .padding(20)
    .background(Color(red: 0.08, green: 0.12, blue: 0.15).opacity(0.92))
    .clipShape(RoundedRectangle(cornerRadius: 16))
    .overlay(
        RoundedRectangle(cornerRadius: 16)
            .strokeBorder(borderColor, lineWidth: lineWidth)
    )
}
.buttonStyle(.plain)
```

### Subtitle color rules
- `.attended` → `.green`
- `.noRSVP` → `.red.opacity(0.9)`
- `.missed` → `.red.opacity(0.7)`
- all others → `.white.opacity(0.7)`

---

## Async loader pattern

When state must be fetched from Supabase before rendering the card:

```swift
struct MyLifecycleLoader: View {
    let session: AppSession
    let userId: UUID
    @State private var rsvpVM = RSVPViewModel()
    @State private var attendanceRecord: Attendance? = nil

    var isPast: Bool {
        (session.proposedAt.map { $0 < Date() } ?? false) || session.status == "completed"
    }

    var body: some View {
        SessionLifecycleCard(
            session: session,
            rsvpStatus: rsvpVM.myRSVP?.status,
            attended: attendanceRecord?.attended,
            onTap: { /* navigate */ }
        )
        .task {
            await rsvpVM.fetchRSVPs(sessionId: session.id, userId: userId)
            let records: [Attendance] = try? await supabase
                .from("attendance")
                .select()
                .eq("session_id", value: session.id.uuidString)
                .eq("user_id", value: userId.uuidString)
                .limit(1)
                .execute()
                .value ?? []
            attendanceRecord = records.first
        }
    }
}
```

---

## Key OnTrack constants (never hardcode differently)
```swift
let cardBg = Color(red: 0.08, green: 0.12, blue: 0.15).opacity(0.92)
let teal = Color(red: 0.08, green: 0.35, blue: 0.45)
let overlayBg = Color.black.opacity(0.72)
```

## Do not
- Use white card backgrounds
- Use lineWidth > 2 on any border
- Use opaque border colors (always use opacity)
- Hardcode background asset names
- Mix @Observable and ObservableObject patterns

# OnTrack UI Skill: Daily Actions Card Styling

Use this skill when making any visual changes to cards on DailyActionsView — borders, text colour, tick colour, completion states, or adding new row types.

---

## The three row types on DailyActionsView

| Row Type | Struct | File |
|---|---|---|
| Habit | `HabitRowView` | `Views/Habits/DailyActionsView.swift` |
| Supplement | `DailySupplementRowView` | `Views/Habits/DailyActionsView.swift` |
| Session | `DailySessionLifecycleRow` + `SessionLifecycleCard` | `DailyActionsView.swift` + `Views/RSVP/RSVPPickerView.swift` |

---

## Completed state visual rules (all rows must match)

### Border
```swift
.overlay(
    RoundedRectangle(cornerRadius: 12)
        .strokeBorder(
            isCompleted ? Color.green.opacity(0.7) : themeManager.currentTheme.primary.opacity(0.5),
            lineWidth: 2
        )
)
```
- Always lineWidth 2 — completed and incomplete
- Completed: `Color.green.opacity(0.7)`
- Incomplete: `themeManager.currentTheme.primary.opacity(0.5)`
- Corner radius 12 for habit/supplement rows

### Title text
```swift
Text(name).font(.body).foregroundColor(isCompleted ? .green : .white)
```

### Subtitle/label text
```swift
Text(label).font(.caption2).foregroundColor(isCompleted ? .green.opacity(0.7) : .white.opacity(0.6))
```

### Toggle circle (checkmark button)
```swift
Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
    .foregroundColor(isCompleted ? .green : .white.opacity(0.6))
    .font(.title2)
```

---

## Session card special rules

Session cards use `SessionLifecycleCard` in `RSVPPickerView.swift` which has its own border logic. When used on DailyActionsView (`showToggle: true`), the border is overridden like this:
```swift
.strokeBorder(
    showToggle ? (attended == true ? Color.green.opacity(0.7) : Color(red: 0.08, green: 0.35, blue: 0.45).opacity(0.5)) : s.borderColor,
    lineWidth: 2
)
```

- When `showToggle` is true and `attended` is true → green border
- When `showToggle` is true and `attended` is false → teal border
- When `showToggle` is false → use the RSVP lifecycle borderColor from style struct

---

## Card background (never change)
```swift
Color(red: 0.08, green: 0.12, blue: 0.15).opacity(0.92)
```

## Key constants
```swift
let teal = Color(red: 0.08, green: 0.35, blue: 0.45)
let cardBg = Color(red: 0.08, green: 0.12, blue: 0.15).opacity(0.92)
```

## Do not
- Use different lineWidths across row types — keep all at 2
- Use white card backgrounds
- Change border opacity above 0.7
- Apply List modifiers (listRowBackground etc) — DailyActionsView uses LazyVStack not List

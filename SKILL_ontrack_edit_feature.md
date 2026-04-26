# SKILL: Add Edit Feature to an Existing Create Flow

## When to use
Use this pattern whenever a feature has a CreateXView + ViewModel with `new*` fields but no edit/update capability yet.

## Step-by-step process

### Step 1 — Read the Create view
Search for: `save|Save|title|location|Button`
Goal: Identify all form fields and what ViewModel properties they bind to.

### Step 2 — Read the ViewModel
Search for: `new*` props + `update|edit`
Goal: Confirm the `new*` field names and verify no `updateX()` function exists yet.

### Step 3 — Read the Detail view
Search for: `admin|isAdmin|created_by|createdBy|toolbar|Button`
Goal: Find the creator gate condition, check for existing toolbar, find where to add the Edit button + sheet.

### Step 4 — Write three changes in one Claude Code prompt

1. **Add `updateX(item:)` to the ViewModel**
   - Takes the existing item as parameter (for its ID)
   - Builds payload from `new*` fields
   - Calls `.update(payload).eq("id", value: item.id.uuidString)`
   - Sets `isLoading` and `errorMessage` like other functions

2. **Create `EditXView.swift` in the same Views folder**
   - Same form structure as CreateXView (copy SectionCard blocks)
   - `.onAppear` pre-fills all `viewModel.new*` fields from the existing item
   - Save button calls `updateX(item:)` and dismisses on success
   - Cancel button dismisses without saving
   - No recurrence section (V1 — single item edit only)

3. **Add Edit button + sheet to DetailView**
   - Add `@State private var showEditX = false`
   - Add `.toolbar { ToolbarItem(.topBarTrailing) { if creatorGate { Button("Edit") { showEditX = true } } } }`
   - Add `.sheet(isPresented: $showEditX) { EditXView(...).environmentObject(appState).environmentObject(themeManager) }`

## Key gotchas
- Always check the Swift model property name for `description` — it may be mapped differently to avoid Swift's built-in `description`
- `SectionCard` and `OnTrackTextField` are defined in `CreateSessionView.swift` — they are available to `EditSessionView` since it's in the same module
- Gate the Edit button on `item.createdBy == appState.currentUser?.id` (not just isAdmin)
- For supplements, gate on `supplement.userId == appState.currentUser?.id`
- Pass `.environmentObject(appState)` and `.environmentObject(themeManager)` on all presented sheets

## Applied to
- ✅ Sessions: `EditSessionView.swift` + `SessionViewModel.updateSession(session:)`

# Implementation Plan: Stack Analysis — ground in knowledge_items + link to Knowledge

## Context
StackAnalysisCard sends a cold AI prompt; ground it in the user's matching `knowledge_items` rows (cheaper/more accurate, no new tables, no peptide-protocol injection) and make matched compounds tappable into the existing KnowledgeDetailView.

## Scope note (brief was stale)
KnowledgeLibraryView + KnowledgeDetailView/CardView/ProtocolView + KnowledgeViewModel(@Observable) already built & shipped (v1.5.4); `knowledge_items`/`knowledge_protocols` tables already seeded & applied. So Goals 1 & 3 = done/skip. Cowork is mid-flight on "protocols tab + collapsible filters" — this plan touches ONLY `SupplementsView.swift`; do not edit `Views/Knowledge/*`. Coordinate before running if Cowork is live.

## Changes
### SupplementsView.swift — `runStackAnalysis()` (lines 228-291)
- Before building `prompt`: for each of `viewModel.protocolSupplements` (cap 12), fuzzy-match `knowledge_items` exactly like `AddSupplementView.swift:459-466` (`.select().eq("is_published",true).ilike("title","%name%").limit(1)`), collect into `[(supp, KnowledgeItem)]`. Build a compact `Reference notes:` block (per item: `title · category · dosage · benefits.joined(", ") · description prefix(240)`).
- New prompt: keep the same JSON output contract (`conflicts/synergies/suggestions`), but prepend the reference block and add: "Use ONLY these reference notes plus the protocol; do not invent compounds or doses; if a claim isn't supported by the notes, omit it." Keep `cleaned`/JSON-parse/`saveAnalysisToCache`/`loadAnalysisFromCache` (lines 293-311) untouched — output shape unchanged so 24h cache stays valid.
- Store matched items on a new `@State private var stackKnowledgeItems: [KnowledgeItem] = []` in `ProtocolView` (set on MainActor alongside `stackAnalysis`), so the card can show them even from cache-less reload (re-fetch is fine; or skip when cache hit).

### SupplementsView.swift — `ProtocolView` (~lines 193-340)
- Add `@State private var knowledgeVM = KnowledgeViewModel()` and `@State private var selectedKnowledgeItem: KnowledgeItem?`.
- Pass `knowledgeItems: stackKnowledgeItems` and `onOpenKnowledge: { selectedKnowledgeItem = $0 }` into `StackAnalysisCard(...)` (line 351).
- Add `.sheet(item: $selectedKnowledgeItem) { NavigationStack { KnowledgeDetailView(item: $0, viewModel: knowledgeVM, userId: appState.currentUser?.id) } }` on the ScrollView.

### SupplementsView.swift — `StackAnalysisCard` (lines 721-870)
- New params: `let knowledgeItems: [KnowledgeItem]`, `let onOpenKnowledge: (KnowledgeItem) -> Void`.
- After the analysis sections, if `!knowledgeItems.isEmpty`: a "Learn more" horizontal `ScrollView` of capsule chips (one per matched `KnowledgeItem`, title text) styled with `cardBg`/purple to match; tap → `onOpenKnowledge(item)`. (No NLP-matching of sentence text — deterministic chips from the same matches used for grounding.)
- Card colour stays `Color(red:0.08,green:0.12,blue:0.15).opacity(0.92)`; dark-only; no white cards. Section "Consider Adding" label/behaviour unchanged.

## Implementation Sequence (one file, build between logical chunks)
1. `runStackAnalysis()` + `ProtocolView` state — fetch+inject reference notes, store matched items. `xcodebuild` ✓.
2. `StackAnalysisCard` — add params + chip row; wire `onOpenKnowledge`/sheet in `ProtocolView`. `xcodebuild` ✓.

## Edge Cases & Risks
- Cowork editing SupplementsView concurrently → collision. Mitigation: confirm Cowork idle/committed before step 1; this plan never touches Views/Knowledge/*.
- No `knowledge_items` match for any supplement → reference block empty; prompt still works (falls back to current behaviour). Chip row hidden.
- Extra Supabase round-trips (≤12) before AI call → minor latency; acceptable, AI call dominates.
- `KnowledgeDetailView` may assume push nav → wrap in `NavigationStack` inside the sheet (AddSupplementView pushes it via NavigationLink; sheet+NavigationStack is equivalent context).
- `swipeActions`/List rules N/A (card is in a ScrollView/VStack).

## Verification
`xcodebuild -project /Users/matthewblake/Desktop/OnTrack/OnTrack/OnTrack.xcodeproj -scheme OnTrack -destination 'platform=iOS Simulator,name=iPhone 16' build` → BUILD SUCCEEDED; manual: Supplements → Protocol tab (2+ supplements) → Analyse → conflicts/synergies/suggestions render; "Learn more" chips appear for matched compounds; tap chip → KnowledgeDetailView sheet; relaunch → cached result still renders.

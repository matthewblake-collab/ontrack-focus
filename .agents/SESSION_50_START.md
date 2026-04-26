# SESSION 50 — START

> Created 2026-04-18 (Session 49 prep) | Pivot context: marketing-pivot-2026-04-18.md

## Goal

Wire the new video pipeline end-to-end and record the first batch of clips. End the session with one fully-rendered .mp4 (no actual posting) and the Post Bridge skill installed and dry-run verified.

---

## Prerequisites — Matt does these BEFORE opening Claude Code tomorrow

> Do not start the Claude Code session until every box below is checked. Several of the build steps depend on env vars and recorded clips being on disk.

### ElevenLabs (10 min)
- [ ] Sign up for **ElevenLabs Starter** at https://elevenlabs.io ($5/mo)
- [ ] Open the **Voice Library**, filter for: Australian, male, 30s, confident-conversational
- [ ] Pick **3 candidate voice_ids** and note them
- [ ] Generate the same 20-second test script in all 3 — use a real OnTrack hook ("Willpower runs out. Your group doesn't. That's the whole mechanic behind OnTrack — the system that makes it harder to stop than to keep going.")
- [ ] Listen on headphones (not laptop speakers — voice tone shifts), pick the winner
- [ ] Save the chosen `voice_id` (and 2 backups) into `~/.OnTrack-Marketing/stack.md` under the **Voice** section

### Post Bridge (15 min)
- [ ] Sign up at https://post-bridge.com ($5/mo)
- [ ] Connect via OAuth: Instagram, TikTok, YouTube, X, LinkedIn, Facebook, Threads
- [ ] Enable the API access add-on ($5/mo)
- [ ] Save the API key as env var: `export POST_BRIDGE_API_KEY=...` (add to `~/.zshrc`, then `source ~/.zshrc`)
- [ ] **Never commit this key.** Confirm `.gitignore` covers `.env*` and `~/.zshrc` is not tracked.

### Recording (45–60 min)
- [ ] Set up the demo Supabase account with seed data per `~/.OnTrack-Marketing/recording-shot-list.md` (Recording setup section)
- [ ] Set iPhone status bar to demo mode (9:41, full battery, full Wi-Fi, full bars)
- [ ] Record the first 10 clips from the shot list, prioritising:
  - `home_daily_actions_overview.mov`
  - `home_tap_habit_complete.mov`
  - `home_streak_count_animate.mov`
  - `groups_list_overview.mov`
  - `groups_chat_send_message.mov`
  - `mentalhealth_check_in_sliders.mov`
  - `supplements_log_dose_taken.mov`
  - `mentalhealth_trends_carousel.mov`
  - `friends_feed_likes.mov`
  - `notifications_bell_sheet.mov`
- [ ] Save all raw clips to `~/.OnTrack-Marketing/clips/raw/` (`mkdir -p` first)

---

## Tomorrow's Claude Code work

> Run `/ultraplan` FIRST. This is multi-file architectural — touches the morning routine, post pipeline, Remotion compositions, compliance filter, analytics loop, watchdog, and cost ceiling. UltraPlan before code.

After UltraPlan finishes:

1. **Install Post Bridge agent-mode skill** — `npx skills add post-bridge-hq/agent-mode`. Verify SKILL.md present in `~/.claude/skills/`.
2. **Wire ElevenLabs TTS into `/content-scripter`** — add a step after script generation that pipes the chosen hook + body text to ElevenLabs API, output `.mp3` to `/tmp/ontrack-vo-<idea_id>.mp3`. Cache by hash so re-runs do not double-spend.
3. **Build the first Remotion composition: "Feature Demo"** template in `~/Desktop/OnTrack-Reel/src/FeatureDemo.tsx`:
   - 0:00–0:02 — branded intro (dark card with logo, fade in)
   - 0:02–0:04 — hook text (TikTok word-by-word reveal)
   - 0:04–0:18 — screen recording with VO + captions
   - 0:18–0:22 — stat or proof card
   - 0:22–0:24 — CTA outro ("Free on TestFlight")
   - Cite the `remotion-best-practices` skill while building.
4. **Replace `/post-content`** — swap Computer Use Playwright path for Post Bridge API calls. Keep `--dry-run` as the default until proven over 3+ live posts.
5. **Compliance filter** — Claude-based check between render and Telegram approval. Block on supplement, peptide, medical, or therapeutic claims. Output verdict + flagged passages.
6. **Analytics feedback loop** — `/shortform-analysis` output (top hooks of the past 7 days, lowest-performing pillars) is concatenated as additional context into the next `/daily-content-researcher` run.
7. **Failure watchdog** in `run-morning-routine.sh` — if no Telegram approval received by 8:15am AEST, ping Matt with a "morning routine waiting on you" message.
8. **Cost ceiling** — kill the routine if ElevenLabs daily spend (queried via their billing API) exceeds $2. Hardcode the threshold; expose it via env var later.
9. **End-to-end dry run** — one test idea → script → VO → render → compliance pass → Telegram preview → Post Bridge `--dry-run`. No live posting. Confirm every step's logs land in the expected place.

---

## Session exit criteria

- [ ] Post Bridge skill installed
- [ ] ElevenLabs voice rendering an .mp3 from a real script
- [ ] Feature Demo Remotion composition rendering a real .mp4 with VO + captions + intro + outro
- [ ] Compliance filter blocking at least one synthetic test claim
- [ ] Watchdog and cost ceiling code in `run-morning-routine.sh`
- [ ] One end-to-end dry-run completed with logs reviewed
- [ ] No actual social posts made

---

## Reference

- Pivot rationale: `~/Brain/02-projects/ontrack/marketing-pivot-2026-04-18.md`
- Stack doc: `~/.OnTrack-Marketing/stack.md`
- Shot list: `~/.OnTrack-Marketing/recording-shot-list.md`
- Marketing CLAUDE.md: `~/.OnTrack-Marketing/CLAUDE.md`
- Project CLAUDE.md: `~/Desktop/OnTrack/OnTrack/CLAUDE.md`

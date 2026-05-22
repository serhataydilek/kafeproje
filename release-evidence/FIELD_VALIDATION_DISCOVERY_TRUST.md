# Field Validation Evidence Playbook - Discovery Trust

Date: 2026-04-05
Project: Istanbul Cafe Discovery
Purpose: Fast but credible field-validation evidence before wide public release.

## Scope
Districts in this run:
- Sisli
- Kagithane
- Besiktas
- Kadikoy
- Sariyer

Trust dimensions validated:
1. False positives (non-cafe venues shown as cafes).
2. False negatives (known cafes missing repeatedly).
3. Map/list/detail consistency (same entity and media across surfaces).
4. Coverage balance using debug diagnostics (including quadrants).

Known diagnostics (Map Debug card in debug build):
- radius
- visible
- filtered
- raw fetched
- classifier rejected
- dedupe rejected
- quadrants TL/TR/BL/BR

Reference implementation:
- Map debug card appears only in debug mode: [../lib/screens/map_screen.dart](../lib/screens/map_screen.dart#L571)
- Debug card fields rendered: [../lib/screens/map_screen.dart](../lib/screens/map_screen.dart#L1072)
- Radius presets used in validation:
  - small = 1000m
  - medium = 3000m
  - large = 6000m
  - Source: [../lib/providers/app_core_providers.dart](../lib/providers/app_core_providers.dart#L63)

---

## Fast Execution Plan (90-120 min)

1. Setup and calibration (10 min)
- Use debug build.
- Ensure location permission granted and stable network.
- Restart app once to avoid stale UI state.
- Verify Map Debug card is visible.

2. District loops (5 districts x 14-18 min)
- For each district:
  - Run required radius presets.
  - Capture mandatory screenshots.
  - Perform consistency and trust checks.
  - Log pass/fail with short evidence note.

3. Final triage and signoff draft (10-20 min)
- Apply severity rubric to all findings.
- Produce concise final signoff summary.

---

## District Validation Plan

## 1) Sisli
Route/setup:
- Open map.
- Apply district filter Sisli if available.
- Pan through Bomonti -> Mecidiyekoy -> Osmanbey corridor.

Radius presets:
- small (1000m)
- medium (3000m)

Expected pass criteria:
- visible stays non-trivial across pans in dense streets (target >= 12 in medium).
- classifier rejected does not dominate raw fetched for the whole pass (rough guide: < 65%).
- No systematic quadrant starvation (all quadrants should show some presence after 2-3 pans).
- 5 sampled cafes preserve identity across map card, list row, and detail page.

Trust-destroying failure examples:
- Frequent borek/pide/doner-style venues shown as cafes.
- Marker tap repeatedly opens wrong cafe in dense overlap blocks.
- Same cafe shows conflicting name/media between map and detail.

## 2) Kagithane
Route/setup:
- Apply district filter Kagithane if available.
- Traverse Caglayan -> Hamidiye -> Seyrantepe edges.

Radius presets:
- medium (3000m)
- large (6000m)

Expected pass criteria:
- medium shows usable density (target >= 8 visible).
- large improves edge coverage without heavy one-side clustering.
- Quadrant imbalance is not persistent across repeated fetches.
- At least 3 known-local cafes are discoverable in full run.

Trust-destroying failure examples:
- Large radius still leaves one side effectively empty while raw fetched is high.
- Repeated refreshes produce volatile, inconsistent district coverage.
- False positives exceed believable local cafe mix.

## 3) Besiktas
Route/setup:
- Apply district filter Besiktas.
- Focus on high-density overlap zones: Besiktas center -> Ortakoy -> Levent fringe.

Radius presets:
- small (1000m)
- medium (3000m)

Expected pass criteria:
- Overlap handling remains tappable and deterministic.
- visible remains strong in medium (target >= 15).
- dedupe rejected can be elevated but should not collapse usable visible set.
- 5 overlap samples: marker tap target matches opened detail every time.

Trust-destroying failure examples:
- Marker overlap selects neighboring cafe unpredictably.
- Card/detail mismatch after marker selection.
- Severe dedupe churn that hides legitimate nearby cafes.

## 4) Kadikoy
Route/setup:
- Apply district filter Kadikoy.
- Traverse Moda -> Rasimpasa -> Caddebostan zones.

Radius presets:
- medium (3000m)
- large (6000m)

Expected pass criteria:
- Strong discovery breadth in medium and large (target >= 15 medium, >= 20 large in active zones).
- False-negative rate low for known-cafe checklist.
- raw fetched growth from medium to large is reflected by stable visible growth (not pure reject growth).
- 5 sampled cafes consistent across map/list/detail and images.

Trust-destroying failure examples:
- Well-known cafes repeatedly missing after refresh and pan.
- Large radius only increases rejects while visible remains flat.
- District label mismatch or obvious neighborhood misclassification in surfaced cafes.

## 5) Sariyer
Route/setup:
- If district filter exists in current environment, use Sariyer filter.
- If not, run manual map-centered route: Emirgan -> Istinye -> Tarabya/Buyukdere coastline.

Radius presets:
- large (6000m)
- medium (3000m)

Expected pass criteria:
- large produces broad-but-plausible spread for sparse/coastal geography.
- quadrant distribution is not persistently collapsed to a single side after route pans.
- At least 2-3 known Sariyer cafes appear in full pass.
- False positives remain low despite broader radius.

Trust-destroying failure examples:
- Near-empty map despite repeated large-radius refresh in active sub-areas.
- Systematic one-quadrant dominance across route.
- Non-cafe chains or food venues repeatedly passing as cafes.

---

## Tester Checklist (per district)

1. Confirm current district route segment and selected radius.
2. Capture diagnostics values:
- visible
- filtered
- raw fetched
- classifier rejected
- dedupe rejected
- TL/TR/BL/BR
3. Run one pan-refresh cycle and re-check diagnostics.
4. Validate false positives:
- inspect top 10 surfaced venues
- flag non-cafe venue types
5. Validate false negatives:
- check known-cafe list for district
- mark missing candidates after at least 2 refresh cycles
6. Validate consistency:
- sample 5 cafes
- compare map card, list row, detail page (name, area, media)
7. Record findings and severity.

---

## Screenshot Checklist

Mandatory captures:
1. One Map Debug screenshot per district per radius used.
2. One map marker selection screenshot for overlap-heavy area (Besiktas and Sisli required).
3. One list screenshot after map interaction for cross-surface comparison.
4. One detail page screenshot for each sampled mismatch (if any).
5. One screenshot showing quadrant values in sparse district runs (Kagithane and Sariyer required).

Minimum expected count:
- District/radius debug captures: 10
- Consistency captures: 5+
- Issue captures: as needed

Naming format:
- fieldval_<district>_<radius>_<sequence>.png
- Example: fieldval_besiktas_small_01.png

---

## Evidence Template For Release Notes

Use one block per district:

```md
District: <name>
Tester: <name>
Build: <build id>
Device/OS: <device>
Date UTC: <timestamp>

Route executed:
- <area 1>
- <area 2>

Radius runs:
- small/medium/large

Diagnostics summary (best representative run):
- visible: <n>
- filtered: <n>
- raw fetched: <n>
- classifier rejected: <n>
- dedupe rejected: <n>
- quadrants: TL <n>, TR <n>, BL <n>, BR <n>

False positive check:
- inspected: <n>
- suspicious: <n>
- notes: <text>

False negative check:
- checklist size: <n>
- missing after retries: <n>
- notes: <text>

Map/list/detail consistency:
- sampled cafes: <n>
- mismatches: <n>
- notes: <text>

Verdict: PASS | FAIL
Severity (if fail): Critical | High | Medium | Low
Artifacts:
- <screenshot paths>
```

---

## Severity Rubric

Critical:
- Widespread trust break (systematic wrong venues, severe mismatch, or near-empty discovery in major district).
- Release-blocking.

High:
- Reproducible major trust issue in one district (persistent false negatives or marker-target mismatch).
- Release should not proceed without fix or explicit mitigation signoff.

Medium:
- Noticeable but localized quality issue (intermittent quadrant imbalance, small mismatch cluster).
- Can proceed only with documented mitigation and post-release watchlist.

Low:
- Cosmetic or rare inconsistency with no material trust impact.
- Track for routine stabilization.

---

## Concise Pass/Fail Matrix

| District | Route complete | Radius complete | False-positive check | False-negative check | Map/list/detail consistency | Quadrant balance check | Verdict |
|---|---|---|---|---|---|---|---|
| Sisli |  |  |  |  |  |  | PASS/FAIL |
| Kagithane |  |  |  |  |  |  | PASS/FAIL |
| Besiktas |  |  |  |  |  |  | PASS/FAIL |
| Kadikoy |  |  |  |  |  |  | PASS/FAIL |
| Sariyer |  |  |  |  |  |  | PASS/FAIL |

Matrix usage rule:
1. Mark a district PASS only when all trust columns are complete and no unresolved High/Critical issue exists.
2. Any unresolved Critical issue in one district forces overall NO-GO.

---

## Final Signoff Summary Format

```md
Field Validation Signoff - Discovery Trust
Date:
Build:
Scope: Sisli, Kagithane, Besiktas, Kadikoy, Sariyer

District verdicts:
- Sisli: PASS/FAIL (severity if fail)
- Kagithane: PASS/FAIL (severity if fail)
- Besiktas: PASS/FAIL (severity if fail)
- Kadikoy: PASS/FAIL (severity if fail)
- Sariyer: PASS/FAIL (severity if fail)

Aggregate metrics:
- total sampled cafes:
- total mismatches:
- total suspected false positives:
- total suspected false negatives:

Release recommendation:
- GO / NO-GO

Blocking findings (if any):
1. <finding>
2. <finding>

Mitigations and owners:
1. <action> - <owner> - <target date>
```

Signoff rule:
- GO only if no Critical findings and no unresolved High findings in any district.

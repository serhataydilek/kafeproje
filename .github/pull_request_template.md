## Summary
- What changed:
- Why now:
- Scope boundaries (what is intentionally not changed):

## User/Product Impact
- User-facing behavior changed:
- Product/business impact:
- Any migration or compatibility note:

## Contracts Touched
Check all that apply and explain impact briefly.

- [ ] Router/widget boundary (`FilterModalScreen` stays constructor-driven; no deep router-state reads)
- [ ] Rating policy (`effectiveRating` app/admin-only; Google rating metadata-only)
- [ ] Test determinism (time, async synchronization, repeatability)
- [ ] Fake/mock isolation (no test fallthrough to real backend paths)
- [ ] Plugin/runtime harness isolation (no plugin-dependent crashes in general tests)

Contract impact notes:
- Router/widget boundary:
- Rating policy:
- Determinism:
- Fake/mock isolation:
- Plugin isolation:

## Validation Performed
- [ ] `flutter analyze`
- [ ] `flutter test -r compact`
- [ ] Relevant focused tests for changed modules

Command outputs summary:
- Analyze result:
- Test result:
- Focused test result:

## Test Determinism Check
- [ ] No wall-clock dependency introduced in tests
- [ ] No guessed delays used where deterministic settle/signal exists
- [ ] Time/TTL tests use controlled time boundaries (before/at/after)
- [ ] No flaky selectors or brittle interaction assumptions introduced

Notes:

## Fake/Mock Isolation Check
- [ ] Test doubles fail loudly on unexpected calls
- [ ] No fake/mock code path can reach real backend behavior
- [ ] Test fixtures remain deterministic and scenario-specific

Notes:

## Routing/Widget Boundary Check
- [ ] Route-derived values are passed at route boundary, not read deep in reusable widgets
- [ ] `FilterModalScreen` remains usable outside router page context
- [ ] No reusable widget now depends on `GoRouterState` internally

Notes:

## Rating Policy Check
- [ ] `effectiveRating` logic remains app/admin-only
- [ ] Google rating remains metadata-only
- [ ] No policy drift introduced in model/service/UI mapping
- [ ] Contract tests updated when rating behavior changed

Notes:

## Risk and Rollback Notes
- Risk level: Low / Medium / High
- Primary risk areas:
- Rollback strategy:
- Feature flag or guarded release needed:

## Reviewer Checklist
- [ ] Scope is minimal and aligned with stated intent
- [ ] No baseline contract violations
- [ ] Tests are deterministic and meaningful
- [ ] Fakes/mocks are strict and isolated
- [ ] Plugin paths are correctly harnessed
- [ ] Routing boundaries are clean (no deep router coupling)
- [ ] Rating policy remains intact
- [ ] Analyze/tests evidence is included

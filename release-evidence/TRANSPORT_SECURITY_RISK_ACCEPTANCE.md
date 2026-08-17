# Transport Security Risk Acceptance Memo

Date: 2026-04-05
Project: Istanbul Cafe Discovery
Release scope: Public release candidate
Decision owner: Security/Release authority

## Decision
For this release, certificate pinning is deferred.

Approved path:
- Do not implement pinning in this release candidate.
- Ship with explicit risk acceptance and compensating controls.
- Time-box this exception with an implementation deadline.

## Why this is the fastest trustworthy path

Current implementation facts:
- Pinning flag is disabled: [../lib/constants/security_config.dart](../lib/constants/security_config.dart#L88)
- Google Places traffic uses direct HTTPS via package:http client: [../lib/services/places_service.dart](../lib/services/places_service.dart#L158), [../lib/services/places_service.dart](../lib/services/places_service.dart#L283)
- Remote image fetches use a separate package:http client path: [../lib/services/app_image_cache_manager.dart](../lib/services/app_image_cache_manager.dart#L24)
- Supabase networking is initialized through SDK default transport path: [../lib/main.dart](../lib/main.dart#L47)

Complexity and rollout risk assessment:
1. Network stack is not centralized behind one TLS client abstraction.
2. Pinning would need coordinated handling across at least three paths:
- Places HTTP client
- image cache HTTP client
- Supabase SDK transport (plus auth/storage/realtime behaviors)
3. Provider certificates are managed by external infrastructure with rotation cadence outside app control.
4. A pinning mistake can create hard production outages for all users.
5. Public-release timeline favors low-regression hardening over high-risk transport rewiring.

Conclusion:
- Implementing pinning now is high outage risk for this release window.
- Deferral with strict controls is the safer release decision.

## Accepted risk
Residual risk accepted for this release:
- Increased exposure to advanced MITM scenarios that rely on compromised trust roots or hostile network paths.

Risk boundaries:
- TLS still relies on platform trust store validation.
- No custom certificate bypass callback is implemented in app code paths reviewed.

## Compensating controls (required for release)

1. Endpoint scope control
- Keep all app network endpoints HTTPS-only.
- Block any introduction of HTTP endpoints in code review.

2. Provider-side security hardening
- Enforce strict Supabase RLS policies and readiness checks.
- Keep admin destructive mutation guard active in runtime path.

3. Credential and key restrictions
- Google API keys must remain app-restricted (Android package/signature, iOS bundle).
- Supabase anon key exposure is treated as expected public key; authorization stays policy-driven.

4. Detection and response
- Monitor auth/authorization failures and suspicious activity during rollout.
- Add release watch for transport/certificate-related failure spikes in logs/crash telemetry.

5. Operational rollback readiness
- Keep staged rollout and hotfix readiness for transport regressions.
- Define release stop condition if transport error rate crosses threshold.

## Expiry and exit criteria

Exception expiry:
- This risk acceptance expires on 2026-07-31 or next major release, whichever comes first.

Exit criteria (must be completed before expiry):
1. Implement domain-scoped SPKI pinning for first-party critical endpoints first (Supabase custom domain or fixed first-party host set).
2. Add backup pins and documented rotation runbook.
3. Add automated pre-release validation for pin mismatch and cert rotation simulation.
4. Roll out pinning behind staged release gates and telemetry checks.

## Release verdict statement
Transport security decision for this release: pinning deferred with explicit risk acceptance and compensating controls; acceptable for public launch only under the controls listed above and within the stated expiry window.

## Signoff
Security lead:
Release manager:
Date:

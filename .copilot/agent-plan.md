# Agent Plan
# First gate: mark a plan item as approved to move it into the backlog.
# Once moved, it leaves this file and enters `.copilot/agent-backlog.txt` as pending.
# Plan status values: planned, approved
# Fields: id | status | priority | complexity | dependencies | title

## backend
plan-3 | planned | high | medium | plan-2 | Add backend tests and production safety rails
  Goal:
  Add meaningful backend coverage, safer rollout defaults, and better observability.
  Why:
  Infra and mobile have validation, but backend critical flows are still under-tested.
  Likely files:
  `my-app/backend/...`, `my-app/infra/lib/infra-stack.ts`, `my-app/infra/test/infra.test.ts`.

## frontend
(empty)

## both
plan-6 | planned | medium | medium | plan-1,plan-4 | Add marketplace timeline and in-app activity visibility
  Goal:
  Show request lifecycle progress clearly and provide a stable in-app activity center.
  Why:
  Core request flow works, but visibility is still too opaque for helpers and recyclers.
  Likely files:
  dashboard screens, request models/provider, backend request/activity emission logic.

plan-7 | planned | medium | medium | plan-1,plan-4 | Add saved addresses and reusable request templates
  Goal:
  Make repeat pickup creation faster for returning users.
  Why:
  This is a high-value retention improvement with clear user-facing payoff.
  Likely files:
  request creation flow, profile/dashboard surfaces, backend request/template storage.

plan-8 | planned | medium | large | plan-5 | Add trust foundations for verification and payment-ready profiles
  Goal:
  Introduce verification state and the backend/mobile shape needed for BankID and payment extensions.
  Why:
  Trust and monetization work should start with visible verification-ready primitives, not ad hoc UI.
  Likely files:
  profile UI, auth/backend files, secrets/config surfaces, future payment integration points.

plan-9 | planned | medium | medium | plan-1,plan-6 | Add structured categories and helper-side marketplace filters
  Goal:
  Support material categories plus filtering by distance, time, reward, and material type.
  Why:
  The helper marketplace already sorts well, but it still lacks strong filtering and job qualification signals.
  Likely files:
  helper marketplace UI, request models/provider, backend filtering/index support.

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
plan-12 | planned | high | medium | plan-6 | Add a notifications inbox and fine-grained notification preferences
  Goal:
  Give users a durable in-app notification center plus control over push and lifecycle alerts.
  Why:
  Marketplace visibility is much stronger with plan-6, but users still need a dependable place to review missed updates and tune noisy alerts.
  Likely files:
  `my-app/mobile/lib/screens/...`, notification/provider files, backend notification preference storage and delivery surfaces.

## both
plan-6 | planned | medium | medium | plan-1,plan-4 | Add marketplace timeline and in-app activity visibility
  Goal:
  Show request lifecycle progress clearly and provide a stable in-app activity center.
  Why:
  Core request flow works, but visibility is still too opaque for helpers and recyclers.
  Likely files:
  dashboard screens, request models/provider, backend request/activity emission logic.

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

plan-10 | planned | high | large | plan-6,plan-8 | Add real-time chat and attachment sharing between recycler and helper
  Goal:
  Support in-app conversation on active requests, including lightweight image sharing for pickup coordination.
  Why:
  Once trust and activity visibility improve, direct coordination becomes the next high-value conversion and completion unlock.
  Likely files:
  backend websocket/message persistence files, mobile request detail screens, notification hooks, auth/ownership checks.

plan-11 | planned | high | large | plan-8 | Add helper earnings, payout status, and completed-job summaries
  Goal:
  Show helpers their completed rewards, pending payouts, and a clean earnings history that can later connect to payments.
  Why:
  Verification-ready profiles are more valuable when helpers can immediately see economic progress and payout readiness.
  Likely files:
  helper dashboard/profile UI, backend reward aggregation endpoints, request completion/payout state models.

plan-14 | planned | high | large | plan-1,plan-8 | Add issue reporting, moderation notes, and safety incident handling
  Goal:
  Let users report no-shows, unsafe interactions, and disputed pickups, with backend state to support follow-up and moderation.
  Why:
  As the marketplace grows, trust requires not only verification but also clear incident handling and accountability flows.
  Likely files:
  request detail/reporting UI, backend request/report models, admin/moderation support endpoints, notification surfaces.

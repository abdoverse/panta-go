# Agent Plan
# First gate: mark a plan item as approved to move it into the backlog.
# Once moved, it leaves this file and enters `.copilot/agent-backlog.txt` as pending.
# Plan status values: planned, approved
# Fields: id | status | priority | complexity | dependencies | title

## backend
plan-3 | planned | high | medium | none | Add backend tests and production safety rails
  Goal:
  Add meaningful backend coverage, safer rollout defaults, and better observability.
  Why:
  Infra and mobile have validation, but backend critical flows are still under-tested.
  Likely files:
  `my-app/backend/...`, `my-app/infra/lib/infra-stack.ts`, `my-app/infra/test/infra.test.ts`.

plan-15 | planned | high | medium | plan-11 | Add payout ledger, receipt, and export APIs
  Goal:
  Expose payout history, downloadable receipts, and export-ready summaries for completed helper earnings.
  Why:
  Professional marketplace operations need more than a visible earnings total; helpers and future finance workflows need durable payout records.
  Likely files:
  `my-app/backend/cmd/api/...`, payout/reward models, request completion handlers, future finance export endpoints.

plan-16 | planned | high | medium | plan-14 | Add admin operations queue and moderation case APIs
  Goal:
  Provide structured admin-side case records, escalation states, and resolution APIs for reports, disputes, and safety incidents.
  Why:
  Incident reporting only becomes operationally useful when support and moderation can work cases through a real queue.
  Likely files:
  `my-app/backend/cmd/api/...`, moderation/report models, auth/role checks, admin support endpoints.

plan-25 | planned | high | large | plan-20,plan-24 | Add invoicing, billing accounts, and tax-ready transaction records
  Goal:
  Support invoice generation, billing entities, and tax-aware transaction records for business customers and future finance workflows.
  Why:
  Professional revenue operations require invoice-grade records, not only consumer-style reward and credit flows.
  Likely files:
  backend billing and transaction models, payout/invoice endpoints, organization account surfaces, export/reporting logic.

plan-26 | planned | high | medium | plan-3,plan-22 | Add audit logs, admin access trails, and compliance event retention
  Goal:
  Record sensitive admin actions, support interventions, and key account events with durable audit trails.
  Why:
  As support, payouts, and moderation mature, operational trust depends on traceability and internal accountability.
  Likely files:
  backend middleware, admin/support endpoints, audit event models, storage/retention configuration.

## frontend
plan-12 | planned | high | medium | plan-6 | Add a notifications inbox and fine-grained notification preferences
  Goal:
  Give users a durable in-app notification center plus control over push and lifecycle alerts.
  Why:
  Marketplace visibility is much stronger with plan-6, but users still need a dependable place to review missed updates and tune noisy alerts.
  Likely files:
  `my-app/mobile/lib/screens/...`, notification/provider files, backend notification preference storage and delivery surfaces.

plan-17 | planned | high | medium | plan-11 | Add a professional helper performance dashboard
  Goal:
  Show helpers conversion, completion, cancellation, rating, and earnings KPIs in a clean dashboard.
  Why:
  Serious helpers need visibility into how they are performing, not just a list of jobs and a raw balance.
  Likely files:
  helper dashboard UI, provider state, stats models, earnings/rating summary surfaces.

plan-18 | planned | high | medium | plan-12 | Add calendar sync, reminder settings, and no-show prevention UX
  Goal:
  Help recyclers and helpers sync pickups to calendars, control reminder timing, and avoid missed appointments.
  Why:
  Stronger reminders and calendar integration directly improve completion rates for scheduled marketplace activity.
  Likely files:
  request detail and scheduling UI, notification settings, reminder models, mobile platform integration surfaces.

plan-19 | planned | high | medium | none | Add favorite helpers and one-tap rebooking surfaces
  Goal:
  Let recyclers favorite past helpers and launch repeat bookings from a dedicated shortcut area, not only from raw history.
  Why:
  Repeat behavior is higher-value when the app remembers preferred helpers and exposes faster retention loops on the home surface.
  Likely files:
  dashboard/home UI, history/profile screens, request creation flow, helper preference models.

plan-27 | planned | high | medium | plan-20 | Add business portal dashboards for operations managers
  Goal:
  Give business customers an operations-focused dashboard for active pickups, site performance, pending approvals, and team activity.
  Why:
  Business accounts become materially more valuable when managers can supervise activity without relying on consumer-oriented screens.
  Likely files:
  business dashboard UI, organization summaries, request analytics cards, team/location management surfaces.

plan-28 | planned | medium | medium | plan-23 | Add branded shareable impact reports and presentation-ready exports
  Goal:
  Let users and business accounts generate polished impact reports they can share internally or externally.
  Why:
  Sustainability value becomes more commercially useful when it can be presented cleanly to stakeholders and customers.
  Likely files:
  report/export UI, dashboard/profile surfaces, branding/report template components, PDF/share flows.

plan-29 | planned | high | medium | plan-18,plan-21 | Add driver-style helper shift mode and route overview UX
  Goal:
  Provide a dedicated helper work mode for active shifts, route sequencing, stop completion, and live workload context.
  Why:
  Power helpers need a focused operating experience once batching and availability windows exist.
  Likely files:
  helper workflow screens, map/route UI, availability state, active job sequencing surfaces.

plan-36 | planned | high | medium | plan-6 | Add a clearer "Where is my pickup?" tracking screen
  Goal:
  Give recyclers a single place to see request status, next step, ETA language, and what they should do now.
  Why:
  Users feel uncertainty most when they do not know what happens next after booking.
  Likely files:
  request detail UI, timeline/progress widgets, notification handoff surfaces, status models.

plan-37 | planned | medium | medium | none | Add a saved-items organizer for favorite addresses, notes, and pickup presets
  Goal:
  Let users manage their most-used booking details from one lightweight settings area.
  Why:
  Practical retention improves when users can reuse their own patterns without digging through history.
  Likely files:
  profile/settings UI, request preset models, provider state, saved-address surfaces.

plan-38 | planned | high | medium | plan-10 | Add photo-first pickup preparation and item guidance
  Goal:
  Help users attach quick photos and get simple prep guidance before a helper arrives.
  Why:
  Better preparation reduces failed pickups, confusion, and chat back-and-forth.
  Likely files:
  create-request flow, request detail UI, upload/image components, backend attachment metadata.

plan-39 | planned | medium | medium | plan-12 | Add a personal reminders center with snooze and "remind me later"
  Goal:
  Let users manage pickup reminders in a more human way without turning notifications fully off.
  Why:
  Users often want fewer interruptions, not zero communication.
  Likely files:
  notification preferences UI, reminder state, inbox surfaces, scheduling helpers.

## both
plan-6 | planned | medium | medium | none | Add marketplace timeline and in-app activity visibility
  Goal:
  Show request lifecycle progress clearly and provide a stable in-app activity center.
  Why:
  Core request flow works, but visibility is still too opaque for helpers and recyclers.
  Likely files:
  dashboard screens, request models/provider, backend request/activity emission logic.

plan-8 | planned | medium | large | none | Add trust foundations for verification and payment-ready profiles
  Goal:
  Introduce verification state and the backend/mobile shape needed for BankID and payment extensions.
  Why:
  Trust and monetization work should start with visible verification-ready primitives, not ad hoc UI.
  Likely files:
  profile UI, auth/backend files, secrets/config surfaces, future payment integration points.

plan-9 | planned | medium | medium | plan-6 | Add structured categories and helper-side marketplace filters
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

plan-14 | planned | high | large | plan-8 | Add issue reporting, moderation notes, and safety incident handling
  Goal:
  Let users report no-shows, unsafe interactions, and disputed pickups, with backend state to support follow-up and moderation.
  Why:
  As the marketplace grows, trust requires not only verification but also clear incident handling and accountability flows.
  Likely files:
  request detail/reporting UI, backend request/report models, admin/moderation support endpoints, notification surfaces.

plan-20 | planned | high | large | plan-8 | Add business accounts with team roles and multi-location pickups
  Goal:
  Support organizations that manage several pickup sites, internal request approvers, and multiple staff members under one account.
  Why:
  Business usage expands order volume and revenue, but it requires more professional account structure than single-user consumer flows.
  Likely files:
  auth/account models, organization/location UI, backend role and ownership logic, request creation permissions.

plan-21 | planned | high | large | plan-6,plan-9 | Add smart scheduling, route batching, and helper availability windows
  Goal:
  Let helpers publish working windows and enable batching of nearby jobs into more efficient pickup routes.
  Why:
  Marketplace liquidity improves when supply can be scheduled more intelligently instead of treating each job as an isolated event.
  Likely files:
  helper availability UI, marketplace ranking logic, backend scheduling/batching models, request assignment surfaces.

plan-22 | planned | high | large | plan-10,plan-16 | Add a support inbox with escalation chat and manual intervention workflows
  Goal:
  Give users a visible support channel for disputes or stuck jobs, with escalation paths that connect to moderation/admin tooling.
  Why:
  A professional service needs a clear intervention path when marketplace automation is not enough.
  Likely files:
  support/help UI, chat/escalation flows, backend support case models, admin/support integration points.

plan-23 | planned | medium | medium | plan-6 | Add sustainability impact dashboards and downloadable recycling certificates
  Goal:
  Show individual and business users measurable recycling impact, milestone summaries, and exportable sustainability proof.
  Why:
  Impact visibility creates a professional value story for retention, business adoption, and brand differentiation.
  Likely files:
  dashboard/profile UI, backend aggregation/reporting endpoints, request completion metrics, PDF/export surfaces.

plan-24 | planned | high | medium | plan-11,plan-19 | Add referrals, credits, and promotional pricing rules
  Goal:
  Support referral rewards, user credits, and campaign-style pricing incentives for repeat growth.
  Why:
  Once repeat-booking and helper preference loops exist, growth mechanics can compound retention and acquisition professionally.
  Likely files:
  wallet/credit UI, checkout/reward surfaces, backend campaign and ledger models, referral tracking endpoints.

plan-30 | planned | high | large | plan-20,plan-25 | Add contract pricing, SLA tiers, and managed service packages
  Goal:
  Support negotiated business pricing, service-level tiers, and package-style managed pickup plans for larger customers.
  Why:
  Professional monetization grows beyond one-off jobs when the platform can sell recurring service packages and SLAs.
  Likely files:
  pricing and contract models, business account UI, backend quoting/rules logic, billing and request policy surfaces.

plan-31 | planned | high | large | plan-21,plan-29 | Add live fleet tracking, ETA prediction, and dynamic reassignment
  Goal:
  Improve marketplace reliability with live helper tracking, ETA updates, and controlled reassignment when plans change mid-route.
  Why:
  Once route workflows exist, live operational visibility becomes the next major trust and efficiency multiplier.
  Likely files:
  realtime location flows, map/ETA UI, backend tracking and reassignment logic, notification updates.

plan-32 | planned | high | medium | plan-16,plan-26 | Add role-based access control across support, finance, and operations
  Goal:
  Introduce explicit internal roles and permissions for support, moderation, finance, and business operations capabilities.
  Why:
  Expanding admin and business workflows safely requires formal access boundaries instead of broad implicit privileges.
  Likely files:
  auth/permission models, admin UI guards, backend role checks, audit-linked access surfaces.

plan-33 | planned | medium | large | plan-22,plan-30 | Add white-label and partner-embedded marketplace capabilities
  Goal:
  Let partners run branded marketplace experiences powered by the same backend workflows and operational controls.
  Why:
  White-label capability opens a higher-value B2B distribution path beyond direct end-user growth.
  Likely files:
  branding/config models, frontend theming surfaces, partner account logic, auth/domain configuration, API tenant scoping.

plan-34 | planned | high | medium | plan-25,plan-32 | Add fraud detection, anomaly review, and payout-risk controls
  Goal:
  Detect suspicious booking, payout, and referral behavior and route risky events into review before settlement.
  Why:
  As payouts, credits, and business billing expand, risk controls become necessary to protect margins and trust.
  Likely files:
  backend anomaly rules, payout/referral models, admin review UI, audit and event scoring surfaces.

plan-40 | planned | high | medium | plan-6,plan-18 | Add weather-aware pickup suggestions and reschedule prompts
  Goal:
  Proactively suggest better pickup windows or rescheduling when weather is likely to affect outdoor collections.
  Why:
  This is practical, user-facing intelligence that improves reliability without adding heavy operational complexity.
  Likely files:
  scheduling UI, request timeline surfaces, backend weather/scheduling logic, notification prompts.

plan-41 | planned | high | medium | plan-9,plan-21 | Add "best match" helper recommendations for each request
  Goal:
  Show users the most suitable nearby helpers based on category, distance, availability, and reliability.
  Why:
  Better matching improves confidence and makes the marketplace feel more helpful and premium.
  Likely files:
  request detail UI, helper ranking logic, provider models, backend recommendation endpoints.

plan-42 | planned | medium | medium | plan-23 | Add neighborhood goals, streaks, and friendly recycling milestones
  Goal:
  Turn sustainability progress into small motivating goals without making the app feel gimmicky.
  Why:
  Light, practical motivation can improve repeat usage when tied to real pickup behavior.
  Likely files:
  dashboard/profile UI, impact metrics, milestone models, notification copy surfaces.

plan-43 | planned | high | medium | plan-14,plan-22 | Add a post-pickup follow-up flow with issue resolution shortcuts
  Goal:
  Give users a clean post-pickup screen for rating, thanking, reporting issues, or requesting a quick support follow-up.
  Why:
  The end of the service experience is where trust and repeat intent are often won or lost.
  Likely files:
  completion/rating UI, support/report shortcuts, request lifecycle state, notification follow-ups.

plan-44 | planned | high | medium | plan-19,plan-24 | Add a household membership plan with perks for frequent users
  Goal:
  Offer frequent recyclers a simple membership with perks like booking priority, bonus credits, or premium support.
  Why:
  This is a practical monetization and retention feature that still feels directly valuable in the app.
  Likely files:
  membership/paywall UI, wallet/credit surfaces, backend subscription/benefit logic, booking priority rules.

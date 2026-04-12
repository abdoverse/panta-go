# Panta Go numbered execution plan

## 1. Objective
Create an execution-ready roadmap for **Panta Go** so another agent can take over a specific numbered part without re-analyzing the repository.

## 2. Current project state
1. **Architecture**
   - Flutter client in `my-app/mobile`
   - Go backend in `my-app/backend`
   - AWS CDK infrastructure in `my-app/infra`
2. **Working MVP capabilities**
   - Cognito sign up and login
   - Pickup request creation
   - Image upload to S3
   - Address suggestions
   - Helper job discovery and distance sorting
   - Accept / cancel / complete request flow
   - Rating flow
   - WebSocket realtime updates
   - Firebase push notifications
3. **Quality baseline**
   - Flutter tests pass
   - Infra Jest test passes
   - Backend has no automated tests

## 3. Main issues discovered
1. **Data model and access**
   - Backend uses DynamoDB `Scan` for request listing
   - Request ownership is weakly modeled
   - `myRequests` is not truly filtered by current user
2. **Security and configuration**
   - Mobile app contains hardcoded backend/auth/push configuration
   - Session persistence is unfinished
   - Logout flow is incomplete
   - CORS and WebSocket origin/auth rules are too permissive
3. **Backend maintainability**
   - Most logic is in one `main.go`
   - Routing, auth, uploads, notifications, storage, and realtime are tightly coupled
4. **Mobile maintainability**
   - `PantaProvider` has too many responsibilities
   - Error handling and state transitions need clearer boundaries
5. **Production readiness**
   - Infra includes destructive or rollout-unsafe settings
   - Observability is minimal
   - Backend test coverage is missing

## 4. How to use this plan
1. Tell the next agent to execute **one numbered plan item** at a time.
2. If you want low-risk sequencing, start with **items 1 and 2**.
3. If you want product-facing work after the foundation, continue with **items 6 and 7**.
4. Each item below includes:
   - **Goal**
   - **Why it matters**
   - **Likely files**
   - **Dependencies**
   - **Definition of done**

## 5. Numbered execution items

### 1. Harden the request domain model and DynamoDB access
1. **Goal**
   - Replace scan-based request access with query-oriented access patterns.
   - Add explicit creator/owner identity fields.
   - Prepare the request model for cleaner lifecycle handling.
2. **Why it matters**
   - This is the biggest structural issue affecting scale and correctness.
   - Many later features depend on having proper ownership and query patterns.
3. **Likely files**
   - `my-app/backend/cmd/api/main.go`
   - `my-app/infra/lib/infra-stack.ts`
   - `my-app/mobile/lib/providers/panta_provider.dart`
   - `my-app/mobile/lib/models/request_model.dart`
4. **Dependencies**
   - None
5. **Definition of done**
   - Requests are no longer fetched through a full table scan for the main app flows.
   - Each request has explicit ownership fields.
   - User-specific request views are backed by real ownership logic.
   - Infra supports the new access pattern, likely through indexes.

### 2. Secure auth, session handling, and runtime configuration
1. **Goal**
   - Move hardcoded runtime config out of app code.
   - Finish session persistence and restore-on-launch behavior.
   - Make logout actually clear auth state.
   - Tighten CORS and WebSocket auth/origin behavior.
2. **Why it matters**
   - This is the highest-risk production hardening area after data modeling.
3. **Likely files**
   - `my-app/mobile/lib/services/api_config.dart`
   - `my-app/mobile/lib/services/auth_service.dart`
   - `my-app/mobile/lib/main.dart`
   - `my-app/mobile/lib/app.dart`
   - `my-app/mobile/lib/features/shared/profile_screen.dart`
   - `my-app/backend/cmd/api/main.go`
   - `my-app/backend/cmd/api/websocket.go`
4. **Dependencies**
   - None
5. **Definition of done**
   - No production-critical client config is hardcoded unnecessarily.
   - Auth sessions persist correctly or fail explicitly with a clear flow.
   - Logout fully clears session state.
   - WebSocket auth/origin rules and CORS are tightened for production.

### 3. Split the backend into maintainable modules
1. **Goal**
   - Refactor the Go backend into smaller packages or layers for auth, requests, uploads, notifications, and realtime.
2. **Why it matters**
   - The current single-file backend will slow down every future change.
3. **Likely files**
   - `my-app/backend/cmd/api/main.go`
   - New backend package directories under `my-app/backend/`
4. **Dependencies**
   - Best done after item 1
   - Can partially overlap with item 2 if boundaries are clear
5. **Definition of done**
   - Main routing/bootstrap code is separated from business logic.
   - Request operations, auth validation, uploads, and notifications are modular.
   - Refactoring does not change intended behavior.

### 4. Improve mobile state architecture
1. **Goal**
   - Reduce the responsibility of `PantaProvider`.
   - Separate auth/session, request operations, location, and realtime concerns more clearly.
2. **Why it matters**
   - Future features will otherwise pile more logic into one provider.
3. **Likely files**
   - `my-app/mobile/lib/providers/panta_provider.dart`
   - `my-app/mobile/lib/services/*.dart`
   - Dashboard/auth/profile files under `my-app/mobile/lib/features/`
4. **Dependencies**
   - Best after item 2
   - Can run after or alongside item 3
5. **Definition of done**
   - `PantaProvider` is noticeably slimmer.
   - Networking/auth/location/realtime responsibilities are better separated.
   - The UI keeps the same behavior or improves predictably.

### 5. Improve release safety, observability, and test coverage
1. **Goal**
   - Add backend tests.
   - Improve infra safety for production rollouts.
   - Add clearer observability signals.
2. **Why it matters**
   - Without this, the app remains hard to ship and hard to trust operationally.
3. **Likely files**
   - `my-app/backend/...`
   - `my-app/infra/lib/infra-stack.ts`
   - `my-app/infra/test/infra.test.ts`
   - Existing mobile test files if behavior changes
4. **Dependencies**
   - Best after item 3
5. **Definition of done**
   - Backend has meaningful automated coverage for critical flows.
   - Infra no longer relies on rollout-unsafe defaults for production.
   - The project has clearer logging and operational visibility.

### 6. Add marketplace quality features
1. **Goal**
   - Improve the user experience of the pickup marketplace without introducing major platform risk.
2. **Recommended feature slice**
   - Request status timeline
   - Better cancellation/reassignment flow
   - Filters for distance, time, reward, and material type
   - In-app activity/notification center
3. **Why it matters**
   - These features improve trust, reduce confusion, and make the marketplace feel complete.
4. **Likely files**
   - `my-app/mobile/lib/features/dashboard/*.dart`
   - `my-app/mobile/lib/providers/panta_provider.dart`
   - `my-app/mobile/lib/models/request_model.dart`
   - `my-app/backend/cmd/api/main.go`
5. **Dependencies**
   - Best after item 1
   - Better after item 4
6. **Definition of done**
   - Users can understand request progress clearly.
   - Helpers and recyclers get better visibility and better filtering.
   - Important events are visible in-app, not only through push.

### 7. Add trust and monetization features
1. **Goal**
   - Add identity/trust systems and payment-related capabilities.
2. **Recommended feature slice**
   - BankID verification
   - Verified badge in profile
   - Swish payment or payout flow
   - Better helper reputation history
   - Basic admin/moderation tooling
3. **Why it matters**
   - This is the most commercially meaningful product expansion path.
4. **Likely files**
   - `my-app/mobile/lib/features/shared/profile_screen.dart`
   - Auth/backend files
   - New payment/verification service integration files
   - Infrastructure files for secrets/config if needed
5. **Dependencies**
   - Best after items 1 and 2
   - Safer after item 5
6. **Definition of done**
   - Verification state is visible and trustworthy.
   - Payment flow is production-safe in scope.
   - Reputation and moderation support real marketplace trust.

### 8. Add retention and growth features
1. **Goal**
   - Improve repeat usage and long-term engagement.
2. **Recommended feature slice**
   - Saved addresses
   - Repeat pickup templates
   - Reminders before pickup windows
   - Recycling impact metrics
   - Streaks or lightweight engagement loops
   - Referral/invite flow
3. **Why it matters**
   - These features help growth, but they should come after the core marketplace is hardened.
4. **Likely files**
   - Request creation flow files
   - Profile/dashboard files
   - Backend request and notification flows
5. **Dependencies**
   - Best after items 1, 4, and 6
6. **Definition of done**
   - Repeat usage requires less effort than first-time usage.
   - Users see reasons to return and track their impact.

## 6. Suggested features list
1. **Saved addresses**
   - **Background:** Recycler users will often create pickups from the same places: home, office, storage, or a family property. The current flow makes them search for the address every time.
   - **Value:** Reduces friction in the request creation flow and should increase repeat usage because creating a pickup becomes faster.
   - **Rough implementation:** Add a saved-address entity linked to the user, expose CRUD endpoints in the backend, and add a “Choose saved address” option in the request creation screen. Reuse the existing location model and prefill the location field and coordinates.
   - **Best fit after:** items 1 and 4.
2. **Repeat pickup templates**
   - **Background:** Many pickup requests are repetitive: same address, similar material, similar notes, similar reward range, and similar time windows.
   - **Value:** Improves retention and increases request volume by reducing form fatigue. It also creates a clearer path for recurring household or small-business usage.
   - **Rough implementation:** Allow users to save a completed or submitted request as a reusable template. Store title, description, address reference, category, reward, and optional photo guidance defaults. Add “Use template” at the top of the request form.
   - **Best fit after:** items 1, 4, and 8.
3. **Request status timeline**
   - **Background:** The current lifecycle exists in logic, but the user experience is still too opaque. Users need to know not only the current state, but also what already happened.
   - **Value:** Improves trust and reduces support confusion. A recycler can see whether a helper accepted, canceled, or completed the job, and a helper can see progress context clearly.
   - **Rough implementation:** Expand the request state model into timeline events such as created, accepted, canceled, reassigned, completed, rated. Store either event records or structured status transition metadata. Render a timeline component in request detail cards or a detail screen.
   - **Best fit after:** items 1 and 6.
4. **In-app activity center**
   - **Background:** Push notifications are useful but unreliable as the only source of truth. Users can dismiss them, disable them, or miss them.
   - **Value:** Gives both recyclers and helpers a stable place to review recent activity, which increases transparency and reduces missed updates.
   - **Rough implementation:** Add an activity feed tied to user identity. Backend emits activity items when requests are created, accepted, canceled, completed, rated, or verified. Mobile app shows a dedicated notifications/activity tab or inbox screen and tracks unread state.
   - **Best fit after:** items 4 and 6.
5. **Distance, reward, time, and material filters**
   - **Background:** Helper job discovery currently relies mainly on sorting and a simple list experience. That works for small volume, but not once the marketplace grows.
   - **Value:** Makes the helper side more efficient, reduces irrelevant jobs, and should improve acceptance quality and conversion.
   - **Rough implementation:** Extend the request model with material categories and normalized filterable fields. Add UI filters in the helper marketplace and support matching query parameters or indexed filtering in the backend.
   - **Best fit after:** items 1 and 6.
6. **Helper availability and service radius**
   - **Background:** A helper may be online but not actually available for every job, every time, or every location. The current system has limited availability intent.
   - **Value:** Improves marketplace quality, lowers avoidable cancellations, and helps route the right jobs to the right helpers.
   - **Rough implementation:** Add helper profile preferences for availability windows, active/inactive status, and a preferred service radius. Use that data to prioritize, filter, or suppress jobs before they are shown.
   - **Best fit after:** items 1, 4, and 6.
7. **Material categories and photo guidance**
   - **Background:** A generic request title and freeform description are often not enough to assess pickup difficulty, pricing, or required vehicle type.
   - **Value:** Helps helpers evaluate jobs faster, improves pricing consistency, and reduces poor matches.
   - **Rough implementation:** Add structured categories such as furniture, electronics, construction waste, garden waste, mixed recyclables, and bulky waste. Add lightweight UI hints telling the user what photos to upload and what information to include.
   - **Best fit after:** items 1 and 6.
8. **BankID verification**
   - **Background:** In a real-world pickup marketplace, trust is critical. Users may be exchanging access to homes, buildings, or valuable goods.
   - **Value:** Strong identity verification reduces fraud risk, improves user confidence, and creates a stronger foundation for payments and dispute handling.
   - **Rough implementation:** Integrate BankID server-side flows for auth/sign verification, store verification status and timestamps on user profiles, and expose verification state to the mobile client. This likely needs new backend endpoints, secure secrets handling, and verification status in profile/UI logic.
   - **Best fit after:** items 2 and 7.
9. **Verified badge in profile**
   - **Background:** Verification has little product value if it is not visible where users make trust decisions.
   - **Value:** Gives users a fast trust signal and makes the verification work legible inside the app.
   - **Rough implementation:** Extend the profile and request-card UI to show verified state, possibly with levels such as verified identity or verified payout setup. Source it from the user profile data returned by the backend.
   - **Best fit after:** items 2 and 7.
10. **Swish payment or payout flow**
   - **Background:** If Panta Go becomes a serious marketplace, money flow will likely be needed either for request payments, helper payouts, or premium service logic.
   - **Value:** Opens monetization, supports paid pickups, and makes the platform more viable commercially.
   - **Rough implementation:** Define whether the first scope is recycler-to-helper payment, platform-collected payment, or helper payout support. Implement backend payment initiation, callback handling, status persistence, and UI states for payment pending/succeeded/failed. Swish likely requires backend-first integration and careful security handling.
   - **Best fit after:** items 2, 5, and 7.
11. **Helper reputation history**
   - **Background:** The current rating model is lightweight and mostly attached to individual requests. That makes it hard to present a fuller trust picture over time.
   - **Value:** Improves decision-making for recyclers and gives good helpers a stronger reputation advantage.
   - **Rough implementation:** Create a helper reputation summary model that aggregates completed jobs, cancellations, ratings, recent feedback, and possibly badges such as “high completion rate.” Show this in helper profile and request assignment views.
   - **Best fit after:** items 1 and 7.
12. **Admin operations dashboard**
   - **Background:** Once real users and transactions exist, the team will need internal tools for moderation, disputes, stuck jobs, fraud review, and manual interventions.
   - **Value:** Reduces operational chaos and makes the business supportable beyond pure self-service flows.
   - **Rough implementation:** Add an internal-only admin surface, likely web-based, backed by role-protected backend endpoints. Include searchable request lists, user lookup, verification status, dispute flags, cancellation history, and action logs.
   - **Best fit after:** items 5 and 7.
13. **Pickup reminders**
   - **Background:** Pickups are time-bound, and missed windows hurt both user trust and completion rates.
   - **Value:** Improves completion reliability and gives users a stronger sense that the platform is helping them stay on schedule.
   - **Rough implementation:** Add scheduled reminder events based on request time windows. Trigger push notifications and in-app reminders before scheduled pickup windows, and allow opt-in or opt-out preferences.
   - **Best fit after:** items 4 and 8.
14. **Impact metrics and streaks**
   - **Background:** Recycling has an emotional and social value dimension. Users often respond well to visible contribution and progress tracking.
   - **Value:** Improves retention, gives users a reason to come back, and makes the brand feel more mission-driven.
   - **Rough implementation:** Start simple with counts such as completed pickups, estimated items recycled, or avoided waste events. Later add streaks, milestones, and celebratory UI tied to successful completions.
   - **Best fit after:** items 6 and 8.
15. **Referral or invite flow**
   - **Background:** Referral loops work best after the product is trustworthy and repeatable. Before that, they amplify weak retention.
   - **Value:** Supports growth at relatively low acquisition cost once the marketplace quality is strong enough.
   - **Rough implementation:** Add invite codes or referral links tied to a user account, backend tracking for successful invited signups or completed first jobs, and optional rewards or credits once a referral milestone is met.
   - **Best fit after:** items 6, 7, and 8.

## 7. Recommended execution order
1. **Start here:** item 1
2. **Then:** item 2
3. **Then:** item 3
4. **Then:** item 4
5. **Then:** item 5
6. **Then choose one product branch**
   - item 6 for marketplace quality
   - item 7 for trust/monetization
   - item 8 for retention/growth

## 8. Best items to delegate immediately
1. **Item 1** if you want the strongest architecture improvement first.
2. **Item 2** if you want the strongest security/config hardening first.
3. **Item 6** if you want visible product UX improvements after foundation work.
4. **Item 7** if you want to push toward commercial readiness.

## 9. Suggested prompts for another agent
1. **Execute item 1**
   - “Read the plan file and execute item 1 only: harden the request domain model and DynamoDB access. Keep changes scoped to that item.”
2. **Execute item 2**
   - “Read the plan file and execute item 2 only: secure auth, session handling, and runtime configuration. Keep changes scoped to that item.”
3. **Execute item 6**
   - “Read the plan file and execute item 6 only: add marketplace quality features, starting with the request status timeline and in-app activity visibility.”
4. **Execute item 7**
   - “Read the plan file and execute item 7 only: add trust and monetization foundations, starting with verification state and payment-ready architecture.”

## 10. Final recommendation
1. If you want the safest path, tell the next agent to execute **item 1** first.
2. If you want the most security-focused path, tell the next agent to execute **item 2** first.
3. If you want visible product progress after hardening, tell the next agent to execute **item 6** next.

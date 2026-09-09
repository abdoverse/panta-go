# Panta Go To-Do List

1. [x] Implement https
2. [x] use bare minimum ecs ram and cpu specs to decrease cost.
3. [x] recycler rating, has to be more accurate and more user friendly. from 1 to 5. based on completed jobs and canceled jobs. 1 being the worst and 5 being the best. 0 canceled jobs mean 5.
4. [x] Add google maps/Apple integration. The recycler can click on the address and it will open the map with the location. Also add a button to get directions to the location on their choosen map app.
5. [x] Advanced: Add bankId integration for secure user identification and signing. This will require backend support to handle the BankID authentication flow and ensure compliance with security standards. For both recycler and helper. On profile, there should be a verified patch.
6. [x] When a helper opens their App,  jobs closer to their geographical location should be prioritized and shown at the top of the list. This will improve user experience by making it easier for helpers to find relevant jobs nearby.
7. [x] do a cool animation when the helper completes a job. It can be a confetti animation or something similar to celebrate the completion of the task and enhance user satisfaction.
8. [ ] Fix Emoji Rendering on Flutter Web: Emojis sent in the chatbox currently render as black-and-white symbols or black boxes after being sent. Investigate Flutter Web CanvasKit font fallback issues with the custom 'Inter' Google Font, or find a reliable multi-platform emoji rendering package.
9. [ ] Enable location access to fully work on phone and laptop
10. [ ] Add under profile, "About Panta" to contain the actual released version of the app
11. [ ] Add a feedback section where any user can leave feedback to the team
12. [ ] Allow users to edit their first and last name in Profile with multi-language support (Arabic, Chinese, and other Unicode special characters)
13. [ ] Display user's email address on the Profile page
14. [ ] Implement GDPR-compliant cookie support and consent banner adhering to Swedish legal standards for online businesses

## Production Readiness
1. [ ] Use real BankID certificates and keys
2. [ ] Set market limits
3. [ ] Comprehensive GDPR Compliance:
   - **Right to Erasure / Right to be Forgotten (Article 17)**: Self-serve account deletion and automated purge of all personal data across DynamoDB, S3, Cognito, and system logs
   - **Right of Access & Portability (Articles 15 & 20)**: Self-serve Data Subject Access Request (DSAR) export in machine-readable JSON format
   - **Right to Rectification (Article 16)**: Seamless updating and correction of personal identity, names, and contact details
   - **Storage Limitation & Automated Retention (Article 5(1)(e))**: Scheduled retention and deletion policies for chat history, delivery proof images, and location trails
   - **Data Minimization & Identifier Masking (Article 5(1)(c))**: Pseudonymization and masking of Swedish personal identity numbers (`personnummer`) and banking data at rest and in transit
   - **Security of Processing & Encryption (Article 32)**: Mandatory TLS 1.3 in transit and AES-256-GCM / AWS KMS encryption at rest across all data stores
   - **Records of Processing & Audit Trails (Articles 30 & 33)**: Durable audit logging of administrative access, data modification/erasure events, and 72-hour breach notification readiness
4. [ ] Lockdown Auth in production: Disable mock `/api/v1/login` and require real AWS Cognito SRP / OAuth2 authentication
5. [ ] Disable dev & simulation endpoints in production: Block `/api/v1/auth/bankid/simulate-complete` and `/api/v1/demo/seed`
6. [ ] Add AWS WAF & backend rate limiting: Attach WAF rules (IP rate limit, OWASP Top 10) to ECS gateway and add Go HTTP rate-limiting middleware
7. [ ] Add HTTP security headers middleware: Inject HSTS (`Strict-Transport-Security`), CSP (`Content-Security-Policy`), `X-Frame-Options: DENY`, and `X-Content-Type-Options: nosniff`
8. [ ] Distributed state for BankID sessions and WebSockets: Persist BankID order refs in DynamoDB with TTL instead of in-memory maps; add multi-instance pub/sub support
9. [ ] Configure ECS high availability & zero-downtime deployments: Scale to `min: 2, max: 4` tasks with autoscaling, `minimumHealthyPercent: 100`, and production target group draining

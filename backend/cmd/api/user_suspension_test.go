package main

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

func TestUserSuspension_LifecycleAndEnforcement(t *testing.T) {
	mux := http.NewServeMux()
	registerAuthRoutes(mux)
	registerRequestRoutes(mux)
	registerAdminRoutes(mux)

	adminToken := generateTestAdminToken()
	testUserEmail := "fraudster.recycler@example.com"
	testUserID := userUUID(testUserEmail)
	caseRef := "CASE-2026-LEGAL-042"

	// 1. Initial State: user can log in
	loginPayload := map[string]string{
		"username": testUserEmail,
		"role":     "user",
	}
	body, _ := json.Marshal(loginPayload)
	req := httptest.NewRequest(http.MethodPost, "/api/v1/login", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	rr := httptest.NewRecorder()
	mux.ServeHTTP(rr, req)

	if rr.Code != http.StatusOK {
		t.Fatalf("expected login status 200 before block, got %d", rr.Code)
	}

	// 2. Non-admin cannot block user
	userToken := generateTestUserToken("user")
	blockPayload := map[string]interface{}{
		"userId":          testUserID,
		"email":           testUserEmail,
		"reason":          "Repeated submission of altered recycling receipts",
		"caseReferenceId": caseRef,
	}
	body, _ = json.Marshal(blockPayload)
	req = httptest.NewRequest(http.MethodPost, "/api/v1/admin/users/block", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+userToken)
	rr = httptest.NewRecorder()
	mux.ServeHTTP(rr, req)

	if rr.Code != http.StatusForbidden {
		t.Fatalf("expected non-admin block request to be forbidden (403), got %d", rr.Code)
	}

	// 3. Admin blocks user
	req = httptest.NewRequest(http.MethodPost, "/api/v1/admin/users/block", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+adminToken)
	rr = httptest.NewRecorder()
	mux.ServeHTTP(rr, req)

	if rr.Code != http.StatusOK {
		t.Fatalf("expected admin block status 200, got %d: %s", rr.Code, rr.Body.String())
	}

	// Verify audit log has been created
	adminLogsMu.RLock()
	foundAudit := false
	for _, l := range adminLogs {
		if l.Category == "LEGAL_INVESTIGATION" && l.Details["caseReferenceId"] == caseRef {
			foundAudit = true
			if l.Level != "WARN" {
				t.Errorf("expected audit level WARN, got %s", l.Level)
			}
		}
	}
	adminLogsMu.RUnlock()
	if !foundAudit {
		t.Errorf("expected audit log entry for case %s was not found", caseRef)
	}

	// 4. Blocked user cannot log in
	body, _ = json.Marshal(loginPayload)
	req = httptest.NewRequest(http.MethodPost, "/api/v1/login", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	rr = httptest.NewRecorder()
	mux.ServeHTTP(rr, req)

	if rr.Code != http.StatusForbidden {
		t.Fatalf("expected blocked login status 403, got %d", rr.Code)
	}

	var blockResp map[string]interface{}
	_ = json.Unmarshal(rr.Body.Bytes(), &blockResp)
	if blockResp["code"] != "ACCOUNT_RESTRICTED" {
		t.Errorf("expected code ACCOUNT_RESTRICTED, got %v", blockResp["code"])
	}
	if blockResp["caseReferenceId"] != caseRef {
		t.Errorf("expected case reference %s, got %v", caseRef, blockResp["caseReferenceId"])
	}

	// 5. Blocked user cannot create request
	createPayload := map[string]interface{}{
		"title":         "Bags of cans",
		"location":      "Stockholm",
		"scheduledFrom": time.Now().Format(time.RFC3339),
		"scheduledTo":   time.Now().Add(time.Hour).Format(time.RFC3339),
	}
	body, _ = json.Marshal(createPayload)

	blockedClaims := &Claims{
		Role:            "user",
		CognitoUsername: testUserEmail,
		DisplayName:     "Fraudster",
		Email:           testUserEmail,
		UserID:          testUserID,
	}
	blockedToken, _ := signTestClaims(blockedClaims)
	req = httptest.NewRequest(http.MethodPost, "/api/v1/requests", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+blockedToken)
	rr = httptest.NewRecorder()
	mux.ServeHTTP(rr, req)

	if rr.Code != http.StatusForbidden {
		t.Fatalf("expected blocked create request status 403, got %d", rr.Code)
	}

	// 6. Admin lists blocks
	req = httptest.NewRequest(http.MethodGet, "/api/v1/admin/users/blocks?status=BLOCKED", nil)
	req.Header.Set("Authorization", "Bearer "+adminToken)
	rr = httptest.NewRecorder()
	mux.ServeHTTP(rr, req)

	if rr.Code != http.StatusOK {
		t.Fatalf("expected list blocks status 200, got %d", rr.Code)
	}

	// 7. Admin unblocks user
	unblockPayload := map[string]interface{}{
		"userId":          testUserID,
		"reason":          "Fraud dispute resolved after receipt verification",
		"caseReferenceId": caseRef,
	}
	body, _ = json.Marshal(unblockPayload)
	req = httptest.NewRequest(http.MethodPost, "/api/v1/admin/users/unblock", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+adminToken)
	rr = httptest.NewRecorder()
	mux.ServeHTTP(rr, req)

	if rr.Code != http.StatusOK {
		t.Fatalf("expected unblock status 200, got %d: %s", rr.Code, rr.Body.String())
	}

	// 8. User can log in again
	body, _ = json.Marshal(loginPayload)
	req = httptest.NewRequest(http.MethodPost, "/api/v1/login", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	rr = httptest.NewRecorder()
	mux.ServeHTTP(rr, req)

	if rr.Code != http.StatusOK {
		t.Fatalf("expected login status 200 after unblock, got %d", rr.Code)
	}
}

func signTestClaims(claims *Claims) (string, error) {
	if len(jwtSecret) == 0 {
		jwtSecret = []byte("local-dev-jwt-secret-key-panta-change-in-prod")
	}
	claims.RegisteredClaims.ExpiresAt = jwt.NewNumericDate(time.Now().Add(1 * time.Hour))
	claims.RegisteredClaims.Issuer = "panta-backend"
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString(jwtSecret)
}

func TestUserSuspension_Expiry(t *testing.T) {
	tempUser := "temp.suspended@example.com"
	tempUID := userUUID(tempUser)

	pastExpiry := time.Now().UTC().Add(-10 * time.Minute).Format(time.RFC3339)
	rec := &UserBlockRecord{
		UserID:          tempUID,
		Email:           tempUser,
		Status:          "BLOCKED",
		Reason:          "Cooldown pending verification",
		CaseReferenceID: "CASE-TEMP-001",
		BlockedAt:       time.Now().UTC().Add(-20 * time.Minute).Format(time.RFC3339),
		ExpiresAt:       pastExpiry,
	}

	_ = blockUser(rec)

	blocked, _ := isUserBlocked(tempUID, tempUser)
	if blocked {
		t.Errorf("expected user with past expiry to not be blocked")
	}
}

func TestUserSuspension_HistoryAndUsersEndpoints(t *testing.T) {
	mux := http.NewServeMux()
	registerAuthRoutes(mux)
	registerAdminRoutes(mux)

	adminToken := generateTestAdminToken()

	// 1. GET /api/v1/admin/users
	reqUsers := httptest.NewRequest(http.MethodGet, "/api/v1/admin/users", nil)
	reqUsers.Header.Set("Authorization", "Bearer "+adminToken)
	rrUsers := httptest.NewRecorder()
	mux.ServeHTTP(rrUsers, reqUsers)

	if rrUsers.Code != http.StatusOK {
		t.Fatalf("expected admin users status 200, got %d", rrUsers.Code)
	}

	var usersResp struct {
		Users []AdminUserInfo `json:"users"`
		Count int             `json:"count"`
	}
	if err := json.Unmarshal(rrUsers.Body.Bytes(), &usersResp); err != nil {
		t.Fatalf("failed to decode users response: %v", err)
	}
	if len(usersResp.Users) == 0 {
		t.Fatalf("expected non-empty users list")
	}

	// 2. GET /api/v1/admin/users/suspensions/history
	reqHist := httptest.NewRequest(http.MethodGet, "/api/v1/admin/users/suspensions/history", nil)
	reqHist.Header.Set("Authorization", "Bearer "+adminToken)
	rrHist := httptest.NewRecorder()
	mux.ServeHTTP(rrHist, reqHist)

	if rrHist.Code != http.StatusOK {
		t.Fatalf("expected suspension history status 200, got %d", rrHist.Code)
	}

	var histResp struct {
		History []SuspensionHistoryEntry `json:"history"`
		Count   int                      `json:"count"`
	}
	if err := json.Unmarshal(rrHist.Body.Bytes(), &histResp); err != nil {
		t.Fatalf("failed to decode history response: %v", err)
	}
	if len(histResp.History) == 0 {
		t.Fatalf("expected non-empty suspension history")
	}
}

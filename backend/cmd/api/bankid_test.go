package main

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

func TestMaskPersonalNumber(t *testing.T) {
	tests := []struct {
		input    string
		expected string
	}{
		{"199001011234", "19900101-****"},
		{"19900101-1234", "19900101-****"},
		{"9205121234", "19920512-****"},
		{"", "19900101-****"},
	}

	for _, tt := range tests {
		got := maskPersonalNumber(tt.input)
		if got != tt.expected {
			t.Errorf("maskPersonalNumber(%q) = %q, want %q", tt.input, got, tt.expected)
		}
	}
}

func TestHandleBankIdInitiate(t *testing.T) {
	t.Setenv("BANKID_MODE", "mock")
	payload := BankIdInitiateRequest{
		PersonalNumber: "199205121234",
		Role:           "helper",
		DisplayName:    "Sven Svensson",
	}
	body, _ := json.Marshal(payload)
	req := httptest.NewRequest(http.MethodPost, "/api/v1/auth/bankid/initiate", bytes.NewReader(body))
	w := httptest.NewRecorder()

	handleBankIdInitiate(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d", w.Code)
	}

	var res BankIdInitiateResponse
	if err := json.NewDecoder(w.Body).Decode(&res); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}

	if res.OrderRef == "" {
		t.Errorf("expected non-empty orderRef")
	}
	if res.AutoStartToken == "" {
		t.Errorf("expected non-empty autoStartToken")
	}
	if res.QrCode == "" {
		t.Errorf("expected non-empty qrCode")
	}
	if res.Status != "pending" {
		t.Errorf("expected status 'pending', got %q", res.Status)
	}
}

func TestHandleBankIdCollectLifecycle(t *testing.T) {
	t.Setenv("BANKID_MODE", "mock")
	// First initiate
	initPayload := BankIdInitiateRequest{
		PersonalNumber: "198503151234",
		Role:           "user",
		DisplayName:    "Anna Andersson",
	}
	initBody, _ := json.Marshal(initPayload)
	initReq := httptest.NewRequest(http.MethodPost, "/api/v1/auth/bankid/initiate", bytes.NewReader(initBody))
	initRec := httptest.NewRecorder()
	handleBankIdInitiate(initRec, initReq)

	var initRes BankIdInitiateResponse
	_ = json.NewDecoder(initRec.Body).Decode(&initRes)
	orderRef := initRes.OrderRef

	// Poll 1: Expect pending
	pollPayload := BankIdCollectRequest{OrderRef: orderRef}
	pollBody, _ := json.Marshal(pollPayload)
	req1 := httptest.NewRequest(http.MethodPost, "/api/v1/auth/bankid/collect", bytes.NewReader(pollBody))
	w1 := httptest.NewRecorder()
	handleBankIdCollect(w1, req1)

	if w1.Code != http.StatusOK {
		t.Fatalf("poll 1: expected 200, got %d", w1.Code)
	}
	var res1 BankIdCollectResponse
	_ = json.NewDecoder(w1.Body).Decode(&res1)
	if res1.Status != "pending" {
		t.Errorf("poll 1: expected pending, got %s", res1.Status)
	}

	// Poll 2: Expect pending (userSign)
	req2 := httptest.NewRequest(http.MethodPost, "/api/v1/auth/bankid/collect", bytes.NewReader(pollBody))
	w2 := httptest.NewRecorder()
	handleBankIdCollect(w2, req2)
	var res2 BankIdCollectResponse
	_ = json.NewDecoder(w2.Body).Decode(&res2)
	if res2.Status != "pending" || res2.HintCode != "userSign" {
		t.Errorf("poll 2: expected pending/userSign, got %s/%s", res2.Status, res2.HintCode)
	}

	// Poll 3: Expect complete
	req3 := httptest.NewRequest(http.MethodPost, "/api/v1/auth/bankid/collect", bytes.NewReader(pollBody))
	w3 := httptest.NewRecorder()
	handleBankIdCollect(w3, req3)
	var res3 BankIdCollectResponse
	_ = json.NewDecoder(w3.Body).Decode(&res3)
	if res3.Status != "complete" {
		t.Errorf("poll 3: expected complete, got %s", res3.Status)
	}
	if !res3.BankIdVerified {
		t.Errorf("poll 3: expected bankIdVerified true")
	}
	if res3.Token == "" {
		t.Errorf("poll 3: expected non-empty JWT token")
	}
	if res3.PersonalNumber != "19850315-****" {
		t.Errorf("poll 3: expected masked SSN, got %s", res3.PersonalNumber)
	}

	// Verify token claims
	claims, err := validateToken(res3.Token)
	if err != nil {
		t.Fatalf("failed to validate returned token: %v", err)
	}
	if !claims.BankIdVerified {
		t.Errorf("token claims BankIdVerified should be true")
	}
	if claims.Role != "user" {
		t.Errorf("token claims Role should be user, got %s", claims.Role)
	}
}

func TestHandleVerifyBankId(t *testing.T) {
	jwtSecret = []byte("test-secret-1234")

	claims := &Claims{
		Role:            "helper",
		CognitoUsername: "testhelper@example.com",
		DisplayName:     "Test Helper",
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(time.Hour)),
		},
	}

	verifyPayload := map[string]string{
		"personalNumber": "199408201234",
	}
	body, _ := json.Marshal(verifyPayload)
	req := httptest.NewRequest(http.MethodPost, "/api/v1/users/verify-bankid", bytes.NewReader(body))
	ctx := context.WithValue(req.Context(), userContextKey, claims)
	req = req.WithContext(ctx)
	w := httptest.NewRecorder()

	handleVerifyBankId(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", w.Code)
	}

	var res map[string]interface{}
	if err := json.NewDecoder(w.Body).Decode(&res); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}

	if res["bankIdVerified"] != true {
		t.Errorf("expected bankIdVerified true")
	}
	if res["bankIdPersonalNumber"] != "19940820-****" {
		t.Errorf("expected masked SSN, got %v", res["bankIdPersonalNumber"])
	}

	// Test Status endpoint with the newly returned BankID-verified session token
	tokenStr, ok := res["token"].(string)
	if !ok || tokenStr == "" {
		t.Fatalf("expected refreshed token in response")
	}
	refreshedClaims, err := validateToken(tokenStr)
	if err != nil {
		t.Fatalf("failed to validate refreshed token: %v", err)
	}

	statusReq := httptest.NewRequest(http.MethodGet, "/api/v1/users/verification-status", nil)
	statusReq = statusReq.WithContext(context.WithValue(req.Context(), userContextKey, refreshedClaims))
	statusW := httptest.NewRecorder()

	handleGetVerificationStatus(statusW, statusReq)

	if statusW.Code != http.StatusOK {
		t.Fatalf("status endpoint: expected 200, got %d", statusW.Code)
	}
	var statusRes BankIdVerificationStatus
	_ = json.NewDecoder(statusW.Body).Decode(&statusRes)
	if !statusRes.BankIdVerified {
		t.Errorf("expected verified status to be true")
	}
}

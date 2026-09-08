package main

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

func generateTestAdminToken() string {
	if len(jwtSecret) == 0 {
		jwtSecret = []byte("local-dev-jwt-secret-key-panta-go-change-in-prod")
	}
	claims := &Claims{
		Role:            "admin",
		CognitoUsername: "Admin Operator",
		DisplayName:     "Admin Operator",
		Email:           "admin@panta.se",
		BankIdVerified:  true,
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(1 * time.Hour)),
			Issuer:    "panta-backend",
		},
	}
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	tokenString, _ := token.SignedString(jwtSecret)
	return tokenString
}

func generateTestUserToken(role string) string {
	if len(jwtSecret) == 0 {
		jwtSecret = []byte("local-dev-jwt-secret-key-panta-go-change-in-prod")
	}
	claims := &Claims{
		Role:            role,
		CognitoUsername: "Test User",
		DisplayName:     "Test User",
		Email:           "user@panta.se",
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(1 * time.Hour)),
			Issuer:    "panta-backend",
		},
	}
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	tokenString, _ := token.SignedString(jwtSecret)
	return tokenString
}

func TestAdminEndpoints(t *testing.T) {
	adminToken := generateTestAdminToken()
	userToken := generateTestUserToken("user")
	helperToken := generateTestUserToken("helper")

	t.Run("GET /api/v1/admin/overview returns market summary and cities", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodGet, "/api/v1/admin/overview", nil)
		req.Header.Set("Authorization", "Bearer "+adminToken)
		w := httptest.NewRecorder()

		authMiddleware(handleAdminOverview)(w, req)

		if w.Code != http.StatusOK {
			t.Fatalf("Expected status 200, got %d: %s", w.Code, w.Body.String())
		}

		var res map[string]interface{}
		if err := json.Unmarshal(w.Body.Bytes(), &res); err != nil {
			t.Fatalf("Failed to parse JSON: %v", err)
		}

		summary, ok := res["summary"].(map[string]interface{})
		if !ok {
			t.Fatalf("Expected summary object, got %v", res["summary"])
		}

		if summary["recyclerLimit"] != float64(20) {
			t.Errorf("Expected recyclerLimit=20, got %v", summary["recyclerLimit"])
		}
		if summary["helperLimit"] != float64(30) {
			t.Errorf("Expected helperLimit=30, got %v", summary["helperLimit"])
		}

		cities, ok := res["cities"].([]interface{})
		if !ok || len(cities) < 4 {
			t.Errorf("Expected at least 4 cities, got %v", cities)
		}
	})

	t.Run("GET /api/v1/admin/logs returns system audit log entries", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodGet, "/api/v1/admin/logs", nil)
		req.Header.Set("Authorization", "Bearer "+adminToken)
		w := httptest.NewRecorder()

		authMiddleware(handleAdminLogs)(w, req)

		if w.Code != http.StatusOK {
			t.Fatalf("Expected status 200, got %d: %s", w.Code, w.Body.String())
		}

		var res map[string]interface{}
		if err := json.Unmarshal(w.Body.Bytes(), &res); err != nil {
			t.Fatalf("Failed to parse JSON: %v", err)
		}

		logs, ok := res["logs"].([]interface{})
		if !ok || len(logs) == 0 {
			t.Errorf("Expected non-empty logs array, got %v", res["logs"])
		}
	})

	t.Run("POST /api/v1/admin/logs/simulate generates real-time market event", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodPost, "/api/v1/admin/logs/simulate", nil)
		req.Header.Set("Authorization", "Bearer "+adminToken)
		w := httptest.NewRecorder()

		authMiddleware(handleAdminSimulateLog)(w, req)

		if w.Code != http.StatusCreated {
			t.Fatalf("Expected status 201, got %d: %s", w.Code, w.Body.String())
		}

		var res map[string]interface{}
		if err := json.Unmarshal(w.Body.Bytes(), &res); err != nil {
			t.Fatalf("Failed to parse JSON: %v", err)
		}

		entry, ok := res["entry"].(map[string]interface{})
		if !ok || entry["id"] == nil || entry["message"] == nil {
			t.Errorf("Expected valid log entry, got %v", res["entry"])
		}
	})

	t.Run("Rejects non-admin tokens with 403 Forbidden", func(t *testing.T) {
		for _, nonAdminToken := range []string{userToken, helperToken} {
			// Overview
			req := httptest.NewRequest(http.MethodGet, "/api/v1/admin/overview", nil)
			req.Header.Set("Authorization", "Bearer "+nonAdminToken)
			w := httptest.NewRecorder()
			authMiddleware(handleAdminOverview)(w, req)
			if w.Code != http.StatusForbidden {
				t.Errorf("Expected 403 Forbidden for overview, got %d", w.Code)
			}

			// Logs
			reqLogs := httptest.NewRequest(http.MethodGet, "/api/v1/admin/logs", nil)
			reqLogs.Header.Set("Authorization", "Bearer "+nonAdminToken)
			wLogs := httptest.NewRecorder()
			authMiddleware(handleAdminLogs)(wLogs, reqLogs)
			if wLogs.Code != http.StatusForbidden {
				t.Errorf("Expected 403 Forbidden for logs, got %d", wLogs.Code)
			}

			// Simulate
			reqSim := httptest.NewRequest(http.MethodPost, "/api/v1/admin/logs/simulate", nil)
			reqSim.Header.Set("Authorization", "Bearer "+nonAdminToken)
			wSim := httptest.NewRecorder()
			authMiddleware(handleAdminSimulateLog)(wSim, reqSim)
			if wSim.Code != http.StatusForbidden {
				t.Errorf("Expected 403 Forbidden for simulate, got %d", wSim.Code)
			}
		}
	})

	t.Run("Rejects unauthenticated requests with 401 Unauthorized", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodGet, "/api/v1/admin/overview", nil)
		w := httptest.NewRecorder()
		authMiddleware(handleAdminOverview)(w, req)
		if w.Code != http.StatusUnauthorized {
			t.Errorf("Expected 401 Unauthorized, got %d", w.Code)
		}
	})
}

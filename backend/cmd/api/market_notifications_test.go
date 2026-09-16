package main

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestMarketNotificationsEndpoints(t *testing.T) {
	mux := http.NewServeMux()
	registerMarketNotificationRoutes(mux)

	adminToken := generateTestAdminToken()
	userToken := generateTestUserToken("user")

	t.Run("GET /api/v1/market/notifications returns default active technical issues notification without auth", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodGet, "/api/v1/market/notifications?market=SE", nil)
		w := httptest.NewRecorder()
		mux.ServeHTTP(w, req)

		if w.Code != http.StatusOK {
			t.Fatalf("Expected 200, got %d. Body: %s", w.Code, w.Body.String())
		}

		var resp MarketNotificationsResponse
		if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
			t.Fatalf("Failed to parse response: %v", err)
		}

		if resp.Market != "SE" {
			t.Errorf("Expected Market SE, got %s", resp.Market)
		}

		if len(resp.Notifications) == 0 {
			t.Fatalf("Expected at least 1 notification, got 0")
		}

		foundTechIssue := false
		for _, n := range resp.Notifications {
			if n.Message == "We are experiencing some technical issues and are looking into it." {
				foundTechIssue = true
				if !n.Active {
					t.Errorf("Expected notification to be active")
				}
				if n.Severity != "warning" {
					t.Errorf("Expected severity warning, got %s", n.Severity)
				}
			}
		}

		if !foundTechIssue {
			t.Errorf("Expected to find default technical issues notification in results")
		}
	})

	t.Run("Market isolation: notifications targeted to specific market are filtered appropriately", func(t *testing.T) {
		// Post a notice specifically for Norway (NO)
		createPayload := map[string]interface{}{
			"market":    "NO",
			"title":     "Norway Maintenance",
			"message":   "Vipps maintenance scheduled in Oslo.",
			"severity":  "info",
			"active":    true,
		}
		body, _ := json.Marshal(createPayload)
		postReq := httptest.NewRequest(http.MethodPost, "/api/v1/admin/market/notifications", bytes.NewReader(body))
		postReq.Header.Set("Authorization", "Bearer "+adminToken)
		postReq.Header.Set("Content-Type", "application/json")
		postW := httptest.NewRecorder()
		mux.ServeHTTP(postW, postReq)

		if postW.Code != http.StatusCreated {
			t.Fatalf("Expected 201 Created, got %d: %s", postW.Code, postW.Body.String())
		}

		// Fetch for Sweden (SE) -> should NOT contain Norway-specific notice
		seReq := httptest.NewRequest(http.MethodGet, "/api/v1/market/notifications?market=SE", nil)
		seW := httptest.NewRecorder()
		mux.ServeHTTP(seW, seReq)

		var seResp MarketNotificationsResponse
		_ = json.Unmarshal(seW.Body.Bytes(), &seResp)
		for _, n := range seResp.Notifications {
			if n.Market == "NO" {
				t.Errorf("Market SE response should not contain market NO notification: %+v", n)
			}
		}

		// Fetch for Norway (NO) -> SHOULD contain Norway-specific notice AND global ALL notices
		noReq := httptest.NewRequest(http.MethodGet, "/api/v1/market/notifications?market=NO", nil)
		noW := httptest.NewRecorder()
		mux.ServeHTTP(noW, noReq)

		var noResp MarketNotificationsResponse
		_ = json.Unmarshal(noW.Body.Bytes(), &noResp)
		foundNO := false
		foundGlobal := false
		for _, n := range noResp.Notifications {
			if n.Market == "NO" {
				foundNO = true
			}
			if n.Market == "ALL" {
				foundGlobal = true
			}
		}

		if !foundNO {
			t.Errorf("Market NO response should contain the NO-targeted notice")
		}
		if !foundGlobal {
			t.Errorf("Market NO response should contain global (ALL) notices")
		}
	})

	t.Run("Admin security: non-admin user cannot manage notifications", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodGet, "/api/v1/admin/market/notifications", nil)
		req.Header.Set("Authorization", "Bearer "+userToken)
		w := httptest.NewRecorder()
		mux.ServeHTTP(w, req)

		if w.Code != http.StatusForbidden {
			t.Errorf("Expected 403 Forbidden for non-admin, got %d", w.Code)
		}
	})

	t.Run("Admin simulate: resets technical issue notification", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodPost, "/api/v1/admin/market/notifications/simulate", nil)
		req.Header.Set("Authorization", "Bearer "+adminToken)
		w := httptest.NewRecorder()
		mux.ServeHTTP(w, req)

		if w.Code != http.StatusOK {
			t.Fatalf("Expected 200 OK from simulate, got %d: %s", w.Code, w.Body.String())
		}

		var simulated MarketNotification
		if err := json.Unmarshal(w.Body.Bytes(), &simulated); err != nil {
			t.Fatalf("Failed to parse simulated notification: %v", err)
		}

		if simulated.Message != "We are experiencing some technical issues and are looking into it." {
			t.Errorf("Unexpected simulated message: %s", simulated.Message)
		}
	})
}

package main

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestHandleCookiePolicy(t *testing.T) {
	mux := http.NewServeMux()
	registerLegalRoutes(mux)

	req := httptest.NewRequest(http.MethodGet, "/api/v1/legal/cookies", nil)
	rr := httptest.NewRecorder()
	mux.ServeHTTP(rr, req)

	if rr.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d: %s", rr.Code, rr.Body.String())
	}

	var resp CookiePolicyResponse
	if err := json.Unmarshal(rr.Body.Bytes(), &resp); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}

	if resp.PolicyVersion != "2026.1" {
		t.Errorf("expected policy version 2026.1, got %s", resp.PolicyVersion)
	}

	if len(resp.Categories) != 4 {
		t.Errorf("expected 4 cookie categories, got %d", len(resp.Categories))
	}

	foundNecessary := false
	for _, cat := range resp.Categories {
		if cat.ID == "necessary" {
			foundNecessary = true
			if !cat.Required {
				t.Errorf("expected necessary category to be required=true")
			}
		}
	}
	if !foundNecessary {
		t.Errorf("necessary category not found in policy response")
	}
}

package main

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"testing"
)

func TestMarketConfigProfiles(t *testing.T) {
	se := getMarketConfig("SE")
	if se.MarketCode != "SE" || se.Currency != "SEK" || se.CurrencySymbol != "kr" || se.MaxActiveRequestsPerRecycler != 10 || se.MaxActiveJobsPerHelper != 15 {
		t.Fatalf("Unexpected SE config: %+v", se)
	}

	no := getMarketConfig("NO")
	if no.MarketCode != "NO" || no.Currency != "NOK" || no.CurrencySymbol != "kr" || no.MaxActiveRequestsPerRecycler != 10 || no.MaxActiveJobsPerHelper != 15 {
		t.Fatalf("Unexpected NO config: %+v", no)
	}

	dk := getMarketConfig("DK")
	if dk.MarketCode != "DK" || dk.Currency != "DKK" || dk.CurrencySymbol != "kr." {
		t.Fatalf("Unexpected DK config: %+v", dk)
	}

	fi := getMarketConfig("FI")
	if fi.MarketCode != "FI" || fi.Currency != "EUR" || fi.CurrencySymbol != "€" {
		t.Fatalf("Unexpected FI config: %+v", fi)
	}

	def := getMarketConfig("XYZ")
	if def.MarketCode != "default" || def.Currency != "SEK" || def.CurrencySymbol != "kr" {
		t.Fatalf("Unexpected default config for unknown market: %+v", def)
	}
}

func TestMarketConfigEnvironmentOverride(t *testing.T) {
	orig := os.Getenv("MAX_ACTIVE_REQUESTS_PER_RECYCLER")
	defer os.Setenv("MAX_ACTIVE_REQUESTS_PER_RECYCLER", orig)

	os.Setenv("MAX_ACTIVE_REQUESTS_PER_RECYCLER", "2")
	cfg := getMarketConfig("SE")
	if cfg.MaxActiveRequestsPerRecycler != 2 {
		t.Fatalf("Expected env override to 2, got %d", cfg.MaxActiveRequestsPerRecycler)
	}
}

func TestMarketConfigHandler(t *testing.T) {
	req := httptest.NewRequest(http.MethodGet, "/api/v1/market/config?market=SE", nil)
	w := httptest.NewRecorder()

	handleMarketConfig(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("Expected status 200, got %d: %s", w.Code, w.Body.String())
	}

	var res map[string]interface{}
	if err := json.Unmarshal(w.Body.Bytes(), &res); err != nil {
		t.Fatalf("Failed to parse JSON response: %v", err)
	}

	if res["canCreate"] != true {
		t.Errorf("Expected canCreate=true when no active requests, got %v", res["canCreate"])
	}
}

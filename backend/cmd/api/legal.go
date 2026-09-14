package main

import (
	"net/http"
)

type CookieCategorySpec struct {
	ID          string   `json:"id"`
	Name        string   `json:"name"`
	Description string   `json:"description"`
	Required    bool     `json:"required"`
	Cookies     []string `json:"cookies"`
	Retention   string   `json:"retention"`
	LegalBasis  string   `json:"legalBasis"`
}

type CookiePolicyResponse struct {
	PolicyVersion string               `json:"policyVersion"`
	LastUpdated   string               `json:"lastUpdated"`
	Jurisdiction  string               `json:"jurisdiction"`
	Authorities   []string             `json:"authorities"`
	Categories    []CookieCategorySpec `json:"categories"`
}

func registerLegalRoutes(mux *http.ServeMux) {
	mux.HandleFunc("/api/v1/legal/cookies", handleCookiePolicy)
}

func handleCookiePolicy(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	resp := CookiePolicyResponse{
		PolicyVersion: "2026.1",
		LastUpdated:   "2026-09-06",
		Jurisdiction:  "Sweden & European Union",
		Authorities: []string{
			"Post- och telestyrelsen (PTS) - Lag (2022:482) om elektronisk kommunikation",
			"Integritetsskyddsmyndigheten (IMY) - General Data Protection Regulation (GDPR 2016/679)",
		},
		Categories: []CookieCategorySpec{
			{
				ID:          "necessary",
				Name:        "Nödvändiga kakor / Strictly Necessary",
				Description: "Essential for authentication tokens, BankID sessions, CSRF prevention, and basic app operation.",
				Required:    true,
				Cookies:     []string{"panta_auth_token", "panta_session", "XSRF-TOKEN"},
				Retention:   "Session / 30 days",
				LegalBasis:  "Legitimate interest & service delivery (GDPR Art. 6(1)(b)/(f), LEK 6 kap 18 §)",
			},
			{
				ID:          "functional",
				Name:        "Funktionella kakor / Functional",
				Description: "Saves client UI state, language selection (sv/en), and layout preferences.",
				Required:    false,
				Cookies:     []string{"app_language_code", "panta_ui_prefs"},
				Retention:   "1 year",
				LegalBasis:  "Freely given consent (GDPR Art. 6(1)(a))",
			},
			{
				ID:          "analytics",
				Name:        "Analyskakor / Performance & Diagnostics",
				Description: "Aggregated, non-identifying telemetry to monitor recycling job completion rates and diagnose crashes.",
				Required:    false,
				Cookies:     []string{"_panta_metrics"},
				Retention:   "90 days",
				LegalBasis:  "Freely given consent (GDPR Art. 6(1)(a))",
			},
			{
				ID:          "marketing",
				Name:        "Marknadsföring / Marketing & Referral",
				Description: "Attribution for community recycling challenges and neighborhood incentive links.",
				Required:    false,
				Cookies:     []string{"_panta_ref"},
				Retention:   "30 days",
				LegalBasis:  "Freely given consent (GDPR Art. 6(1)(a))",
			},
		},
	}

	jsonResponse(w, http.StatusOK, resp)
}

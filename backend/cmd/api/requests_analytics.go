package main

import (
	"log"
	"net/http"
)

func handleAnalytics(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	claims, ok := currentClaims(r)
	if !ok || claims == nil {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}

	requests, err := listRequestsForClaims(r.Context(), claims)
	if err != nil {
		log.Printf("Failed to load requests for analytics: %v", err)
		http.Error(w, "Failed to load analytics", http.StatusInternalServerError)
		return
	}

	summary := CalculateImpact(requests, claims.isHelper())
	jsonResponse(w, http.StatusOK, summary)
}

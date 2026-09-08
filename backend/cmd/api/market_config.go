package main

import (
	"net/http"
	"os"
	"strconv"
	"strings"
)

type MarketConfig struct {
	MarketCode                   string  `json:"marketCode"`
	MarketName                   string  `json:"marketName"`
	Currency                     string  `json:"currency"`
	CurrencySymbol               string  `json:"currencySymbol"`
	MaxActiveRequestsPerRecycler int     `json:"maxActiveRequestsPerRecycler"`
	MaxActiveJobsPerHelper       int     `json:"maxActiveJobsPerHelper"`
	DefaultSplitPercentage       float64 `json:"defaultSplitPercentage"`
	MinReward                    float64 `json:"minReward"`
	MaxReward                    float64 `json:"maxReward"`
}

var marketProfiles = map[string]MarketConfig{
	"SE": {
		MarketCode:                   "SE",
		MarketName:                   "Sweden",
		Currency:                     "SEK",
		CurrencySymbol:               "kr",
		MaxActiveRequestsPerRecycler: 20,
		MaxActiveJobsPerHelper:       30,
		DefaultSplitPercentage:       70.0,
		MinReward:                    10.0,
		MaxReward:                    2000.0,
	},
	"NO": {
		MarketCode:                   "NO",
		MarketName:                   "Norway",
		Currency:                     "NOK",
		CurrencySymbol:               "kr",
		MaxActiveRequestsPerRecycler: 20,
		MaxActiveJobsPerHelper:       30,
		DefaultSplitPercentage:       70.0,
		MinReward:                    15.0,
		MaxReward:                    2500.0,
	},
	"DK": {
		MarketCode:                   "DK",
		MarketName:                   "Denmark",
		Currency:                     "DKK",
		CurrencySymbol:               "kr.",
		MaxActiveRequestsPerRecycler: 20,
		MaxActiveJobsPerHelper:       30,
		DefaultSplitPercentage:       70.0,
		MinReward:                    10.0,
		MaxReward:                    2000.0,
	},
	"FI": {
		MarketCode:                   "FI",
		MarketName:                   "Finland",
		Currency:                     "EUR",
		CurrencySymbol:               "€",
		MaxActiveRequestsPerRecycler: 20,
		MaxActiveJobsPerHelper:       30,
		DefaultSplitPercentage:       70.0,
		MinReward:                    1.0,
		MaxReward:                    200.0,
	},
	"DE": {
		MarketCode:                   "DE",
		MarketName:                   "Germany",
		Currency:                     "EUR",
		CurrencySymbol:               "€",
		MaxActiveRequestsPerRecycler: 20,
		MaxActiveJobsPerHelper:       30,
		DefaultSplitPercentage:       70.0,
		MinReward:                    1.0,
		MaxReward:                    200.0,
	},
	"US": {
		MarketCode:                   "US",
		MarketName:                   "United States",
		Currency:                     "USD",
		CurrencySymbol:               "$",
		MaxActiveRequestsPerRecycler: 20,
		MaxActiveJobsPerHelper:       30,
		DefaultSplitPercentage:       70.0,
		MinReward:                    2.0,
		MaxReward:                    250.0,
	},
	"GB": {
		MarketCode:                   "GB",
		MarketName:                   "United Kingdom",
		Currency:                     "GBP",
		CurrencySymbol:               "£",
		MaxActiveRequestsPerRecycler: 20,
		MaxActiveJobsPerHelper:       30,
		DefaultSplitPercentage:       70.0,
		MinReward:                    1.0,
		MaxReward:                    200.0,
	},
	"default": {
		MarketCode:                   "default",
		MarketName:                   "Global Default",
		Currency:                     "SEK",
		CurrencySymbol:               "kr",
		MaxActiveRequestsPerRecycler: 20,
		MaxActiveJobsPerHelper:       30,
		DefaultSplitPercentage:       70.0,
		MinReward:                    10.0,
		MaxReward:                    2000.0,
	},
}

func getMarketConfig(marketCode string) MarketConfig {
	code := strings.ToUpper(strings.TrimSpace(marketCode))
	cfg, ok := marketProfiles[code]
	if !ok {
		cfg = marketProfiles["default"]
	}

	if envMax := os.Getenv("MAX_ACTIVE_REQUESTS_PER_RECYCLER"); envMax != "" {
		if parsed, err := strconv.Atoi(envMax); err == nil && parsed > 0 {
			cfg.MaxActiveRequestsPerRecycler = parsed
		}
	}
	if envMaxHelper := os.Getenv("MAX_ACTIVE_JOBS_PER_HELPER"); envMaxHelper != "" {
		if parsed, err := strconv.Atoi(envMaxHelper); err == nil && parsed > 0 {
			cfg.MaxActiveJobsPerHelper = parsed
		}
	}
	return cfg
}

func handleMarketConfig(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	claims, _ := currentClaims(r)
	market := strings.TrimSpace(r.URL.Query().Get("market"))
	if market == "" {
		market = "SE"
	}

	config := getMarketConfig(market)

	var activeCount int
	var helperActiveCount int
	if claims != nil {
		if claims.isHelper() {
			helperJobs, err := listHelperAssignedRequests(r.Context(), claims.helperID())
			if err == nil {
				for _, job := range helperJobs {
					if job.Status == "accepted" {
						helperActiveCount++
					}
				}
			}
		} else {
			creatorID := claims.requestOwnerID()
			requests, err := listCreatorRequests(r.Context(), creatorID)
			if err == nil {
				for _, req := range requests {
					if req.Status == "pending" || req.Status == "accepted" {
						activeCount++
					}
				}
			}
		}
	}

	remaining := config.MaxActiveRequestsPerRecycler - activeCount
	if remaining < 0 {
		remaining = 0
	}
	helperRemaining := config.MaxActiveJobsPerHelper - helperActiveCount
	if helperRemaining < 0 {
		helperRemaining = 0
	}

	jsonResponse(w, http.StatusOK, map[string]interface{}{
		"config":            config,
		"activeCount":       activeCount,
		"remaining":         remaining,
		"canCreate":         activeCount < config.MaxActiveRequestsPerRecycler,
		"helperActiveCount": helperActiveCount,
		"helperRemaining":   helperRemaining,
		"canAcceptJob":      helperActiveCount < config.MaxActiveJobsPerHelper,
	})
}

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
	MaxActiveRequestsPerRecycler int     `json:"maxActiveRequestsPerRecycler"`
	DefaultSplitPercentage       float64 `json:"defaultSplitPercentage"`
	MinReward                    float64 `json:"minReward"`
	MaxReward                    float64 `json:"maxReward"`
}

var marketProfiles = map[string]MarketConfig{
	"SE": {
		MarketCode:                   "SE",
		MarketName:                   "Sweden",
		Currency:                     "SEK",
		MaxActiveRequestsPerRecycler: 5,
		DefaultSplitPercentage:       70.0,
		MinReward:                    10.0,
		MaxReward:                    2000.0,
	},
	"NO": {
		MarketCode:                   "NO",
		MarketName:                   "Norway",
		Currency:                     "NOK",
		MaxActiveRequestsPerRecycler: 4,
		DefaultSplitPercentage:       70.0,
		MinReward:                    15.0,
		MaxReward:                    2500.0,
	},
	"DK": {
		MarketCode:                   "DK",
		MarketName:                   "Denmark",
		Currency:                     "DKK",
		MaxActiveRequestsPerRecycler: 4,
		DefaultSplitPercentage:       70.0,
		MinReward:                    10.0,
		MaxReward:                    2000.0,
	},
	"default": {
		MarketCode:                   "default",
		MarketName:                   "Global Default",
		Currency:                     "SEK",
		MaxActiveRequestsPerRecycler: 5,
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
	if claims != nil {
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

	remaining := config.MaxActiveRequestsPerRecycler - activeCount
	if remaining < 0 {
		remaining = 0
	}

	jsonResponse(w, http.StatusOK, map[string]interface{}{
		"config":        config,
		"activeCount":   activeCount,
		"remaining":     remaining,
		"canCreate":     activeCount < config.MaxActiveRequestsPerRecycler,
	})
}

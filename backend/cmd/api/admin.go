package main

import (
	"fmt"
	"math/rand"
	"net/http"
	"strings"
	"sync"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/feature/dynamodb/attributevalue"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb"
)

type AdminSummary struct {
	TotalRequests        int     `json:"totalRequests"`
	ActiveRequests       int     `json:"activeRequests"`
	PendingRequests      int     `json:"pendingRequests"`
	InProgressRequests   int     `json:"inProgressRequests"`
	CompletedRequests    int     `json:"completedRequests"`
	CancelledRequests    int     `json:"cancelledRequests"`
	TotalPantAmount      float64 `json:"totalPantAmount"`
	TotalRecyclerPayout  float64 `json:"totalRecyclerPayout"`
	TotalHelperPayout    float64 `json:"totalHelperPayout"`
	RecyclerLimit        int     `json:"recyclerLimit"`
	HelperLimit          int     `json:"helperLimit"`
	ActiveRecyclersCount int     `json:"activeRecyclersCount"`
	ActiveHelpersCount   int     `json:"activeHelpersCount"`
}

type CityTrend struct {
	CityName          string   `json:"cityName"`
	CountryCode       string   `json:"countryCode"`
	Latitude          float64  `json:"latitude"`
	Longitude         float64  `json:"longitude"`
	ActiveRequests    int      `json:"activeRequests"`
	PendingRequests   int      `json:"pendingRequests"`
	AcceptedRequests  int      `json:"acceptedRequests"`
	CompletedRequests int      `json:"completedRequests"`
	ActiveHelpers     int      `json:"activeHelpers"`
	AvgEtaMinutes     int      `json:"avgEtaMinutes"`
	Status            string   `json:"status"` // "optimal", "high_demand", "helper_shortage"
	Districts         []string `json:"districts"`
}

type AdminLogEntry struct {
	ID        string                 `json:"id"`
	Timestamp string                 `json:"timestamp"`
	Level     string                 `json:"level"`    // "INFO", "WARN", "SUCCESS", "METRIC"
	Category  string                 `json:"category"` // "ANTI_SPAM", "DISPATCH", "PAYOUT", "GEO_HEALTH", "MARKET_LIMIT"
	Message   string                 `json:"message"`
	City      string                 `json:"city"`
	Details   map[string]interface{} `json:"details,omitempty"`
}

var (
	adminLogs   []AdminLogEntry
	adminLogsMu sync.RWMutex
)

func init() {
	initAdminLogs()
}

func initAdminLogs() {
	adminLogsMu.Lock()
	defer adminLogsMu.Unlock()

	now := time.Now().UTC()
	adminLogs = []AdminLogEntry{
		{
			ID:        "log-init-1",
			Timestamp: now.Add(-45 * time.Minute).Format(time.RFC3339),
			Level:     "INFO",
			Category:  "MARKET_LIMIT",
			Message:   "Anti-spam protection rules initialized: Personal Recycler cap 20, Helper cap 30",
			City:      "Sweden (National)",
			Details: map[string]interface{}{
				"recyclerMax": 20,
				"helperMax":   30,
				"mode":        "personal_account_quota",
			},
		},
		{
			ID:        "log-init-2",
			Timestamp: now.Add(-32 * time.Minute).Format(time.RFC3339),
			Level:     "INFO",
			Category:  "GEO_HEALTH",
			Message:   "Node Stockholm operational: 4 active pickups, 5 verified helpers online",
			City:      "Stockholm",
			Details: map[string]interface{}{
				"status":        "optimal",
				"avgEtaMinutes": 11,
			},
		},
		{
			ID:        "log-init-3",
			Timestamp: now.Add(-20 * time.Minute).Format(time.RFC3339),
			Level:     "SUCCESS",
			Category:  "PAYOUT",
			Message:   "Bulk return verified: 185.00 SEK scanned. 129.50 SEK disbursed to Anna, 105.50 SEK to Erik",
			City:      "Stockholm",
			Details: map[string]interface{}{
				"pantAmount": 185.0,
				"split":      "70/30",
			},
		},
		{
			ID:        "log-init-4",
			Timestamp: now.Add(-12 * time.Minute).Format(time.RFC3339),
			Level:     "METRIC",
			Category:  "ANTI_SPAM",
			Message:   "Audit scan: 0 accounts exceeding active market thresholds. Spam score: 0.0%",
			City:      "Sweden (National)",
			Details: map[string]interface{}{
				"checkedAccounts": 24,
				"spamViolations":  0,
			},
		},
		{
			ID:        "log-init-5",
			Timestamp: now.Add(-5 * time.Minute).Format(time.RFC3339),
			Level:     "INFO",
			Category:  "DISPATCH",
			Message:   "Helper Erik accepted job in Götgatan (Stockholm Södermalm), live tracking enabled",
			City:      "Stockholm",
			Details: map[string]interface{}{
				"jobId": "demo-accepted-1",
				"eta":   12,
			},
		},
	}
}

func registerAdminRoutes(mux *http.ServeMux) {
	mux.HandleFunc("/api/v1/admin/overview", authMiddleware(handleAdminOverview))
	mux.HandleFunc("/api/v1/admin/logs", authMiddleware(handleAdminLogs))
	mux.HandleFunc("/api/v1/admin/logs/simulate", authMiddleware(handleAdminSimulateLog))
}

func handleAdminOverview(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	claims, ok := currentClaims(r)
	if !ok || claims == nil {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}
	if !claims.isAdmin() {
		http.Error(w, "Forbidden: admin access required", http.StatusForbidden)
		return
	}

	// Fetch all requests for national market overview
	var allRequests []RecyclingRequest
	if svc != nil && tableName != "" {
		scanOut, err := svc.Scan(r.Context(), &dynamodb.ScanInput{
			TableName: aws.String(tableName),
			Limit:     aws.Int32(200),
		})
		if err == nil && len(scanOut.Items) > 0 {
			_ = attributevalue.UnmarshalListOfMaps(scanOut.Items, &allRequests)
		}
	}
	if len(allRequests) == 0 {
		allRequests = defaultAdminRequests()
	}

	// Calculate summary metrics
	summary := AdminSummary{
		RecyclerLimit: 20,
		HelperLimit:   30,
	}

	recyclerSet := make(map[string]bool)
	helperSet := make(map[string]bool)

	cityMap := map[string]*CityTrend{
		"Stockholm": {
			CityName:      "Stockholm",
			CountryCode:   "SE",
			Latitude:      59.3293,
			Longitude:     18.0686,
			ActiveHelpers: 5,
			AvgEtaMinutes: 11,
			Status:        "optimal",
			Districts:     []string{"Södermalm", "Norrmalm", "Vasastan", "Kungsholmen", "Östermalm"},
		},
		"Göteborg": {
			CityName:      "Göteborg",
			CountryCode:   "SE",
			Latitude:      57.7089,
			Longitude:     11.9746,
			ActiveHelpers: 3,
			AvgEtaMinutes: 14,
			Status:        "optimal",
			Districts:     []string{"Centrum", "Majorna", "Linnéstaden", "Haga", "Hisingen"},
		},
		"Malmö": {
			CityName:      "Malmö",
			CountryCode:   "SE",
			Latitude:      55.6050,
			Longitude:     13.0038,
			ActiveHelpers: 2,
			AvgEtaMinutes: 16,
			Status:        "high_demand",
			Districts:     []string{"Västra Hamnen", "Möllevången", "Slottsstaden", "Limhamn"},
		},
		"Uppsala": {
			CityName:      "Uppsala",
			CountryCode:   "SE",
			Latitude:      59.8586,
			Longitude:     17.6389,
			ActiveHelpers: 2,
			AvgEtaMinutes: 13,
			Status:        "optimal",
			Districts:     []string{"Centrum", "Luthagen", "Fålhagen", "Svartbäcken"},
		},
	}

	for _, req := range allRequests {
		summary.TotalRequests++
		if req.CreatorID != "" {
			recyclerSet[req.CreatorID] = true
		}
		if req.HelperID != "" {
			helperSet[req.HelperID] = true
		}

		cityKey := "Stockholm"
		locLower := strings.ToLower(req.Location)
		if strings.Contains(locLower, "göteborg") || strings.Contains(locLower, "gothenburg") {
			cityKey = "Göteborg"
		} else if strings.Contains(locLower, "malmö") || strings.Contains(locLower, "malmo") {
			cityKey = "Malmö"
		} else if strings.Contains(locLower, "uppsala") {
			cityKey = "Uppsala"
		}

		cTrend := cityMap[cityKey]

		switch req.Status {
		case "pending":
			summary.PendingRequests++
			summary.ActiveRequests++
			if cTrend != nil {
				cTrend.PendingRequests++
				cTrend.ActiveRequests++
			}
		case "accepted":
			summary.InProgressRequests++
			summary.ActiveRequests++
			if cTrend != nil {
				cTrend.AcceptedRequests++
				cTrend.ActiveRequests++
			}
		case "pickedUp":
			summary.CompletedRequests++
			if cTrend != nil {
				cTrend.CompletedRequests++
			}
			if req.ReceiptAmount > 0 {
				summary.TotalPantAmount += req.ReceiptAmount
			}
			if req.RecyclerPayout != nil {
				summary.TotalRecyclerPayout += *req.RecyclerPayout
			}
			if req.HelperPayout != nil {
				summary.TotalHelperPayout += *req.HelperPayout
			}
		case "cancelled":
			summary.CancelledRequests++
		}
	}

	summary.ActiveRecyclersCount = len(recyclerSet)
	summary.ActiveHelpersCount = len(helperSet)
	if summary.ActiveRecyclersCount == 0 {
		summary.ActiveRecyclersCount = 1
	}
	if summary.ActiveHelpersCount == 0 {
		summary.ActiveHelpersCount = 1
	}

	// Update dynamic status per city
	citiesList := make([]CityTrend, 0, len(cityMap))
	for _, c := range []string{"Stockholm", "Göteborg", "Malmö", "Uppsala"} {
		ct := cityMap[c]
		if ct.PendingRequests > ct.ActiveHelpers*2 {
			ct.Status = "helper_shortage"
		} else if ct.ActiveRequests > 4 {
			ct.Status = "high_demand"
		} else {
			ct.Status = "optimal"
		}
		citiesList = append(citiesList, *ct)
	}

	jsonResponse(w, http.StatusOK, map[string]interface{}{
		"summary":   summary,
		"cities":    citiesList,
		"timestamp": time.Now().UTC().Format(time.RFC3339),
	})
}

func handleAdminLogs(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	claims, ok := currentClaims(r)
	if !ok || claims == nil {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}
	if !claims.isAdmin() {
		http.Error(w, "Forbidden: admin access required", http.StatusForbidden)
		return
	}

	adminLogsMu.RLock()
	defer adminLogsMu.RUnlock()

	// Return most recent logs first
	copied := make([]AdminLogEntry, len(adminLogs))
	for i, entry := range adminLogs {
		copied[len(adminLogs)-1-i] = entry
	}

	jsonResponse(w, http.StatusOK, map[string]interface{}{
		"logs":  copied,
		"total": len(copied),
	})
}

func handleAdminSimulateLog(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	claims, ok := currentClaims(r)
	if !ok || claims == nil {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}
	if !claims.isAdmin() {
		http.Error(w, "Forbidden: admin access required", http.StatusForbidden)
		return
	}

	templates := []struct {
		level    string
		category string
		city     string
		format   string
	}{
		{"INFO", "ANTI_SPAM", "Stockholm", "Recycler quota audit: User Anna verified at %d/20 active pickups (anti-spam healthy)"},
		{"INFO", "DISPATCH", "Stockholm", "Proximity match: Helper Erik assigned to pickup near Sveavägen (ETA %d mins)"},
		{"WARN", "GEO_HEALTH", "Malmö", "Elevated pickup demand detected in Malmö Möllevången: %d pending requests queued"},
		{"SUCCESS", "PAYOUT", "Göteborg", "BankID verified receipt processed: %.2f SEK return pant released via Swish"},
		{"METRIC", "MARKET_LIMIT", "Stockholm", "Helper pool capacity check: %d active jobs among 8 registered helpers (within 30 max limit)"},
		{"INFO", "GEO_HEALTH", "Uppsala", "New recycling cluster formed in Uppsala Luthagen: %d pickups available"},
	}

	rnd := rand.New(rand.NewSource(time.Now().UnixNano()))
	t := templates[rnd.Intn(len(templates))]

	var message string
	now := time.Now().UTC()
	switch t.category {
	case "ANTI_SPAM":
		message = fmt.Sprintf(t.format, rnd.Intn(4)+1)
	case "DISPATCH":
		message = fmt.Sprintf(t.format, rnd.Intn(8)+5)
	case "GEO_HEALTH":
		message = fmt.Sprintf(t.format, rnd.Intn(5)+3)
	case "PAYOUT":
		message = fmt.Sprintf(t.format, float64(rnd.Intn(150)+50))
	case "MARKET_LIMIT":
		message = fmt.Sprintf(t.format, rnd.Intn(12)+3)
	}

	newEntry := AdminLogEntry{
		ID:        fmt.Sprintf("log-sim-%d", now.UnixNano()),
		Timestamp: now.Format(time.RFC3339),
		Level:     t.level,
		Category:  t.category,
		Message:   message,
		City:      t.city,
		Details: map[string]interface{}{
			"simulated": true,
			"source":    "real_backend_simulation_engine",
		},
	}

	adminLogsMu.Lock()
	adminLogs = append(adminLogs, newEntry)
	// Cap log storage at 100
	if len(adminLogs) > 100 {
		adminLogs = adminLogs[len(adminLogs)-100:]
	}
	adminLogsMu.Unlock()

	jsonResponse(w, http.StatusCreated, map[string]interface{}{
		"success": true,
		"entry":   newEntry,
		"message": "Simulated real-time log event generated",
	})
}

func defaultAdminRequests() []RecyclingRequest {
	p1, hp1 := 75.0, 25.0
	p2, hp2 := 112.0, 48.0
	return []RecyclingRequest{
		{ID: "req-admin-demo-1", CreatorID: userUUID("anna.recycler@example.com"), CreatorName: "Anna Recycler", Status: "pending", Location: "Stockholm Södermalm", Currency: "SEK", CurrencySymbol: "kr", Market: "SE"},
		{ID: "req-admin-demo-2", CreatorID: userUUID("anna.recycler@example.com"), CreatorName: "Anna Recycler", HelperID: userUUID("erik.helper@example.com"), HelperName: "Erik Helper", Status: "accepted", Location: "Stockholm Norrmalm", Currency: "SEK", CurrencySymbol: "kr", Market: "SE"},
		{ID: "req-admin-demo-3", CreatorID: userUUID("johan.recycler@example.com"), CreatorName: "Johan Recycler", Status: "pending", Location: "Göteborg Centrum", Currency: "SEK", CurrencySymbol: "kr", Market: "SE"},
		{ID: "req-admin-demo-4", CreatorID: userUUID("sara.recycler@example.com"), CreatorName: "Sara Recycler", Status: "pending", Location: "Malmö Västra Hamnen", Currency: "SEK", CurrencySymbol: "kr", Market: "SE"},
		{ID: "req-admin-demo-5", CreatorID: userUUID("karin.recycler@example.com"), CreatorName: "Karin Recycler", HelperID: userUUID("erik.helper@example.com"), HelperName: "Erik Helper", Status: "pickedUp", Location: "Stockholm Vasastan", ReceiptAmount: 100.0, RecyclerPayout: &p1, HelperPayout: &hp1, Currency: "SEK", CurrencySymbol: "kr", Market: "SE"},
		{ID: "req-admin-demo-6", CreatorID: userUUID("lars.recycler@example.com"), CreatorName: "Lars Recycler", HelperID: userUUID("oskar.helper@example.com"), HelperName: "Oskar Helper", Status: "pickedUp", Location: "Uppsala Centrum", ReceiptAmount: 160.0, RecyclerPayout: &p2, HelperPayout: &hp2, Currency: "SEK", CurrencySymbol: "kr", Market: "SE"},
	}
}


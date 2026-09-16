package main

import (
	"encoding/json"
	"net/http"
	"strings"
	"sync"
	"time"

	"github.com/google/uuid"
)

// MarketNotification represents an in-app or web service announcement,
// technical outage warning, or operational update targeted per market or globally.
type MarketNotification struct {
	ID          string    `json:"id" dynamodbav:"id"`
	Market      string    `json:"market" dynamodbav:"market"` // e.g. "ALL", "SE", "NO", "DK", "FI", "DE", "US", "GB"
	Title       string    `json:"title" dynamodbav:"title"`
	TitleSv     string    `json:"titleSv,omitempty" dynamodbav:"titleSv,omitempty"`
	Message     string    `json:"message" dynamodbav:"message"`
	MessageSv   string    `json:"messageSv,omitempty" dynamodbav:"messageSv,omitempty"`
	Severity    string    `json:"severity" dynamodbav:"severity"` // "info", "warning", "critical", "incident"
	Active      bool      `json:"active" dynamodbav:"active"`
	Dismissible bool      `json:"dismissible" dynamodbav:"dismissible"`
	ActionURL   string    `json:"actionUrl,omitempty" dynamodbav:"actionUrl,omitempty"`
	ActionLabel string    `json:"actionLabel,omitempty" dynamodbav:"actionLabel,omitempty"`
	CreatedAt   time.Time `json:"createdAt" dynamodbav:"createdAt"`
	UpdatedAt   time.Time `json:"updatedAt" dynamodbav:"updatedAt"`
}

type MarketNotificationsResponse struct {
	Market        string               `json:"market"`
	Notifications []MarketNotification `json:"notifications"`
}

var (
	marketNotifications   []MarketNotification
	marketNotificationsMu sync.RWMutex
)

func init() {
	initMarketNotifications()
}

func initMarketNotifications() {
	marketNotificationsMu.Lock()
	defer marketNotificationsMu.Unlock()

	now := time.Now().UTC()
	marketNotifications = []MarketNotification{
		{
			ID:          "market-notice-tech-issue-1",
			Market:      "ALL",
			Title:       "Technical Issues",
			TitleSv:     "Tekniska problem",
			Message:     "We are experiencing some technical issues and are looking into it.",
			MessageSv:   "Vi upplever för närvarande vissa tekniska problem och undersöker saken.",
			Severity:    "warning",
			Active:      true,
			Dismissible: true,
			CreatedAt:   now.Add(-15 * time.Minute),
			UpdatedAt:   now,
		},
	}
}

func registerMarketNotificationRoutes(mux *http.ServeMux) {
	mux.HandleFunc("/api/v1/market/notifications", handleMarketNotifications)
	mux.HandleFunc("/api/v1/admin/market/notifications", authMiddleware(handleAdminMarketNotifications))
	mux.HandleFunc("/api/v1/admin/market/notifications/simulate", authMiddleware(handleAdminSimulateMarketNotification))
}

// handleMarketNotifications handles normal client fetch for active notifications.
// It is a public endpoint so unauthenticated visitors (e.g. on web or login screen)
// can be informed of technical issues before logging in, as well as authenticated users.
func handleMarketNotifications(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	requestedMarket := strings.TrimSpace(r.URL.Query().Get("market"))
	if requestedMarket == "" {
		requestedMarket = "SE"
	}
	targetMarket := strings.ToUpper(requestedMarket)

	marketNotificationsMu.RLock()
	defer marketNotificationsMu.RUnlock()

	result := make([]MarketNotification, 0)
	for _, n := range marketNotifications {
		if !n.Active {
			continue
		}
		// Match notifications targeted to this specific market OR global notifications (ALL / *)
		notifMarket := strings.ToUpper(strings.TrimSpace(n.Market))
		if notifMarket == "ALL" || notifMarket == "*" || notifMarket == targetMarket {
			result = append(result, n)
		}
	}

	jsonResponse(w, http.StatusOK, MarketNotificationsResponse{
		Market:        targetMarket,
		Notifications: result,
	})
}

// handleAdminMarketNotifications allows administrators to list all notifications or broadcast new ones.
func handleAdminMarketNotifications(w http.ResponseWriter, r *http.Request) {
	claims, ok := currentClaims(r)
	if !ok || claims == nil {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}
	if !claims.isAdmin() {
		http.Error(w, "Forbidden: admin access required", http.StatusForbidden)
		return
	}

	switch r.Method {
	case http.MethodGet:
		marketNotificationsMu.RLock()
		defer marketNotificationsMu.RUnlock()
		jsonResponse(w, http.StatusOK, marketNotifications)

	case http.MethodPost:
		var req struct {
			Market      string `json:"market"`
			Title       string `json:"title"`
			TitleSv     string `json:"titleSv"`
			Message     string `json:"message"`
			MessageSv   string `json:"messageSv"`
			Severity    string `json:"severity"`
			Active      *bool  `json:"active"`
			Dismissible *bool  `json:"dismissible"`
			ActionURL   string `json:"actionUrl"`
			ActionLabel string `json:"actionLabel"`
		}

		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			http.Error(w, "Invalid JSON payload", http.StatusBadRequest)
			return
		}

		if strings.TrimSpace(req.Message) == "" {
			http.Error(w, "Message is required", http.StatusBadRequest)
			return
		}

		market := strings.ToUpper(strings.TrimSpace(req.Market))
		if market == "" {
			market = "ALL"
		}

		title := strings.TrimSpace(req.Title)
		if title == "" {
			title = "Service Notice"
		}

		severity := strings.ToLower(strings.TrimSpace(req.Severity))
		if severity == "" {
			severity = "warning"
		}

		isActive := true
		if req.Active != nil {
			isActive = *req.Active
		}

		isDismissible := true
		if req.Dismissible != nil {
			isDismissible = *req.Dismissible
		}

		now := time.Now().UTC()
		notif := MarketNotification{
			ID:          "market-notice-" + uuid.New().String()[:8],
			Market:      market,
			Title:       title,
			TitleSv:     strings.TrimSpace(req.TitleSv),
			Message:     strings.TrimSpace(req.Message),
			MessageSv:   strings.TrimSpace(req.MessageSv),
			Severity:    severity,
			Active:      isActive,
			Dismissible: isDismissible,
			ActionURL:   strings.TrimSpace(req.ActionURL),
			ActionLabel: strings.TrimSpace(req.ActionLabel),
			CreatedAt:   now,
			UpdatedAt:   now,
		}

		marketNotificationsMu.Lock()
		marketNotifications = append([]MarketNotification{notif}, marketNotifications...)
		marketNotificationsMu.Unlock()

		jsonResponse(w, http.StatusCreated, notif)

	case http.MethodPut:
		var req struct {
			ID     string `json:"id"`
			Active bool   `json:"active"`
		}
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			http.Error(w, "Invalid JSON payload", http.StatusBadRequest)
			return
		}

		marketNotificationsMu.Lock()
		defer marketNotificationsMu.Unlock()

		found := false
		var updated MarketNotification
		for i, n := range marketNotifications {
			if n.ID == req.ID {
				marketNotifications[i].Active = req.Active
				marketNotifications[i].UpdatedAt = time.Now().UTC()
				updated = marketNotifications[i]
				found = true
				break
			}
		}

		if !found {
			http.Error(w, "Notification not found", http.StatusNotFound)
			return
		}

		jsonResponse(w, http.StatusOK, updated)

	default:
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
	}
}

// handleAdminSimulateMarketNotification resets or activates the default technical issues notification.
func handleAdminSimulateMarketNotification(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	claims, ok := currentClaims(r)
	if !ok || claims == nil || !claims.isAdmin() {
		http.Error(w, "Forbidden: admin access required", http.StatusForbidden)
		return
	}

	marketNotificationsMu.Lock()
	defer marketNotificationsMu.Unlock()

	now := time.Now().UTC()
	simulated := MarketNotification{
		ID:          "market-notice-tech-issue-" + uuid.New().String()[:6],
		Market:      "ALL",
		Title:       "Technical Issues",
		TitleSv:     "Tekniska problem",
		Message:     "We are experiencing some technical issues and are looking into it.",
		MessageSv:   "Vi upplever för närvarande vissa tekniska problem och undersöker saken.",
		Severity:    "warning",
		Active:      true,
		Dismissible: true,
		CreatedAt:   now,
		UpdatedAt:   now,
	}

	marketNotifications = append([]MarketNotification{simulated}, marketNotifications...)
	jsonResponse(w, http.StatusOK, simulated)
}

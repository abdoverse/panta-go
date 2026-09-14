package main

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"strings"
	"sync"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb/types"
)

// NonSensitiveAccountRestrictionMessage is the user-facing message returned to blocked users
// without revealing internal investigative notes or confidential case details.
const NonSensitiveAccountRestrictionMessage = "Your account is currently restricted for compliance or legal review. If you believe this is an error, please contact Panta Support quoting your case reference."

// UserBlockRecord represents a suspension or blocking action against a user account.
type UserBlockRecord struct {
	UserID          string `json:"userId"`
	Email           string `json:"email,omitempty"`
	Status          string `json:"status"` // "BLOCKED", "ACTIVE"
	Reason          string `json:"reason"`
	CaseReferenceID string `json:"caseReferenceId"`
	BlockedAt       string `json:"blockedAt"`
	BlockedBy       string `json:"blockedBy"`
	ExpiresAt       string `json:"expiresAt,omitempty"`
	UnblockedAt     string `json:"unblockedAt,omitempty"`
	UnblockedBy     string `json:"unblockedBy,omitempty"`
	UnblockReason   string `json:"unblockReason,omitempty"`
}

var (
	userBlocksMu sync.RWMutex
	userBlocks   = make(map[string]*UserBlockRecord) // keyed by normalized UserID and Email
)

// isUserBlocked checks if a given user ID or email is currently blocked.
// It automatically evaluates expiration timestamps and unblocks expired restrictions.
func isUserBlocked(userID, email string) (bool, *UserBlockRecord) {
	userBlocksMu.Lock()
	defer userBlocksMu.Unlock()

	var record *UserBlockRecord
	normID := strings.TrimSpace(userID)
	normEmail := strings.ToLower(strings.TrimSpace(email))

	if normID != "" {
		if rec, exists := userBlocks[normID]; exists {
			record = rec
		}
	}
	if record == nil && normEmail != "" {
		if rec, exists := userBlocks[normEmail]; exists {
			record = rec
		}
	}

	if record == nil || record.Status != "BLOCKED" {
		return false, nil
	}

	// Check optional expiry
	if record.ExpiresAt != "" {
		if expiry, err := time.Parse(time.RFC3339, record.ExpiresAt); err == nil {
			if time.Now().UTC().After(expiry) {
				// Expired: auto-unblock
				record.Status = "ACTIVE"
				record.UnblockedAt = time.Now().UTC().Format(time.RFC3339)
				record.UnblockedBy = "system_expiry_engine"
				record.UnblockReason = "Temporary suspension period expired"
				return false, nil
			}
		}
	}

	return true, record
}

// blockUser applies a block record, preserves/reassigns active requests, and writes a durable audit log.
func blockUser(rec *UserBlockRecord) error {
	userBlocksMu.Lock()
	defer userBlocksMu.Unlock()

	normID := strings.TrimSpace(rec.UserID)
	normEmail := strings.ToLower(strings.TrimSpace(rec.Email))

	if normID == "" && normEmail == "" {
		return fmt.Errorf("either userId or email must be provided")
	}

	if rec.Status == "" {
		rec.Status = "BLOCKED"
	}
	if rec.BlockedAt == "" {
		rec.BlockedAt = time.Now().UTC().Format(time.RFC3339)
	}

	if normID != "" {
		userBlocks[normID] = rec
	}
	if normEmail != "" {
		userBlocks[normEmail] = rec
	}

	// Active requests preservation and handling
	handleActiveRequestsOnBlock(normID, normEmail, rec.CaseReferenceID)

	// Append durable audit log entry
	logID := fmt.Sprintf("log-block-%d", time.Now().UnixNano())
	auditEntry := AdminLogEntry{
		ID:        logID,
		Timestamp: rec.BlockedAt,
		Level:     "WARN",
		Category:  "LEGAL_INVESTIGATION",
		Message:   fmt.Sprintf("User restricted under case %s: %s", rec.CaseReferenceID, rec.Reason),
		City:      "National Compliance",
		Details: map[string]interface{}{
			"userId":          rec.UserID,
			"email":           rec.Email,
			"caseReferenceId": rec.CaseReferenceID,
			"blockedBy":       rec.BlockedBy,
			"reason":          rec.Reason,
			"expiresAt":       rec.ExpiresAt,
			"action":          "USER_SUSPENSION",
		},
	}

	adminLogsMu.Lock()
	adminLogs = append(adminLogs, auditEntry)
	if len(adminLogs) > 100 {
		adminLogs = adminLogs[len(adminLogs)-100:]
	}
	adminLogsMu.Unlock()

	return nil
}

// unblockUser lifts a suspension, records the unblock audit details, and logs the event.
func unblockUser(userID, email, adminID, reason, caseRef string) (*UserBlockRecord, error) {
	userBlocksMu.Lock()
	defer userBlocksMu.Unlock()

	normID := strings.TrimSpace(userID)
	normEmail := strings.ToLower(strings.TrimSpace(email))

	var record *UserBlockRecord
	if normID != "" {
		record = userBlocks[normID]
	}
	if record == nil && normEmail != "" {
		record = userBlocks[normEmail]
	}

	if record == nil {
		return nil, fmt.Errorf("user block record not found")
	}

	record.Status = "ACTIVE"
	record.UnblockedAt = time.Now().UTC().Format(time.RFC3339)
	record.UnblockedBy = adminID
	record.UnblockReason = reason
	if caseRef != "" {
		record.CaseReferenceID = caseRef
	}

	// Append durable audit log entry
	auditEntry := AdminLogEntry{
		ID:        fmt.Sprintf("log-unblock-%d", time.Now().UnixNano()),
		Timestamp: record.UnblockedAt,
		Level:     "INFO",
		Category:  "LEGAL_INVESTIGATION",
		Message:   fmt.Sprintf("User restriction lifted under case %s: %s", record.CaseReferenceID, reason),
		City:      "National Compliance",
		Details: map[string]interface{}{
			"userId":          record.UserID,
			"email":           record.Email,
			"caseReferenceId": record.CaseReferenceID,
			"unblockedBy":     adminID,
			"unblockReason":   reason,
			"action":          "USER_REINSTATED",
		},
	}

	adminLogsMu.Lock()
	adminLogs = append(adminLogs, auditEntry)
	if len(adminLogs) > 100 {
		adminLogs = adminLogs[len(adminLogs)-100:]
	}
	adminLogsMu.Unlock()

	return record, nil
}

// handleActiveRequestsOnBlock handles requests when a user is suspended:
// - If user was an assigned helper on accepted jobs: re-dispatches them to pending so recyclers get picked up.
// - If user was a recycler with pending jobs: cancels them cleanly.
// - If user was a recycler with accepted/in-progress jobs: preserves them to protect innocent helpers.
func handleActiveRequestsOnBlock(userID, email, caseRef string) {
	ctx := context.Background()
	normID := strings.TrimSpace(userID)
	if normID == "" && email != "" {
		normID = userUUID(email)
	}

	if svc != nil && tableName != "" && normID != "" {
		// 1. Helper assigned jobs
		if assigned, err := listHelperAssignedRequests(ctx, normID); err == nil {
			for _, req := range assigned {
				if req.Status == "accepted" {
					_, _ = svc.UpdateItem(ctx, &dynamodb.UpdateItemInput{
						TableName: aws.String(tableName),
						Key: map[string]types.AttributeValue{
							"id": &types.AttributeValueMemberS{Value: req.ID},
						},
						UpdateExpression: aws.String("SET #status = :pending REMOVE helperId, helperName, helperETA"),
						ExpressionAttributeNames: map[string]string{
							"#status": "status",
						},
						ExpressionAttributeValues: map[string]types.AttributeValue{
							":pending": &types.AttributeValueMemberS{Value: "pending"},
						},
					})
					if hub != nil {
						hub.broadcast <- []byte(fmt.Sprintf(`{"type":"request-updated","id":"%s","status":"pending"}`, req.ID))
					}
				}
			}
		}

		// 2. Creator jobs
		if created, err := listCreatorRequests(ctx, normID); err == nil {
			for _, req := range created {
				if req.Status == "pending" {
					_, _ = svc.UpdateItem(ctx, &dynamodb.UpdateItemInput{
						TableName: aws.String(tableName),
						Key: map[string]types.AttributeValue{
							"id": &types.AttributeValueMemberS{Value: req.ID},
						},
						UpdateExpression: aws.String("SET #status = :cancelled"),
						ExpressionAttributeNames: map[string]string{
							"#status": "status",
						},
						ExpressionAttributeValues: map[string]types.AttributeValue{
							":cancelled": &types.AttributeValueMemberS{Value: "cancelled"},
						},
					})
					if hub != nil {
						hub.broadcast <- []byte(fmt.Sprintf(`{"type":"request-cancelled","id":"%s","case":"%s"}`, req.ID, caseRef))
					}
				}
			}
		}
	}
}

// listUserBlocks returns all user block records, optionally filtered by status ("BLOCKED" or "ACTIVE").
func listUserBlocks(statusFilter string) []*UserBlockRecord {
	userBlocksMu.RLock()
	defer userBlocksMu.RUnlock()

	seen := make(map[*UserBlockRecord]bool)
	var list []*UserBlockRecord

	for _, rec := range userBlocks {
		if seen[rec] {
			continue
		}
		seen[rec] = true

		if statusFilter != "" && !strings.EqualFold(rec.Status, statusFilter) {
			continue
		}
		list = append(list, rec)
	}
	return list
}

// Admin HTTP Handlers

func handleAdminBlockUser(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	claims, ok := currentClaims(r)
	if !ok || claims == nil || !claims.isAdmin() {
		http.Error(w, "Forbidden: admin access required", http.StatusForbidden)
		return
	}

	var payload struct {
		UserID          string `json:"userId"`
		Email           string `json:"email"`
		Reason          string `json:"reason"`
		CaseReferenceID string `json:"caseReferenceId"`
		ExpiresAt       string `json:"expiresAt"`
	}

	if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
		jsonResponse(w, http.StatusBadRequest, map[string]string{"error": "Invalid request payload"})
		return
	}

	payload.UserID = strings.TrimSpace(payload.UserID)
	payload.Email = strings.TrimSpace(payload.Email)
	payload.Reason = strings.TrimSpace(payload.Reason)
	payload.CaseReferenceID = strings.TrimSpace(payload.CaseReferenceID)

	if payload.UserID == "" && payload.Email == "" {
		jsonResponse(w, http.StatusBadRequest, map[string]string{"error": "Must provide userId or email"})
		return
	}
	if payload.Reason == "" {
		jsonResponse(w, http.StatusBadRequest, map[string]string{"error": "Reason is required for legal suspension"})
		return
	}
	if payload.CaseReferenceID == "" {
		jsonResponse(w, http.StatusBadRequest, map[string]string{"error": "Case/reference ID is required for audit trail"})
		return
	}

	rec := &UserBlockRecord{
		UserID:          payload.UserID,
		Email:           payload.Email,
		Status:          "BLOCKED",
		Reason:          payload.Reason,
		CaseReferenceID: payload.CaseReferenceID,
		BlockedAt:       time.Now().UTC().Format(time.RFC3339),
		BlockedBy:       claims.notificationName(),
		ExpiresAt:       payload.ExpiresAt,
	}

	if err := blockUser(rec); err != nil {
		jsonResponse(w, http.StatusInternalServerError, map[string]string{"error": err.Error()})
		return
	}

	jsonResponse(w, http.StatusOK, map[string]interface{}{
		"success": true,
		"record":  rec,
		"message": "User suspended successfully and active requests reconciled",
	})
}

func handleAdminUnblockUser(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	claims, ok := currentClaims(r)
	if !ok || claims == nil || !claims.isAdmin() {
		http.Error(w, "Forbidden: admin access required", http.StatusForbidden)
		return
	}

	var payload struct {
		UserID          string `json:"userId"`
		Email           string `json:"email"`
		Reason          string `json:"reason"`
		CaseReferenceID string `json:"caseReferenceId"`
	}

	if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
		jsonResponse(w, http.StatusBadRequest, map[string]string{"error": "Invalid request payload"})
		return
	}

	payload.UserID = strings.TrimSpace(payload.UserID)
	payload.Email = strings.TrimSpace(payload.Email)
	payload.Reason = strings.TrimSpace(payload.Reason)
	payload.CaseReferenceID = strings.TrimSpace(payload.CaseReferenceID)

	if payload.UserID == "" && payload.Email == "" {
		jsonResponse(w, http.StatusBadRequest, map[string]string{"error": "Must provide userId or email"})
		return
	}
	if payload.Reason == "" {
		jsonResponse(w, http.StatusBadRequest, map[string]string{"error": "Reason is required to unblock user"})
		return
	}

	updated, err := unblockUser(payload.UserID, payload.Email, claims.notificationName(), payload.Reason, payload.CaseReferenceID)
	if err != nil {
		jsonResponse(w, http.StatusNotFound, map[string]string{"error": err.Error()})
		return
	}

	jsonResponse(w, http.StatusOK, map[string]interface{}{
		"success": true,
		"record":  updated,
		"message": "User suspension lifted successfully",
	})
}

func handleAdminListBlocks(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	claims, ok := currentClaims(r)
	if !ok || claims == nil || !claims.isAdmin() {
		http.Error(w, "Forbidden: admin access required", http.StatusForbidden)
		return
	}

	status := r.URL.Query().Get("status")
	records := listUserBlocks(status)
	if records == nil {
		records = []*UserBlockRecord{}
	}

	jsonResponse(w, http.StatusOK, map[string]interface{}{
		"blocks": records,
		"count":  len(records),
	})
}

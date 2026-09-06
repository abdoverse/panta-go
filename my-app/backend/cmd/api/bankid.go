package main

import (
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"regexp"
	"strings"
	"sync"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

type bankIdSession struct {
	OrderRef       string    `json:"orderRef"`
	AutoStartToken string    `json:"autoStartToken"`
	QrCode         string    `json:"qrCode"`
	PersonalNumber string    `json:"personalNumber"`
	Role           string    `json:"role"`
	DisplayName    string    `json:"displayName"`
	CreatedAt      time.Time `json:"createdAt"`
	PollCount      int       `json:"pollCount"`
	Verified       bool      `json:"verified"`
	CompletedAt    time.Time `json:"completedAt"`
}

type BankIdVerifiedUser struct {
	Username       string    `json:"username"`
	PersonalNumber string    `json:"personalNumber"`
	VerifiedAt     time.Time `json:"verifiedAt"`
	DisplayName    string    `json:"displayName"`
	Role           string    `json:"role"`
}

var (
	bankIdOrdersLock sync.RWMutex
	bankIdOrders     = make(map[string]*bankIdSession)

	verifiedUsersLock sync.RWMutex
	verifiedUsers     = make(map[string]*BankIdVerifiedUser)
)

func registerBankIdRoutes(mux *http.ServeMux) {
	mux.HandleFunc("/api/v1/auth/bankid/initiate", handleBankIdInitiate)
	mux.HandleFunc("/api/v1/auth/bankid/collect", handleBankIdCollect)
	mux.HandleFunc("/api/v1/users/verify-bankid", authMiddleware(handleVerifyBankId))
	mux.HandleFunc("/api/v1/users/verification-status", authMiddleware(handleGetVerificationStatus))
}

func generateRandomToken(bytesLen int) string {
	b := make([]byte, bytesLen)
	if _, err := rand.Read(b); err != nil {
		return fmt.Sprintf("%d", time.Now().UnixNano())
	}
	return hex.EncodeToString(b)
}

func maskPersonalNumber(raw string) string {
	clean := regexp.MustCompile(`\D`).ReplaceAllString(raw, "")
	if len(clean) >= 12 {
		return clean[:8] + "-****"
	}
	if len(clean) >= 10 {
		return "19" + clean[:6] + "-****"
	}
	return "19900101-****"
}

func isUserBankIdVerified(userID string) bool {
	normalized := strings.TrimSpace(userID)
	if normalized == "" {
		return false
	}
	verifiedUsersLock.RLock()
	defer verifiedUsersLock.RUnlock()
	_, ok := verifiedUsers[normalized]
	return ok
}

func getVerifiedUser(userID string) (*BankIdVerifiedUser, bool) {
	normalized := strings.TrimSpace(userID)
	if normalized == "" {
		return nil, false
	}
	verifiedUsersLock.RLock()
	defer verifiedUsersLock.RUnlock()
	user, ok := verifiedUsers[normalized]
	return user, ok
}

func markUserBankIdVerified(userID, personalNumber, displayName, role string) *BankIdVerifiedUser {
	normalized := strings.TrimSpace(userID)
	if normalized == "" {
		normalized = displayName
	}
	verifiedUsersLock.Lock()
	defer verifiedUsersLock.Unlock()

	user := &BankIdVerifiedUser{
		Username:       normalized,
		PersonalNumber: maskPersonalNumber(personalNumber),
		VerifiedAt:     time.Now().UTC(),
		DisplayName:    displayName,
		Role:           role,
	}
	verifiedUsers[normalized] = user
	if displayName != "" && displayName != normalized {
		verifiedUsers[displayName] = user
	}
	return user
}

func generateBankIdToken(role, username, displayName, personalNumber string, verifiedAt time.Time) (string, error) {
	expirationTime := time.Now().Add(24 * time.Hour)
	uID := userUUID(username)
	claims := &Claims{
		Role:                 role,
		CognitoUsername:      username,
		DisplayName:          displayName,
		UserID:               uID,
		BankIdVerified:       true,
		BankIdPersonalNumber: maskPersonalNumber(personalNumber),
		BankIdVerifiedAt:     verifiedAt.Format(time.RFC3339),
		RegisteredClaims: jwt.RegisteredClaims{
			Subject:   uID,
			ExpiresAt: jwt.NewNumericDate(expirationTime),
			Issuer:    "panta-backend",
		},
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString(jwtSecret)
}

func handleBankIdInitiate(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var req BankIdInitiateRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil && err.Error() != "EOF" {
		jsonResponse(w, http.StatusBadRequest, map[string]string{"error": "Invalid payload"})
		return
	}

	role := strings.ToLower(strings.TrimSpace(req.Role))
	if role != "helper" && role != "user" {
		role = "user"
	}

	orderRef := generateRandomToken(16)
	autoStartToken := generateRandomToken(16)
	qrCode := fmt.Sprintf("bankid.%s.%d", autoStartToken, time.Now().Unix())

	displayName := strings.TrimSpace(req.DisplayName)
	if displayName == "" {
		if req.PersonalNumber != "" {
			displayName = "BankID " + maskPersonalNumber(req.PersonalNumber)
		} else {
			displayName = "BankID User"
		}
	}

	session := &bankIdSession{
		OrderRef:       orderRef,
		AutoStartToken: autoStartToken,
		QrCode:         qrCode,
		PersonalNumber: req.PersonalNumber,
		Role:           role,
		DisplayName:    displayName,
		CreatedAt:      time.Now().UTC(),
		PollCount:      0,
		Verified:       false,
	}

	bankIdOrdersLock.Lock()
	bankIdOrders[orderRef] = session
	bankIdOrdersLock.Unlock()

	jsonResponse(w, http.StatusOK, BankIdInitiateResponse{
		OrderRef:       orderRef,
		AutoStartToken: autoStartToken,
		QrCode:         qrCode,
		Status:         "pending",
	})
}

func handleBankIdCollect(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var req BankIdCollectRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		jsonResponse(w, http.StatusBadRequest, map[string]string{"error": "Invalid payload"})
		return
	}

	bankIdOrdersLock.Lock()
	session, exists := bankIdOrders[req.OrderRef]
	if !exists {
		bankIdOrdersLock.Unlock()
		jsonResponse(w, http.StatusNotFound, map[string]string{"error": "Order not found or expired"})
		return
	}

	session.PollCount++

	// Simulate realistic BankID handshake lifecycle
	// Poll 1: outstandingTransaction (waiting for BankID app launch)
	// Poll 2: userSign (user is signing with code / biometric)
	// Poll 3+: complete (or after 1.5 seconds)
	elapsed := time.Since(session.CreatedAt)
	isComplete := session.Verified || session.PollCount >= 3 || elapsed >= 1500*time.Millisecond

	if !isComplete {
		hintCode := "outstandingTransaction"
		if session.PollCount >= 2 {
			hintCode = "userSign"
		}
		bankIdOrdersLock.Unlock()
		jsonResponse(w, http.StatusOK, BankIdCollectResponse{
			OrderRef: req.OrderRef,
			Status:   "pending",
			HintCode: hintCode,
		})
		return
	}

	if !session.Verified {
		session.Verified = true
		session.CompletedAt = time.Now().UTC()
	}
	bankIdOrdersLock.Unlock()

	maskedPN := maskPersonalNumber(session.PersonalNumber)
	username := session.DisplayName
	if username == "" {
		username = "bankid_" + session.OrderRef[:8]
	}

	// Register verified user
	markUserBankIdVerified(username, session.PersonalNumber, session.DisplayName, session.Role)

	// Issue JWT with BankID verification
	tokenString, err := generateBankIdToken(session.Role, username, session.DisplayName, session.PersonalNumber, session.CompletedAt)
	if err != nil {
		log.Printf("Failed to generate token for BankID collect: %v", err)
		jsonResponse(w, http.StatusInternalServerError, map[string]string{"error": "Could not generate token"})
		return
	}

	jsonResponse(w, http.StatusOK, BankIdCollectResponse{
		OrderRef:             req.OrderRef,
		Status:               "complete",
		HintCode:             "complete",
		Token:                tokenString,
		PersonalNumber:       maskedPN,
		Name:                 session.DisplayName,
		BankIdVerified:       true,
		BankIdVerifiedAt:     session.CompletedAt.Format(time.RFC3339),
	})
}

func handleVerifyBankId(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	claims, ok := currentClaims(r)
	if !ok {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}

	var payload struct {
		OrderRef       string `json:"orderRef,omitempty"`
		PersonalNumber string `json:"personalNumber,omitempty"`
	}
	_ = json.NewDecoder(r.Body).Decode(&payload)

	pn := payload.PersonalNumber
	if pn == "" && payload.OrderRef != "" {
		bankIdOrdersLock.RLock()
		if sess, exists := bankIdOrders[payload.OrderRef]; exists {
			pn = sess.PersonalNumber
		}
		bankIdOrdersLock.RUnlock()
	}
	if pn == "" {
		pn = "199001011234"
	}

	verifiedUser := markUserBankIdVerified(claims.requestOwnerID(), pn, claims.DisplayName, claims.Role)

	refreshedToken, err := generateBankIdToken(claims.Role, claims.requestOwnerID(), claims.DisplayName, pn, verifiedUser.VerifiedAt)
	if err != nil {
		log.Printf("Failed to generate token in verify-bankid: %v", err)
		jsonResponse(w, http.StatusInternalServerError, map[string]string{"error": "Could not generate refreshed token"})
		return
	}

	jsonResponse(w, http.StatusOK, map[string]interface{}{
		"status":               "success",
		"token":                refreshedToken,
		"bankIdVerified":       true,
		"bankIdPersonalNumber": verifiedUser.PersonalNumber,
		"bankIdVerifiedAt":     verifiedUser.VerifiedAt.Format(time.RFC3339),
		"displayName":          claims.DisplayName,
		"role":                 claims.Role,
	})
}

func handleGetVerificationStatus(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	claims, ok := currentClaims(r)
	if !ok {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}

	ownerID := claims.requestOwnerID()
	verifiedUser, exists := getVerifiedUser(ownerID)
	isVerified := claims.BankIdVerified || exists
	personalNumber := claims.BankIdPersonalNumber
	verifiedAt := claims.BankIdVerifiedAt

	if exists {
		personalNumber = verifiedUser.PersonalNumber
		verifiedAt = verifiedUser.VerifiedAt.Format(time.RFC3339)
	}

	jsonResponse(w, http.StatusOK, BankIdVerificationStatus{
		BankIdVerified:       isVerified,
		BankIdPersonalNumber: personalNumber,
		BankIdVerifiedAt:     verifiedAt,
		DisplayName:          claims.DisplayName,
		Role:                 claims.Role,
	})
}

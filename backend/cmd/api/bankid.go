package main

import (
	"bytes"
	"context"
	"crypto/hmac"
	"crypto/rand"
	"crypto/sha256"
	"crypto/tls"
	"crypto/x509"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"log"
	"net"
	"net/http"
	"os"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/feature/dynamodb/attributevalue"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb/types"
	"github.com/golang-jwt/jwt/v5"
)

type bankIdSession struct {
	OrderRef         string    `json:"orderRef"`
	AutoStartToken   string    `json:"autoStartToken"`
	QrStartToken     string    `json:"qrStartToken"`
	QrStartSecret    string    `json:"qrStartSecret"`
	QrCode           string    `json:"qrCode"`
	PersonalNumber   string    `json:"personalNumber"`
	Role             string    `json:"role"`
	DisplayName      string    `json:"displayName"`
	CreatedAt        time.Time `json:"createdAt"`
	PollCount        int       `json:"pollCount"`
	Verified         bool      `json:"verified"`
	CompletedAt      time.Time `json:"completedAt"`
	IsReal           bool      `json:"isReal"`
	MockAutoProgress bool      `json:"mockAutoProgress"`
}

type BankIdVerifiedUser struct {
	ID             string    `json:"id" dynamodbav:"id"`
	Username       string    `json:"username" dynamodbav:"username"`
	PersonalNumber string    `json:"personalNumber" dynamodbav:"personalNumber"`
	VerifiedAt     time.Time `json:"verifiedAt" dynamodbav:"verifiedAt"`
	DisplayName    string    `json:"displayName" dynamodbav:"displayName"`
	Role           string    `json:"role" dynamodbav:"role"`
	BankIdVerified bool      `json:"bankIdVerified" dynamodbav:"bankIdVerified"`
}

type bankIdRPAuthRequest struct {
	EndUserIP   string                 `json:"endUserIp"`
	Requirement map[string]interface{} `json:"requirement,omitempty"`
}

type bankIdRPAuthResponse struct {
	OrderRef       string `json:"orderRef"`
	AutoStartToken string `json:"autoStartToken"`
	QrStartToken   string `json:"qrStartToken"`
	QrStartSecret  string `json:"qrStartSecret"`
}

type bankIdRPCollectRequest struct {
	OrderRef string `json:"orderRef"`
}

type bankIdRPCollectResponse struct {
	OrderRef       string                `json:"orderRef"`
	Status         string                `json:"status"` // "pending", "complete", "failed"
	HintCode       string                `json:"hintCode,omitempty"`
	CompletionData *bankIdCompletionData `json:"completionData,omitempty"`
}

type bankIdCompletionData struct {
	User struct {
		PersonalNumber string `json:"personalNumber"`
		Name           string `json:"name"`
		GivenName      string `json:"givenName"`
		Surname        string `json:"surname"`
	} `json:"user"`
	Device struct {
		IPAddress string `json:"ipAddress"`
	} `json:"device"`
	BankIdIssueDate string `json:"bankIdIssueDate"`
	Signature       string `json:"signature"`
	OcspResponse    string `json:"ocspResponse"`
}

type realBankIdClient struct {
	baseURL    string
	httpClient *http.Client
}

var (
	bankIdOrdersLock sync.RWMutex
	bankIdOrders     = make(map[string]*bankIdSession)

	verifiedUsersLock sync.RWMutex
	verifiedUsers     = make(map[string]*BankIdVerifiedUser)

	bankIdClientInstance *realBankIdClient
	bankIdClientOnce     sync.Once
)

func registerBankIdRoutes(mux *http.ServeMux) {
	mux.HandleFunc("/api/v1/auth/bankid/initiate", handleBankIdInitiate)
	mux.HandleFunc("/api/v1/auth/bankid/collect", handleBankIdCollect)
	mux.HandleFunc("/api/v1/auth/bankid/simulate-complete", handleBankIdSimulateComplete)
	mux.HandleFunc("/api/v1/auth/bankid/cancel", handleBankIdCancel)
	mux.HandleFunc("/api/v1/users/verify-bankid", authMiddleware(handleVerifyBankId))
	mux.HandleFunc("/api/v1/users/verification-status", authMiddleware(handleGetVerificationStatus))
}

func getBankIdClient() *realBankIdClient {
	mode := strings.ToLower(strings.TrimSpace(os.Getenv("BANKID_MODE")))
	if mode == "mock" {
		return nil
	}
	bankIdClientOnce.Do(func() {

		certPath := os.Getenv("BANKID_CERT_FILE")
		keyPath := os.Getenv("BANKID_KEY_FILE")
		caPath := os.Getenv("BANKID_CA_FILE")
		baseURL := os.Getenv("BANKID_BASE_URL")

		if certPath == "" {
			candidates := []string{
				"certs/bankid_test",
				"backend/certs/bankid_test",
				"../certs/bankid_test",
				"../../certs/bankid_test",
			}
			for _, c := range candidates {
				cp := filepath.Join(c, "cert.pem")
				kp := filepath.Join(c, "key.pem")
				ca := filepath.Join(c, "ca.pem")
				if _, err := os.Stat(cp); err == nil {
					certPath = cp
					keyPath = kp
					caPath = ca
					break
				}
			}
		}

		if certPath == "" || keyPath == "" {
			log.Println("No BankID mTLS client certificate found; running BankID in MOCK mode")
			return
		}

		cert, err := tls.LoadX509KeyPair(certPath, keyPath)
		if err != nil {
			log.Printf("Failed to load BankID mTLS cert (%s, %s): %v. Falling back to MOCK.", certPath, keyPath, err)
			return
		}

		tlsConfig := &tls.Config{
			Certificates: []tls.Certificate{cert},
			MinVersion:   tls.VersionTLS12,
		}

		if caPath != "" {
			caBytes, err := os.ReadFile(caPath)
			if err == nil {
				caPool := x509.NewCertPool()
				if caPool.AppendCertsFromPEM(caBytes) {
					tlsConfig.RootCAs = caPool
				}
			}
		}

		if baseURL == "" {
			baseURL = "https://appapi2.test.bankid.com/rp/v6.0"
		}

		bankIdClientInstance = &realBankIdClient{
			baseURL: strings.TrimRight(baseURL, "/"),
			httpClient: &http.Client{
				Timeout: 15 * time.Second,
				Transport: &http.Transport{
					TLSClientConfig: tlsConfig,
				},
			},
		}
		log.Printf("BankID initialized in LIVE mTLS mode against %s", baseURL)
	})
	return bankIdClientInstance
}

func readClientIP(r *http.Request) string {
	if xff := r.Header.Get("X-Forwarded-For"); xff != "" {
		parts := strings.Split(xff, ",")
		ip := strings.TrimSpace(parts[0])
		if ip != "" && ip != "127.0.0.1" && ip != "::1" {
			return ip
		}
	}
	if xri := r.Header.Get("X-Real-IP"); xri != "" {
		ip := strings.TrimSpace(xri)
		if ip != "" && ip != "127.0.0.1" && ip != "::1" {
			return ip
		}
	}
	host, _, err := net.SplitHostPort(r.RemoteAddr)
	if err == nil && host != "" && host != "127.0.0.1" && host != "::1" {
		return host
	}
	// BankID test environment requires a valid IPv4/IPv6 address
	return "194.168.2.1"
}

func calculateBankIdQrCode(qrStartToken, qrStartSecret string, elapsedSeconds int) string {
	mac := hmac.New(sha256.New, []byte(qrStartSecret))
	mac.Write([]byte(strconv.Itoa(elapsedSeconds)))
	qrAuthCode := hex.EncodeToString(mac.Sum(nil))
	return fmt.Sprintf("bankid.%s.%d.%s", qrStartToken, elapsedSeconds, qrAuthCode)
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

func userVerificationKey(identifier string) string {
	clean := strings.ToLower(strings.TrimSpace(identifier))
	return "user-verification#" + clean
}

func loadBankIdVerifiedUser(ctx context.Context, identifier string) (*BankIdVerifiedUser, bool) {
	normalized := strings.TrimSpace(identifier)
	if normalized == "" {
		return nil, false
	}

	// 1. Check in-memory cache
	verifiedUsersLock.RLock()
	user, ok := verifiedUsers[normalized]
	if !ok {
		user, ok = verifiedUsers[strings.ToLower(normalized)]
	}
	verifiedUsersLock.RUnlock()
	if ok && user != nil {
		return user, true
	}

	// 2. Query DynamoDB if available
	if svc == nil || tableName == "" {
		return nil, false
	}

	out, err := svc.GetItem(ctx, &dynamodb.GetItemInput{
		TableName: aws.String(tableName),
		Key: map[string]types.AttributeValue{
			"id": &types.AttributeValueMemberS{Value: userVerificationKey(normalized)},
		},
	})
	if err != nil || len(out.Item) == 0 {
		return nil, false
	}

	var record BankIdVerifiedUser
	if err := attributevalue.UnmarshalMap(out.Item, &record); err != nil {
		log.Printf("Failed to unmarshal user verification from DynamoDB: %v", err)
		return nil, false
	}

	// Cache in-memory
	verifiedUsersLock.Lock()
	verifiedUsers[normalized] = &record
	verifiedUsers[strings.ToLower(normalized)] = &record
	if record.Username != "" {
		verifiedUsers[record.Username] = &record
		verifiedUsers[strings.ToLower(record.Username)] = &record
	}
	if record.DisplayName != "" {
		verifiedUsers[record.DisplayName] = &record
		verifiedUsers[strings.ToLower(record.DisplayName)] = &record
	}
	verifiedUsersLock.Unlock()

	return &record, true
}

func isUserBankIdVerified(userID string) bool {
	_, ok := loadBankIdVerifiedUser(context.Background(), userID)
	return ok
}

func getVerifiedUser(userID string) (*BankIdVerifiedUser, bool) {
	return loadBankIdVerifiedUser(context.Background(), userID)
}

func markUserBankIdVerified(userID, personalNumber, displayName, role string) *BankIdVerifiedUser {
	normalized := strings.TrimSpace(userID)
	if normalized == "" {
		normalized = displayName
	}

	maskedPN := maskPersonalNumber(personalNumber)
	now := time.Now().UTC()

	user := &BankIdVerifiedUser{
		ID:             userVerificationKey(normalized),
		Username:       normalized,
		PersonalNumber: maskedPN,
		VerifiedAt:     now,
		DisplayName:    displayName,
		Role:           role,
		BankIdVerified: true,
	}

	verifiedUsersLock.Lock()
	verifiedUsers[normalized] = user
	verifiedUsers[strings.ToLower(normalized)] = user
	if displayName != "" && displayName != normalized {
		verifiedUsers[displayName] = user
		verifiedUsers[strings.ToLower(displayName)] = user
	}
	verifiedUsersLock.Unlock()

	// Persist to DynamoDB asynchronously
	go func(u BankIdVerifiedUser, uid, dn string) {
		if svc == nil || tableName == "" {
			return
		}
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()

		keysToSave := []string{userVerificationKey(uid)}
		if dn != "" && strings.ToLower(dn) != strings.ToLower(uid) {
			keysToSave = append(keysToSave, userVerificationKey(dn))
		}
		uuidVal := userUUID(uid)
		if uuidVal != "" && uuidVal != uid {
			keysToSave = append(keysToSave, userVerificationKey(uuidVal))
		}
		if dn != "" {
			dnUUID := userUUID(dn)
			if dnUUID != "" && dnUUID != dn {
				keysToSave = append(keysToSave, userVerificationKey(dnUUID))
			}
		}

		for _, key := range keysToSave {
			u.ID = key
			item, err := attributevalue.MarshalMap(u)
			if err != nil {
				continue
			}
			_, _ = svc.PutItem(ctx, &dynamodb.PutItemInput{
				TableName: aws.String(tableName),
				Item:      item,
			})
		}
	}(*user, normalized, displayName)

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

	displayName := strings.TrimSpace(req.DisplayName)
	if displayName == "" {
		if req.PersonalNumber != "" {
			displayName = "BankID " + maskPersonalNumber(req.PersonalNumber)
		} else {
			displayName = "BankID User"
		}
	}

	client := getBankIdClient()
	if client != nil {
		authReq := bankIdRPAuthRequest{
			EndUserIP: readClientIP(r),
		}
		if req.PersonalNumber != "" {
			cleanPN := regexp.MustCompile(`\D`).ReplaceAllString(req.PersonalNumber, "")
			if len(cleanPN) == 10 {
				cleanPN = "19" + cleanPN
			}
			if len(cleanPN) == 12 {
				authReq.Requirement = map[string]interface{}{
					"personalNumber": cleanPN,
				}
			}
		}

		payloadBytes, err := json.Marshal(authReq)
		if err != nil {
			jsonResponse(w, http.StatusInternalServerError, map[string]string{"error": "Failed to serialize BankID payload"})
			return
		}

		httpReq, err := http.NewRequestWithContext(r.Context(), http.MethodPost, client.baseURL+"/auth", bytes.NewReader(payloadBytes))
		if err != nil {
			jsonResponse(w, http.StatusInternalServerError, map[string]string{"error": "Failed to construct BankID request"})
			return
		}
		httpReq.Header.Set("Content-Type", "application/json")

		resp, err := client.httpClient.Do(httpReq)
		if err != nil {
			log.Printf("BankID API network error on /auth: %v", err)
			jsonResponse(w, http.StatusBadGateway, map[string]string{"error": "BankID test server unreachable: " + err.Error()})
			return
		}
		defer resp.Body.Close()

		if resp.StatusCode != http.StatusOK {
			var errBody map[string]interface{}
			_ = json.NewDecoder(resp.Body).Decode(&errBody)
			log.Printf("BankID /auth error HTTP %d: %v", resp.StatusCode, errBody)
			jsonResponse(w, resp.StatusCode, map[string]interface{}{
				"error":   "BankID error",
				"details": errBody,
			})
			return
		}

		var authRes bankIdRPAuthResponse
		if err := json.NewDecoder(resp.Body).Decode(&authRes); err != nil {
			jsonResponse(w, http.StatusInternalServerError, map[string]string{"error": "Failed to parse BankID response"})
			return
		}

		initialQR := calculateBankIdQrCode(authRes.QrStartToken, authRes.QrStartSecret, 0)
		session := &bankIdSession{
			OrderRef:       authRes.OrderRef,
			AutoStartToken: authRes.AutoStartToken,
			QrStartToken:   authRes.QrStartToken,
			QrStartSecret:  authRes.QrStartSecret,
			QrCode:         initialQR,
			PersonalNumber: req.PersonalNumber,
			Role:           role,
			DisplayName:    displayName,
			CreatedAt:      time.Now().UTC(),
			IsReal:         true,
		}

		bankIdOrdersLock.Lock()
		bankIdOrders[authRes.OrderRef] = session
		bankIdOrdersLock.Unlock()

		jsonResponse(w, http.StatusOK, BankIdInitiateResponse{
			OrderRef:       authRes.OrderRef,
			AutoStartToken: authRes.AutoStartToken,
			QrCode:         initialQR,
			QrStartToken:   authRes.QrStartToken,
			QrStartSecret:  authRes.QrStartSecret,
			Status:         "pending",
			Mode:           "test",
		})
		return
	}

	// Mock Fallback
	orderRef := generateRandomToken(16)
	autoStartToken := generateRandomToken(16)
	qrStartToken := generateRandomToken(16)
	qrStartSecret := generateRandomToken(16)
	initialQR := calculateBankIdQrCode(qrStartToken, qrStartSecret, 0)

	session := &bankIdSession{
		OrderRef:         orderRef,
		AutoStartToken:   autoStartToken,
		QrStartToken:     qrStartToken,
		QrStartSecret:    qrStartSecret,
		QrCode:           initialQR,
		PersonalNumber:   req.PersonalNumber,
		Role:             role,
		DisplayName:      displayName,
		CreatedAt:        time.Now().UTC(),
		PollCount:        0,
		Verified:         false,
		IsReal:           false,
		MockAutoProgress: os.Getenv("BANKID_AUTO_PROGRESS") != "false",
	}

	bankIdOrdersLock.Lock()
	bankIdOrders[orderRef] = session
	bankIdOrdersLock.Unlock()

	jsonResponse(w, http.StatusOK, BankIdInitiateResponse{
		OrderRef:       orderRef,
		AutoStartToken: autoStartToken,
		QrCode:         initialQR,
		QrStartToken:   qrStartToken,
		QrStartSecret:  qrStartSecret,
		Status:         "pending",
		Mode:           "mock",
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
	bankIdOrdersLock.Unlock()

	// If it's a real BankID session, query the real BankID Relying Party API
	if session.IsReal {
		client := getBankIdClient()
		if client == nil {
			jsonResponse(w, http.StatusInternalServerError, map[string]string{"error": "BankID client not ready"})
			return
		}

		collectReq := bankIdRPCollectRequest{OrderRef: req.OrderRef}
		payloadBytes, _ := json.Marshal(collectReq)
		httpReq, err := http.NewRequestWithContext(r.Context(), http.MethodPost, client.baseURL+"/collect", bytes.NewReader(payloadBytes))
		if err != nil {
			jsonResponse(w, http.StatusInternalServerError, map[string]string{"error": "Failed to create collect request"})
			return
		}
		httpReq.Header.Set("Content-Type", "application/json")

		resp, err := client.httpClient.Do(httpReq)
		if err != nil {
			log.Printf("BankID API /collect network error: %v", err)
			jsonResponse(w, http.StatusOK, BankIdCollectResponse{
				OrderRef: req.OrderRef,
				Status:   "pending",
				HintCode: "outstandingTransaction",
			})
			return
		}
		defer resp.Body.Close()

		var collectRes bankIdRPCollectResponse
		if err := json.NewDecoder(resp.Body).Decode(&collectRes); err != nil {
			jsonResponse(w, http.StatusInternalServerError, map[string]string{"error": "Failed to decode collect response"})
			return
		}

		if collectRes.Status == "pending" {
			jsonResponse(w, http.StatusOK, BankIdCollectResponse{
				OrderRef: req.OrderRef,
				Status:   "pending",
				HintCode: collectRes.HintCode,
			})
			return
		}

		if collectRes.Status == "failed" {
			bankIdOrdersLock.Lock()
			delete(bankIdOrders, req.OrderRef)
			bankIdOrdersLock.Unlock()

			jsonResponse(w, http.StatusOK, BankIdCollectResponse{
				OrderRef: req.OrderRef,
				Status:   "failed",
				HintCode: collectRes.HintCode,
			})
			return
		}

		// Status is "complete" from real BankID!
		var verifiedPN, verifiedName string
		if collectRes.CompletionData != nil {
			verifiedPN = collectRes.CompletionData.User.PersonalNumber
			verifiedName = collectRes.CompletionData.User.Name
		}
		if verifiedPN == "" {
			verifiedPN = session.PersonalNumber
		}
		if verifiedName == "" {
			verifiedName = session.DisplayName
		}

		session.Verified = true
		session.CompletedAt = time.Now().UTC()
		session.PersonalNumber = verifiedPN
		session.DisplayName = verifiedName

		maskedPN := maskPersonalNumber(verifiedPN)
		username := verifiedName
		if username == "" {
			username = "bankid_" + session.OrderRef[:8]
		}

		markUserBankIdVerified(username, verifiedPN, verifiedName, session.Role)

		tokenString, err := generateBankIdToken(session.Role, username, verifiedName, verifiedPN, session.CompletedAt)
		if err != nil {
			jsonResponse(w, http.StatusInternalServerError, map[string]string{"error": "Could not generate token"})
			return
		}

		jsonResponse(w, http.StatusOK, BankIdCollectResponse{
			OrderRef:         req.OrderRef,
			Status:           "complete",
			HintCode:         "complete",
			Token:            tokenString,
			PersonalNumber:   maskedPN,
			Name:             verifiedName,
			BankIdVerified:   true,
			BankIdVerifiedAt: session.CompletedAt.Format(time.RFC3339),
		})
		return
	}

	// Mock mode handling
	if session.MockAutoProgress {
		elapsed := time.Since(session.CreatedAt)
		isComplete := session.Verified || session.PollCount >= 3 || elapsed >= 1500*time.Millisecond
		if !isComplete {
			hintCode := "outstandingTransaction"
			if session.PollCount >= 2 {
				hintCode = "userSign"
			}
			jsonResponse(w, http.StatusOK, BankIdCollectResponse{
				OrderRef: req.OrderRef,
				Status:   "pending",
				HintCode: hintCode,
			})
			return
		}
		session.Verified = true
		session.CompletedAt = time.Now().UTC()
	}

	if !session.Verified {
		hintCode := "outstandingTransaction"
		if session.PollCount >= 2 {
			hintCode = "userSign"
		}
		jsonResponse(w, http.StatusOK, BankIdCollectResponse{
			OrderRef: req.OrderRef,
			Status:   "pending",
			HintCode: hintCode,
		})
		return
	}

	maskedPN := maskPersonalNumber(session.PersonalNumber)
	username := session.DisplayName
	if username == "" {
		username = "bankid_" + session.OrderRef[:8]
	}

	markUserBankIdVerified(username, session.PersonalNumber, session.DisplayName, session.Role)

	tokenString, err := generateBankIdToken(session.Role, username, session.DisplayName, session.PersonalNumber, session.CompletedAt)
	if err != nil {
		log.Printf("Failed to generate token for BankID collect: %v", err)
		jsonResponse(w, http.StatusInternalServerError, map[string]string{"error": "Could not generate token"})
		return
	}

	jsonResponse(w, http.StatusOK, BankIdCollectResponse{
		OrderRef:         req.OrderRef,
		Status:           "complete",
		HintCode:         "complete",
		Token:            tokenString,
		PersonalNumber:   maskedPN,
		Name:             session.DisplayName,
		BankIdVerified:   true,
		BankIdVerifiedAt: session.CompletedAt.Format(time.RFC3339),
	})
}

func handleBankIdSimulateComplete(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var req struct {
		OrderRef       string `json:"orderRef"`
		PersonalNumber string `json:"personalNumber,omitempty"`
		DisplayName    string `json:"displayName,omitempty"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		jsonResponse(w, http.StatusBadRequest, map[string]string{"error": "Invalid payload"})
		return
	}

	bankIdOrdersLock.Lock()
	session, exists := bankIdOrders[req.OrderRef]
	if !exists {
		bankIdOrdersLock.Unlock()
		jsonResponse(w, http.StatusNotFound, map[string]string{"error": "Session not found"})
		return
	}

	pn := req.PersonalNumber
	if pn == "" {
		pn = session.PersonalNumber
	}
	if pn == "" {
		pn = "199001019802"
	}

	dn := req.DisplayName
	if dn == "" {
		dn = session.DisplayName
	}
	if dn == "" || dn == "BankID User" {
		dn = "Karl Karlsson (BankID)"
	}

	session.Verified = true
	session.CompletedAt = time.Now().UTC()
	session.PersonalNumber = pn
	session.DisplayName = dn
	bankIdOrdersLock.Unlock()

	maskedPN := maskPersonalNumber(pn)
	markUserBankIdVerified(dn, pn, dn, session.Role)

	tokenString, err := generateBankIdToken(session.Role, dn, dn, pn, session.CompletedAt)
	if err != nil {
		jsonResponse(w, http.StatusInternalServerError, map[string]string{"error": "Could not generate token"})
		return
	}

	jsonResponse(w, http.StatusOK, BankIdCollectResponse{
		OrderRef:         req.OrderRef,
		Status:           "complete",
		HintCode:         "complete",
		Token:            tokenString,
		PersonalNumber:   maskedPN,
		Name:             dn,
		BankIdVerified:   true,
		BankIdVerifiedAt: session.CompletedAt.Format(time.RFC3339),
	})
}

func handleBankIdCancel(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var req BankIdCollectRequest
	_ = json.NewDecoder(r.Body).Decode(&req)

	bankIdOrdersLock.Lock()
	session, exists := bankIdOrders[req.OrderRef]
	if exists {
		delete(bankIdOrders, req.OrderRef)
	}
	bankIdOrdersLock.Unlock()

	if exists && session.IsReal {
		client := getBankIdClient()
		if client != nil {
			cancelBody, _ := json.Marshal(map[string]string{"orderRef": req.OrderRef})
			httpReq, err := http.NewRequestWithContext(r.Context(), http.MethodPost, client.baseURL+"/cancel", bytes.NewReader(cancelBody))
			if err == nil {
				httpReq.Header.Set("Content-Type", "application/json")
				resp, err := client.httpClient.Do(httpReq)
				if err == nil {
					resp.Body.Close()
				}
			}
		}
	}

	jsonResponse(w, http.StatusOK, map[string]string{"status": "canceled"})
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
	verifiedUser, exists := loadBankIdVerifiedUser(r.Context(), ownerID)
	if !exists && claims.DisplayName != "" {
		verifiedUser, exists = loadBankIdVerifiedUser(r.Context(), claims.DisplayName)
	}
	if !exists && claims.CognitoUsername != "" {
		verifiedUser, exists = loadBankIdVerifiedUser(r.Context(), claims.CognitoUsername)
	}
	if !exists && claims.Email != "" {
		verifiedUser, exists = loadBankIdVerifiedUser(r.Context(), claims.Email)
	}

	isVerified := claims.BankIdVerified
	personalNumber := claims.BankIdPersonalNumber
	verifiedAt := claims.BankIdVerifiedAt

	if exists && verifiedUser != nil {
		isVerified = true
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

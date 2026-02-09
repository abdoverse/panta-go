package main

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"net/http"
	"os"
	"strings"
	"time"

	"firebase.google.com/go/v4"
	"firebase.google.com/go/v4/messaging"
	"google.golang.org/api/option"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/feature/dynamodb/attributevalue"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb/types"
	"github.com/golang-jwt/jwt/v5"
	"github.com/MicahParks/keyfunc/v2"
)

// Request Data Model
type RecyclingRequest struct {
	ID            string    `json:"id" dynamodbav:"id"`
	Title         string    `json:"title" dynamodbav:"title"`
	ImageUrl      string    `json:"imageUrl" dynamodbav:"imageUrl"`
	ScheduledFrom time.Time `json:"scheduledFrom" dynamodbav:"scheduledFrom"`
	ScheduledTo   time.Time `json:"scheduledTo" dynamodbav:"scheduledTo"`
	Location      string    `json:"location" dynamodbav:"location"`
	Description   string    `json:"description" dynamodbav:"description"`
	Reward        float64   `json:"reward" dynamodbav:"reward"`
	Status        string    `json:"status" dynamodbav:"status"`
	HelperID      string    `json:"helperId,omitempty" dynamodbav:"helperId,omitempty"`
	IsRated       bool      `json:"isRated" dynamodbav:"isRated"`
	Rating        float64   `json:"rating,omitempty" dynamodbav:"rating,omitempty"`
	RatingComment string    `json:"ratingComment,omitempty" dynamodbav:"ratingComment,omitempty"`
	CreatorDeviceToken string `json:"creatorDeviceToken,omitempty" dynamodbav:"creatorDeviceToken,omitempty"`
}

// Auth Types
type LoginRequest struct {
	Role string `json:"role"` // "helper" or "user"
	Name string `json:"username"`
}

type LoginResponse struct {
	Token string `json:"token"`
}

type Claims struct {
	Role string `json:"nickname"`
	Name string `json:"cognito:username"`
	jwt.RegisteredClaims
}

var (
	svc       *dynamodb.Client
	tableName string
	jwtSecret = []byte(os.Getenv("JWT_SECRET"))
	hub       *Hub
	fcmClient *messaging.Client
)

// Helper to send push notification
func sendPushNotification(token string, title string, body string) {
	if fcmClient == nil {
		log.Println("Skipping notification: FCM client not initialized")
		return
	}
	if token == "" {
		return
	}

	start := time.Now()
	_, err := fcmClient.Send(context.Background(), &messaging.Message{
		Token: token,
		Notification: &messaging.Notification{
			Title: title,
			Body:  body,
		},
		Data: map[string]string{
			"click_action": "FLUTTER_NOTIFICATION_CLICK",
		},
	})
	if err != nil {
		log.Printf("Error sending FCM message: %v", err)
	} else {
		log.Printf("Notification sent to %s (took %v)", token, time.Since(start))
	}
}

// Init Firebase
func initFirebase() {
	ctx := context.Background()
	// Use environment variable GOOGLE_APPLICATION_CREDENTIALS or default to local file for dev
	var opts []option.ClientOption
	// If you wanted to force a file:
	// opts = append(opts, option.WithCredentialsFile("google-services.json"))
	// But in AWS, we rely on env vars or metadata service.

	// Create app
	app, err := firebase.NewApp(ctx, nil, opts...)
	if err != nil {
		log.Printf("Warning: error initializing Firebase App: %v. Notifications will not work.", err)
		return
	}

	fcmClient, err = app.Messaging(ctx)
	if err != nil {
		log.Printf("Warning: error getting Messaging client: %v", err)
	} else {
		log.Println("Firebase Messaging initialized successfully")
	}
}

// Global JWKS
var jwks *keyfunc.JWKS

func initJWKS() {
	region := os.Getenv("AWS_REGION")
	userPoolID := os.Getenv("COGNITO_USER_POOL_ID")

	if region == "" || userPoolID == "" {
		log.Println("WARNING: COGNITO_USER_POOL_ID or AWS_REGION not set. Auth verification will fail.")
		return
	}

	jwksURL := fmt.Sprintf("https://cognito-idp.%s.amazonaws.com/%s/.well-known/jwks.json", region, userPoolID)
	log.Printf("Initializing JWKS from: %s", jwksURL)

	var err error
	options := keyfunc.Options{
		RefreshErrorHandler: func(err error) {
			log.Printf("There was an error with the JWKS refresh: %v", err)
		},
		RefreshInterval: time.Hour,
		RefreshTimeout:  time.Second * 10,
		RefreshUnknownKID: true,
	}
	jwks, err = keyfunc.Get(jwksURL, options)
	if err != nil {
		log.Printf("Failed to create JWKS from resource at the given URL.\nError: %v", err)
		// We don't panic here to allow the service to start, but auth will fail
	} else {
		log.Println("JWKS initialized successfully.")
	}
}

func init() {
	// Initialize AWS Client
	cfg, err := config.LoadDefaultConfig(context.TODO())
	if err != nil {
		log.Fatalf("unable to load SDK config, %v", err)
	}

	svc = dynamodb.NewFromConfig(cfg)
	tableName = os.Getenv("TABLE_NAME")
	if tableName == "" {
		log.Println("Warning: TABLE_NAME environment variable is not set")
	}
	if len(jwtSecret) == 0 {
		jwtSecret = []byte("default-secret-key-change-me")
	}
	// Initialize Firebase
	initFirebase()

	// Check for credentials file
	checkCredentials()
}

// Check for credentials file
func checkCredentials() {
	path := os.Getenv("GOOGLE_APPLICATION_CREDENTIALS")
	if path == "" {
		log.Println("⚠️  GOOGLE_APPLICATION_CREDENTIALS env var not set.")
		return
	}
	if _, err := os.Stat(path); err != nil {
		log.Printf("⚠️  Credentials file not found at %s: %v", path, err)
	} else {
		log.Printf("✅ Credentials file found at %s", path)
	}
}

// Simple JSON helper
func jsonResponse(w http.ResponseWriter, status int, data interface{}) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(data)
}

// Basic error checking helper
func errorIs(err error, target interface{}) bool {
	return errors.As(err, target)
}

// CORS Middleware
func enableCORS(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, OPTIONS, PUT, DELETE")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization")

		// Handle preflight requests
		if r.Method == "OPTIONS" {
			w.WriteHeader(http.StatusOK)
			return
		}

		next.ServeHTTP(w, r)
	})
}

// Auth Middleware
func authMiddleware(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		authHeader := r.Header.Get("Authorization")
		if authHeader == "" {
			http.Error(w, "Authorization header required", http.StatusUnauthorized)
			return
		}

		parts := strings.Split(authHeader, " ")
		if len(parts) != 2 || parts[0] != "Bearer" {
			http.Error(w, "Invalid authorization header format", http.StatusUnauthorized)
			return
		}

		tokenString := parts[1]
		claims := &Claims{}

		// Use JWKS if available (Cognito Mode), otherwise fallback to local secret (Dev/Mock Mode)
		var token *jwt.Token
		var err error

		if jwks != nil {
			// Validate using Cognito Public Keys (RSA)
			token, err = jwt.ParseWithClaims(tokenString, claims, jwks.Keyfunc)
		} else {
			// Fallback validation (HMAC) - Only for local testing if env vars are missing
			token, err = jwt.ParseWithClaims(tokenString, claims, func(token *jwt.Token) (interface{}, error) {
				if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
					return nil, fmt.Errorf("unexpected signing method: %v", token.Header["alg"])
				}
				return jwtSecret, nil
			})
		}

		if err != nil || !token.Valid {
			log.Printf("Token validation failed: %v", err)
			http.Error(w, "Invalid token", http.StatusUnauthorized)
			return
		}

		// Pass context with user claims
		ctx := context.WithValue(r.Context(), "user", claims)
		next(w, r.WithContext(ctx))
	}
}

func main() {
	// Initialize JWKS
	initJWKS()

	// Initialize WebSocket Hub
	hub = newHub()
	go hub.run()

	mux := http.NewServeMux()

	// 1. Health Check
	mux.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		jsonResponse(w, 200, map[string]string{"status": "healthy"})
	})

	// 2. API Endpoint
	mux.HandleFunc("/api/v1/hello", func(w http.ResponseWriter, r *http.Request) {
		jsonResponse(w, 200, map[string]string{
			"message": "Hello from Panta Go Backend (DynamoDB Connected)!",
			"backend": "Go",
		})
	})

	// Login Endpoint
	mux.HandleFunc("/api/v1/login", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
			return
		}

		var req LoginRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			jsonResponse(w, 400, map[string]string{"error": "Invalid payload"})
			return
		}

		// Simple mock authentication
		// In a real app, verify user/password here
		if req.Role != "user" && req.Role != "helper" {
			jsonResponse(w, 400, map[string]string{"error": "Invalid role"})
			return
		}

		expirationTime := time.Now().Add(24 * time.Hour)
		claims := &Claims{
			Role: req.Role,
			Name: req.Name,
			RegisteredClaims: jwt.RegisteredClaims{
				ExpiresAt: jwt.NewNumericDate(expirationTime),
				Issuer:    "panta-backend",
			},
		}

		token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
		tokenString, err := token.SignedString(jwtSecret)
		if err != nil {
			jsonResponse(w, 500, map[string]string{"error": "Could not generate token"})
			return
		}

		jsonResponse(w, 200, LoginResponse{Token: tokenString})
	})

	// -------------------------------------------------------------------------
	// Recycling Requests API
	// -------------------------------------------------------------------------

	// GET /api/v1/requests - Get all requests (Public or Protected? Let's protect it)
	mux.HandleFunc("/api/v1/requests", authMiddleware(func(w http.ResponseWriter, r *http.Request) {
		// Enable CORS
		w.Header().Set("Access-Control-Allow-Origin", "*")
		if r.Method == http.MethodGet {
			out, err := svc.Scan(context.TODO(), &dynamodb.ScanInput{
				TableName: aws.String(tableName),
			})
			if err != nil {
				log.Printf("Failed to scan table: %v", err)
				jsonResponse(w, 500, map[string]string{"error": "Failed to fetch requests"})
				return
			}

			var requests []RecyclingRequest
			if err := attributevalue.UnmarshalListOfMaps(out.Items, &requests); err != nil {
				log.Printf("Failed to unmarshal storage: %v", err)
				jsonResponse(w, 500, map[string]string{"error": "Failed to parse data"})
				return
			}

			jsonResponse(w, 200, requests)
			return
		}

		// POST /api/v1/requests - Create a new request
		if r.Method == http.MethodPost {
			var req RecyclingRequest
			if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
				jsonResponse(w, 400, map[string]string{"error": fmt.Sprintf("Invalid payload: %v", err)})
				return
			}

			req.ID = time.Now().Format("20060102150405")
			if req.ImageUrl == "" {
				req.ImageUrl = "assets/images/generic.png"
			}
			req.Status = "pending"

			item, err := attributevalue.MarshalMap(req)
			if err != nil {
				jsonResponse(w, 500, map[string]string{"error": "Failed to marshal item"})
				return
			}

			_, err = svc.PutItem(context.TODO(), &dynamodb.PutItemInput{
				TableName: aws.String(tableName),
				Item:      item,
			})
			if err != nil {
				log.Printf("Failed to put item: %v", err)
				jsonResponse(w, 500, map[string]string{"error": "Failed to save request"})
				return
			}

			// Broadcast Update
			hub.broadcast <- []byte(`{"type":"refresh"}`)

			jsonResponse(w, 201, req)
			return
		}

		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
	}))

	// POST /api/v1/requests/accept
	mux.HandleFunc("/api/v1/requests/accept", authMiddleware(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
			return
		}

		claims, ok := r.Context().Value("user").(*Claims)
		if !ok {
			http.Error(w, "Unauthorized", http.StatusUnauthorized)
			return
		}

		var payload struct {
			ID string `json:"id"`
		}
		if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
			jsonResponse(w, 400, map[string]string{"error": "Invalid payload"})
			return
		}

		// First, fetch the request to get the creator's device token
		// We could do this via ReturnValues: ALL_OLD in UpdateItem, but DynamoDB UpdateItem
		// ReturnValues only supports ALL_NEW, ALL_OLD, etc.
		// Let's rely on ReturnValues: ALL_NEW from the update to get the token *if* it was there?
		// No, usually Update doesn't return existing attributes unless they are modified or requested specifically?
		// Actually ALL_NEW returns the *entire* item after update.

		out, err := svc.UpdateItem(context.TODO(), &dynamodb.UpdateItemInput{
			TableName: aws.String(tableName),
			Key: map[string]types.AttributeValue{
				"id": &types.AttributeValueMemberS{Value: payload.ID},
			},
			UpdateExpression:          aws.String("SET #status = :accepted, helperId = :helperId"),
			ConditionExpression:       aws.String("#status = :pending"),
			ExpressionAttributeNames:  map[string]string{"#status": "status"},
			ExpressionAttributeValues: map[string]types.AttributeValue{
				":accepted": &types.AttributeValueMemberS{Value: "accepted"},
				":helperId": &types.AttributeValueMemberS{Value: claims.Name},
				":pending":  &types.AttributeValueMemberS{Value: "pending"},
			},
			ReturnValues: types.ReturnValueAllNew,
		})

		if err != nil {
			log.Printf("Failed to accept request: %v", err)
			var cfe *types.ConditionalCheckFailedException
			if errorIs(err, &cfe) {
				jsonResponse(w, 400, map[string]string{"error": "Request already accepted or not found"})
			} else {
				jsonResponse(w, 500, map[string]string{"error": "Failed to update request"})
			}
			return
		}

		// Check for CreatorDeviceToken and send notification
		var updatedReq RecyclingRequest
		if err := attributevalue.UnmarshalMap(out.Attributes, &updatedReq); err == nil {
			if updatedReq.CreatorDeviceToken != "" {
				go sendPushNotification(
					updatedReq.CreatorDeviceToken,
					"Request Accepted! 🚛",
					fmt.Sprintf("%s has accepted your request and is on the way.", claims.Name),
				)
			}
		}

		// Broadcast Update
		hub.broadcast <- []byte(`{"type":"refresh"}`)

		jsonResponse(w, 200, map[string]string{"status": "accepted"})
	}))

	// POST /api/v1/requests/complete
	mux.HandleFunc("/api/v1/requests/complete", authMiddleware(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
			return
		}

		var payload struct {
			ID string `json:"id"`
		}
		if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
			jsonResponse(w, 400, map[string]string{"error": "Invalid payload"})
			return
		}

		_, err := svc.UpdateItem(context.TODO(), &dynamodb.UpdateItemInput{
			TableName: aws.String(tableName),
			Key: map[string]types.AttributeValue{
				"id": &types.AttributeValueMemberS{Value: payload.ID},
			},
			UpdateExpression:          aws.String("SET #status = :pickedUp"),
			ExpressionAttributeNames:  map[string]string{"#status": "status"},
			ExpressionAttributeValues: map[string]types.AttributeValue{
				":pickedUp": &types.AttributeValueMemberS{Value: "pickedUp"},
			},
		})

		if err != nil {
			log.Printf("Failed to complete request: %v", err)
			jsonResponse(w, 500, map[string]string{"error": "Failed to update request"})
			return
		}

		// Broadcast Update
		hub.broadcast <- []byte(`{"type":"refresh"}`)

		jsonResponse(w, 200, map[string]string{"status": "pickedUp"})
	}))

	// POST /api/v1/requests/rate
	mux.HandleFunc("/api/v1/requests/rate", authMiddleware(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
			return
		}

		var payload struct {
			ID      string  `json:"id"`
			Rating  float64 `json:"rating"`
			Comment string  `json:"comment"`
		}
		if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
			jsonResponse(w, 400, map[string]string{"error": "Invalid payload"})
			return
		}

		_, err := svc.UpdateItem(context.TODO(), &dynamodb.UpdateItemInput{
			TableName: aws.String(tableName),
			Key: map[string]types.AttributeValue{
				"id": &types.AttributeValueMemberS{Value: payload.ID},
			},
			UpdateExpression: aws.String("SET isRated = :true, rating = :r, ratingComment = :c"),
			ExpressionAttributeValues: map[string]types.AttributeValue{
				":true": &types.AttributeValueMemberBOOL{Value: true},
				":r":    &types.AttributeValueMemberN{Value: fmt.Sprintf("%f", payload.Rating)},
				":c":    &types.AttributeValueMemberS{Value: payload.Comment},
			},
		})

		if err != nil {
			log.Printf("Failed to rate request: %v", err)
			jsonResponse(w, 500, map[string]string{"error": "Failed to update request"})
			return
		}

		// Optional: Broadcast if rating changes view, otherwise not strictly needed
		// hub.broadcast <- []byte(`{"type":"refresh"}`)

		jsonResponse(w, 200, map[string]string{"status": "rated"})
	}))

	// WebSocket Endpoint
	mux.HandleFunc("/api/v1/ws", func(w http.ResponseWriter, r *http.Request) {
		// Verify token (simplified authMiddleware for upgrading)
		// For WS, auth often happens via query param "token" in `ws://url?token=...`
		// or headers (requires specific client support).

		// Extract token from query param since standard JS WebSocket API doesn't support custom headers easily,
		// but standard libraries usually do. Let's try header first, if missing check query.
		tokenString := r.URL.Query().Get("token")
		if tokenString == "" {
			// Fallback to Header logic if possible (e.g. from Flutter)
			authHeader := r.Header.Get("Authorization")
			if authHeader != "" && strings.HasPrefix(authHeader, "Bearer ") {
				tokenString = strings.TrimPrefix(authHeader, "Bearer ")
			}
		}

		if tokenString == "" {
			http.Error(w, "Unauthorized: missing token", http.StatusUnauthorized)
			return
		}

		// Token Validation (same as middleware)
		claims := &Claims{}
		var token *jwt.Token
		var err error

		if jwks != nil {
			token, err = jwt.ParseWithClaims(tokenString, claims, jwks.Keyfunc)
		} else {
			token, err = jwt.ParseWithClaims(tokenString, claims, func(token *jwt.Token) (interface{}, error) {
				if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
					return nil, fmt.Errorf("unexpected signing method: %v", token.Header["alg"])
				}
				return jwtSecret, nil
			})
		}

		if err != nil || !token.Valid {
			http.Error(w, "Unauthorized: invalid token", http.StatusUnauthorized)
			return
		}

		serveWs(hub, w, r)
	})

	// Hello World
	mux.HandleFunc("/helloworld", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "text/plain")
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("Hello World"))
	})

	// 3. Root Endpoint
	mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/" {
			http.NotFound(w, r)
			return
		}
		jsonResponse(w, 200, map[string]string{
			"message":   "Welcome to the Panta Go Backend",
			"endpoints": "/health, /api/v1/hello",
		})
	})

	// 4. Start Server
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}
	log.Printf("Server starting on port %s", port)

	// Wrap mux with CORS middleware
	handler := enableCORS(mux)

	certFile := os.Getenv("TLS_CERT_FILE")
	keyFile := os.Getenv("TLS_KEY_FILE")

	if certFile != "" && keyFile != "" {
		log.Printf("Starting in HTTPS mode...")
		if err := http.ListenAndServeTLS(":"+port, certFile, keyFile, handler); err != nil {
			log.Fatal(err)
		}
	} else {
		log.Printf("Starting in HTTP mode (HTTPS not configured)...")
		if err := http.ListenAndServe(":"+port, handler); err != nil {
			log.Fatal(err)
		}
	}
}


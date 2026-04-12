package main

import (
	"bytes"
	"context"
	"crypto/rand"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	pathpkg "path"
	"strings"
	"time"

	"firebase.google.com/go/v4"
	"firebase.google.com/go/v4/messaging"
	"google.golang.org/api/option"

	"github.com/MicahParks/keyfunc/v2"
	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/feature/dynamodb/attributevalue"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb/types"
	"github.com/aws/aws-sdk-go-v2/service/s3"
	"github.com/golang-jwt/jwt/v5"
)

// Request Data Model
type RecyclingRequest struct {
	ID                 string    `json:"id" dynamodbav:"id"`
	Title              string    `json:"title" dynamodbav:"title"`
	ImageUrl           string    `json:"imageUrl" dynamodbav:"imageUrl"`
	ImageUploadKey     string    `json:"imageUploadKey,omitempty" dynamodbav:"-"`
	ScheduledFrom      time.Time `json:"scheduledFrom" dynamodbav:"scheduledFrom"`
	ScheduledTo        time.Time `json:"scheduledTo" dynamodbav:"scheduledTo"`
	Location           string    `json:"location" dynamodbav:"location"`
	Description        string    `json:"description" dynamodbav:"description"`
	Reward             float64   `json:"reward" dynamodbav:"reward"`
	Status             string    `json:"status" dynamodbav:"status"`
	HelperID           string    `json:"helperId,omitempty" dynamodbav:"helperId,omitempty"`
	CanceledHelperIDs  []string  `json:"canceledHelperIds,omitempty" dynamodbav:"canceledHelperIds,omitempty"`
	IsRated            bool      `json:"isRated" dynamodbav:"isRated"`
	Rating             float64   `json:"rating,omitempty" dynamodbav:"rating,omitempty"`
	RatingComment      string    `json:"ratingComment,omitempty" dynamodbav:"ratingComment,omitempty"`
	CreatorDeviceToken string    `json:"creatorDeviceToken,omitempty" dynamodbav:"creatorDeviceToken,omitempty"`
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
	Role            string `json:"nickname"`
	CognitoUsername string `json:"cognito:username"`
	DisplayName     string `json:"name"`
	Email           string `json:"email"`
	jwt.RegisteredClaims
}

func (c *Claims) helperID() string {
	if username := strings.TrimSpace(c.CognitoUsername); username != "" {
		return username
	}
	if name := strings.TrimSpace(c.DisplayName); name != "" {
		return name
	}
	return strings.TrimSpace(c.Email)
}

func (c *Claims) notificationName() string {
	if name := strings.TrimSpace(c.DisplayName); name != "" {
		return name
	}
	if email := strings.TrimSpace(c.Email); email != "" {
		return strings.Split(email, "@")[0]
	}
	return c.helperID()
}

var (
	svc             *dynamodb.Client
	s3Client        *s3.Client
	s3PresignClient *s3.PresignClient
	tableName       string
	imageBucketName string
	jwtSecret       = []byte(os.Getenv("JWT_SECRET"))
	hub             *Hub
	fcmClient       *messaging.Client
)

const (
	requestImageUploadLimitBytes = 8 << 20
	requestImageURLTTL           = 24 * time.Hour
)

var allowedImageContentTypes = map[string]string{
	"image/jpeg": "jpg",
	"image/png":  "png",
	"image/webp": "webp",
	"image/gif":  "gif",
}

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
	var opts []option.ClientOption

	if serviceAccountJSON := os.Getenv("FIREBASE_SERVICE_ACCOUNT_JSON"); serviceAccountJSON != "" {
		opts = append(opts, option.WithCredentialsJSON([]byte(serviceAccountJSON)))
		log.Println("Firebase service account loaded from injected secret")
	} else if credentialsPath := os.Getenv("GOOGLE_APPLICATION_CREDENTIALS"); credentialsPath != "" {
		opts = append(opts, option.WithCredentialsFile(credentialsPath))
		log.Printf("Firebase service account loaded from %s", credentialsPath)
	} else {
		log.Println("⚠️  Firebase service account not configured. Notifications will not work.")
	}

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
		RefreshInterval:   time.Hour,
		RefreshTimeout:    time.Second * 10,
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
	s3Client = s3.NewFromConfig(cfg)
	s3PresignClient = s3.NewPresignClient(s3Client)
	tableName = os.Getenv("TABLE_NAME")
	imageBucketName = os.Getenv("IMAGE_BUCKET_NAME")
	if tableName == "" {
		log.Println("Warning: TABLE_NAME environment variable is not set")
	}
	if imageBucketName == "" {
		log.Println("Warning: IMAGE_BUCKET_NAME environment variable is not set")
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
	if os.Getenv("FIREBASE_SERVICE_ACCOUNT_JSON") != "" {
		log.Println("✅ Firebase service account injected via secret")
		return
	}

	path := os.Getenv("GOOGLE_APPLICATION_CREDENTIALS")
	if path == "" {
		log.Println("⚠️  FIREBASE_SERVICE_ACCOUNT_JSON and GOOGLE_APPLICATION_CREDENTIALS are both unset.")
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

func newRequestID() string {
	return fmt.Sprintf("%s-%s", time.Now().UTC().Format("20060102150405"), randomHex(8))
}

func randomHex(length int) string {
	if length <= 0 {
		return ""
	}

	buf := make([]byte, (length+1)/2)
	if _, err := rand.Read(buf); err != nil {
		log.Fatalf("failed to generate random bytes: %v", err)
	}

	return hex.EncodeToString(buf)[:length]
}

func sanitizePathSegment(value string) string {
	trimmed := strings.TrimSpace(value)
	if trimmed == "" {
		return "anonymous"
	}

	replacer := strings.NewReplacer("/", "-", "\\", "-", " ", "-", ":", "-")
	return replacer.Replace(trimmed)
}

func tempUploadPrefix(ownerID string) string {
	return fmt.Sprintf("users/%s/request-images/uploads/", sanitizePathSegment(ownerID))
}

func finalRequestImageKey(requestID string, extension string) string {
	return fmt.Sprintf("requests/%s/images/original.%s", sanitizePathSegment(requestID), strings.TrimPrefix(extension, "."))
}

func parseS3ImageReference(reference string) (bucket string, key string, ok bool) {
	if !strings.HasPrefix(reference, "s3://") {
		return "", "", false
	}

	trimmed := strings.TrimPrefix(reference, "s3://")
	parts := strings.SplitN(trimmed, "/", 2)
	if len(parts) != 2 || parts[0] == "" || parts[1] == "" {
		return "", "", false
	}

	return parts[0], parts[1], true
}

func resolveImageURL(ctx context.Context, storedValue string) (string, error) {
	storedValue = strings.TrimSpace(storedValue)
	if storedValue == "" {
		return storedValue, nil
	}

	bucket := imageBucketName
	key := storedValue

	if parsedBucket, parsedKey, ok := parseS3ImageReference(storedValue); ok {
		bucket = parsedBucket
		key = parsedKey
	} else if strings.HasPrefix(storedValue, "http") || strings.HasPrefix(storedValue, "data:") || strings.HasPrefix(storedValue, "assets/") {
		return storedValue, nil
	}

	if s3PresignClient == nil {
		return "", fmt.Errorf("s3 presign client is not configured")
	}

	presigned, err := s3PresignClient.PresignGetObject(ctx, &s3.GetObjectInput{
		Bucket: aws.String(bucket),
		Key:    aws.String(key),
	}, func(options *s3.PresignOptions) {
		options.Expires = requestImageURLTTL
	})
	if err != nil {
		return "", fmt.Errorf("presign image %s: %w", key, err)
	}

	return presigned.URL, nil
}

func imageExtensionForContentType(contentType string) (string, bool) {
	normalized := strings.ToLower(strings.TrimSpace(contentType))
	if ext, ok := allowedImageContentTypes[normalized]; ok {
		return ext, true
	}
	return "", false
}

func uploadImageBytes(ctx context.Context, bucket string, key string, payload []byte, contentType string, metadata map[string]string) (string, error) {
	if s3Client == nil {
		return "", fmt.Errorf("s3 client is not configured")
	}
	if bucket == "" {
		return "", fmt.Errorf("image bucket is not configured")
	}

	_, err := s3Client.PutObject(ctx, &s3.PutObjectInput{
		Bucket:      aws.String(bucket),
		Key:         aws.String(key),
		Body:        bytes.NewReader(payload),
		ContentType: aws.String(contentType),
		Metadata:    metadata,
	})
	if err != nil {
		return "", fmt.Errorf("put object %s: %w", key, err)
	}

	return key, nil
}

func finalizeUploadedRequestImage(ctx context.Context, ownerID string, requestID string, uploadKey string) (string, error) {
	if imageBucketName == "" {
		return "", fmt.Errorf("image bucket is not configured")
	}

	expectedPrefix := tempUploadPrefix(ownerID)
	if !strings.HasPrefix(uploadKey, expectedPrefix) {
		return "", fmt.Errorf("upload key does not belong to the current user")
	}

	extension := pathpkg.Ext(uploadKey)
	if extension == "" {
		return "", fmt.Errorf("upload key is missing a file extension")
	}

	finalKey := finalRequestImageKey(requestID, extension)
	copySource := fmt.Sprintf("%s/%s", imageBucketName, uploadKey)

	if _, err := s3Client.CopyObject(ctx, &s3.CopyObjectInput{
		Bucket:            aws.String(imageBucketName),
		CopySource:        aws.String(copySource),
		Key:               aws.String(finalKey),
		MetadataDirective: "COPY",
	}); err != nil {
		return "", fmt.Errorf("copy uploaded image: %w", err)
	}

	if _, err := s3Client.DeleteObject(ctx, &s3.DeleteObjectInput{
		Bucket: aws.String(imageBucketName),
		Key:    aws.String(uploadKey),
	}); err != nil {
		return "", fmt.Errorf("delete temporary upload: %w", err)
	}

	return finalKey, nil
}

func parseDataURLImage(payload string) ([]byte, string, error) {
	if !strings.HasPrefix(payload, "data:") {
		return nil, "", fmt.Errorf("image payload is not a data URL")
	}

	header, encoded, found := strings.Cut(payload, ",")
	if !found {
		return nil, "", fmt.Errorf("invalid data URL payload")
	}

	contentType := strings.TrimPrefix(header, "data:")
	contentType = strings.TrimSuffix(contentType, ";base64")
	if _, ok := imageExtensionForContentType(contentType); !ok {
		return nil, "", fmt.Errorf("unsupported image content type: %s", contentType)
	}

	decoded, err := base64.StdEncoding.DecodeString(encoded)
	if err != nil {
		return nil, "", fmt.Errorf("decode base64 image: %w", err)
	}

	return decoded, contentType, nil
}

func prepareRequestImageReference(ctx context.Context, claims *Claims, requestID string, uploadKey string, imageURL string) (string, error) {
	switch {
	case strings.TrimSpace(uploadKey) != "":
		return finalizeUploadedRequestImage(ctx, claims.helperID(), requestID, strings.TrimSpace(uploadKey))
	case strings.HasPrefix(strings.TrimSpace(imageURL), "data:"):
		imageBytes, contentType, err := parseDataURLImage(strings.TrimSpace(imageURL))
		if err != nil {
			return "", err
		}

		extension, _ := imageExtensionForContentType(contentType)
		return uploadImageBytes(
			ctx,
			imageBucketName,
			finalRequestImageKey(requestID, extension),
			imageBytes,
			contentType,
			map[string]string{
				"request-id":  requestID,
				"uploaded-by": sanitizePathSegment(claims.helperID()),
				"source":      "legacy-data-url",
			},
		)
	case strings.TrimSpace(imageURL) == "":
		return "assets/images/generic.png", nil
	default:
		return imageURL, nil
	}
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
			Role:            req.Role,
			CognitoUsername: req.Name,
			DisplayName:     req.Name,
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

	mux.HandleFunc("/api/v1/uploads/request-image", authMiddleware(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
			return
		}

		claims, ok := r.Context().Value("user").(*Claims)
		if !ok {
			http.Error(w, "Unauthorized", http.StatusUnauthorized)
			return
		}
		if imageBucketName == "" {
			jsonResponse(w, 500, map[string]string{"error": "Image storage is not configured"})
			return
		}

		r.Body = http.MaxBytesReader(w, r.Body, requestImageUploadLimitBytes+(1<<20))
		file, header, err := r.FormFile("file")
		if err != nil {
			jsonResponse(w, 400, map[string]string{"error": "Request image file is required"})
			return
		}
		defer file.Close()

		fileBytes, err := io.ReadAll(io.LimitReader(file, requestImageUploadLimitBytes+1))
		if err != nil {
			jsonResponse(w, 400, map[string]string{"error": "Failed to read request image"})
			return
		}
		if len(fileBytes) == 0 {
			jsonResponse(w, 400, map[string]string{"error": "Request image is empty"})
			return
		}
		if len(fileBytes) > requestImageUploadLimitBytes {
			jsonResponse(w, 400, map[string]string{"error": "Request image exceeds the 8 MB limit"})
			return
		}

		contentType := http.DetectContentType(fileBytes)
		extension, ok := imageExtensionForContentType(contentType)
		if !ok {
			jsonResponse(w, 400, map[string]string{"error": "Unsupported image type. Use JPEG, PNG, WebP, or GIF."})
			return
		}

		filename := strings.TrimSpace(header.Filename)
		if filename == "" {
			filename = "request-image"
		}
		if existingExtension := pathpkg.Ext(filename); existingExtension != "" {
			filename = strings.TrimSuffix(filename, existingExtension)
		}
		filename = sanitizePathSegment(filename)

		uploadKey := fmt.Sprintf(
			"%s%s-%s.%s",
			tempUploadPrefix(claims.helperID()),
			time.Now().UTC().Format("2006/01/02/150405"),
			fmt.Sprintf("%s-%s", filename, randomHex(8)),
			extension,
		)

		if _, err := uploadImageBytes(
			r.Context(),
			imageBucketName,
			uploadKey,
			fileBytes,
			contentType,
			map[string]string{
				"uploaded-by": sanitizePathSegment(claims.helperID()),
				"source":      "multipart-upload",
			},
		); err != nil {
			log.Printf("Failed to upload request image: %v", err)
			jsonResponse(w, 500, map[string]string{"error": "Failed to upload request image"})
			return
		}

		jsonResponse(w, 201, map[string]string{
			"uploadKey": uploadKey,
		})
	}))

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

			for i := range requests {
				resolvedURL, err := resolveImageURL(r.Context(), requests[i].ImageUrl)
				if err != nil {
					log.Printf("Failed to resolve image URL for request %s: %v", requests[i].ID, err)
					jsonResponse(w, 500, map[string]string{"error": "Failed to resolve request images"})
					return
				}
				requests[i].ImageUrl = resolvedURL
			}

			jsonResponse(w, 200, requests)
			return
		}

		// POST /api/v1/requests - Create a new request
		if r.Method == http.MethodPost {
			claims, ok := r.Context().Value("user").(*Claims)
			if !ok {
				http.Error(w, "Unauthorized", http.StatusUnauthorized)
				return
			}

			var req RecyclingRequest
			if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
				jsonResponse(w, 400, map[string]string{"error": fmt.Sprintf("Invalid payload: %v", err)})
				return
			}

			req.ID = newRequestID()
			if strings.TrimSpace(req.ImageUrl) == "" && strings.TrimSpace(req.ImageUploadKey) == "" {
				req.ImageUrl = "assets/images/generic.png"
			}
			if req.ImageUrl != "assets/images/generic.png" || strings.TrimSpace(req.ImageUploadKey) != "" {
				imageReference, err := prepareRequestImageReference(r.Context(), claims, req.ID, req.ImageUploadKey, req.ImageUrl)
				if err != nil {
					log.Printf("Failed to prepare image for request %s: %v", req.ID, err)
					jsonResponse(w, 400, map[string]string{"error": "Failed to process request image"})
					return
				}
				req.ImageUrl = imageReference
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
			UpdateExpression:         aws.String("SET #status = :accepted, helperId = :helperId"),
			ConditionExpression:      aws.String("#status = :pending AND (attribute_not_exists(canceledHelperIds) OR NOT contains(canceledHelperIds, :helperId))"),
			ExpressionAttributeNames: map[string]string{"#status": "status"},
			ExpressionAttributeValues: map[string]types.AttributeValue{
				":accepted": &types.AttributeValueMemberS{Value: "accepted"},
				":helperId": &types.AttributeValueMemberS{Value: claims.helperID()},
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
					fmt.Sprintf("%s has accepted your request and is on the way.", claims.notificationName()),
				)
			}
		}

		// Broadcast Update
		hub.broadcast <- []byte(`{"type":"refresh"}`)

		jsonResponse(w, 200, map[string]string{"status": "accepted"})
	}))

	// POST /api/v1/requests/cancel
	mux.HandleFunc("/api/v1/requests/cancel", authMiddleware(func(w http.ResponseWriter, r *http.Request) {
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

		helperID := claims.helperID()
		out, err := svc.UpdateItem(context.TODO(), &dynamodb.UpdateItemInput{
			TableName: aws.String(tableName),
			Key: map[string]types.AttributeValue{
				"id": &types.AttributeValueMemberS{Value: payload.ID},
			},
			UpdateExpression:    aws.String("SET #status = :pending, canceledHelperIds = list_append(if_not_exists(canceledHelperIds, :emptyList), :helperList) REMOVE helperId"),
			ConditionExpression: aws.String("#status = :accepted AND helperId = :helperId"),
			ExpressionAttributeNames: map[string]string{
				"#status": "status",
			},
			ExpressionAttributeValues: map[string]types.AttributeValue{
				":pending":   &types.AttributeValueMemberS{Value: "pending"},
				":helperId":  &types.AttributeValueMemberS{Value: helperID},
				":emptyList": &types.AttributeValueMemberL{Value: []types.AttributeValue{}},
				":helperList": &types.AttributeValueMemberL{Value: []types.AttributeValue{
					&types.AttributeValueMemberS{Value: helperID},
				}},
			},
			ReturnValues: types.ReturnValueAllNew,
		})

		if err != nil {
			log.Printf("Failed to cancel request: %v", err)
			var cfe *types.ConditionalCheckFailedException
			if errorIs(err, &cfe) {
				jsonResponse(w, 400, map[string]string{"error": "Request is no longer assigned to you"})
			} else {
				jsonResponse(w, 500, map[string]string{"error": "Failed to cancel pickup"})
			}
			return
		}

		var updatedReq RecyclingRequest
		if err := attributevalue.UnmarshalMap(out.Attributes, &updatedReq); err == nil {
			if updatedReq.CreatorDeviceToken != "" {
				go sendPushNotification(
					updatedReq.CreatorDeviceToken,
					"Pickup Cancelled",
					fmt.Sprintf("%s can no longer complete your pickup. Your request is available for another helper again.", claims.notificationName()),
				)
			}
		}

		hub.broadcast <- []byte(`{"type":"refresh"}`)

		jsonResponse(w, 200, map[string]string{"status": "pending"})
	}))

	// POST /api/v1/requests/complete
	mux.HandleFunc("/api/v1/requests/complete", authMiddleware(func(w http.ResponseWriter, r *http.Request) {
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

		_, err := svc.UpdateItem(context.TODO(), &dynamodb.UpdateItemInput{
			TableName: aws.String(tableName),
			Key: map[string]types.AttributeValue{
				"id": &types.AttributeValueMemberS{Value: payload.ID},
			},
			UpdateExpression:         aws.String("SET #status = :pickedUp"),
			ConditionExpression:      aws.String("#status = :accepted AND helperId = :helperId"),
			ExpressionAttributeNames: map[string]string{"#status": "status"},
			ExpressionAttributeValues: map[string]types.AttributeValue{
				":pickedUp": &types.AttributeValueMemberS{Value: "pickedUp"},
				":accepted": &types.AttributeValueMemberS{Value: "accepted"},
				":helperId": &types.AttributeValueMemberS{Value: claims.helperID()},
			},
		})

		if err != nil {
			log.Printf("Failed to complete request: %v", err)
			var cfe *types.ConditionalCheckFailedException
			if errorIs(err, &cfe) {
				jsonResponse(w, 400, map[string]string{"error": "Request is no longer assigned to you"})
			} else {
				jsonResponse(w, 500, map[string]string{"error": "Failed to update request"})
			}
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

		// Broadcast update so helper sees the rating immediately
		if hub != nil {
			hub.broadcast <- []byte(`{"type":"refresh"}`)
		}

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

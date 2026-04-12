package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"strings"
	"time"

	"github.com/MicahParks/keyfunc/v2"
	"github.com/golang-jwt/jwt/v5"
)

type contextKey string

const userContextKey contextKey = "user"

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
	jwks, err = keyfunc.Get(jwksURL, keyfunc.Options{
		RefreshErrorHandler: func(err error) {
			log.Printf("There was an error with the JWKS refresh: %v", err)
		},
		RefreshInterval:   time.Hour,
		RefreshTimeout:    10 * time.Second,
		RefreshUnknownKID: true,
	})
	if err != nil {
		log.Printf("Failed to create JWKS from resource at the given URL. Error: %v", err)
		return
	}

	log.Println("JWKS initialized successfully.")
}

func registerAuthRoutes(mux *http.ServeMux) {
	mux.HandleFunc("/api/v1/login", handleLogin)
}

func handleLogin(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var req LoginRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		jsonResponse(w, http.StatusBadRequest, map[string]string{"error": "Invalid payload"})
		return
	}
	if req.Role != "user" && req.Role != "helper" {
		jsonResponse(w, http.StatusBadRequest, map[string]string{"error": "Invalid role"})
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
		jsonResponse(w, http.StatusInternalServerError, map[string]string{"error": "Could not generate token"})
		return
	}

	jsonResponse(w, http.StatusOK, LoginResponse{Token: tokenString})
}

func authMiddleware(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		tokenString, err := bearerTokenFromRequest(r)
		if err != nil {
			http.Error(w, err.Error(), http.StatusUnauthorized)
			return
		}

		claims, err := validateToken(tokenString)
		if err != nil {
			log.Printf("Token validation failed: %v", err)
			http.Error(w, "Invalid token", http.StatusUnauthorized)
			return
		}

		ctx := context.WithValue(r.Context(), userContextKey, claims)
		next(w, r.WithContext(ctx))
	}
}

func currentClaims(r *http.Request) (*Claims, bool) {
	claims, ok := r.Context().Value(userContextKey).(*Claims)
	return claims, ok
}

func validateToken(tokenString string) (*Claims, error) {
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
	if err != nil {
		return nil, err
	}
	if !token.Valid {
		return nil, fmt.Errorf("token is invalid")
	}

	return claims, nil
}

func bearerTokenFromRequest(r *http.Request) (string, error) {
	authHeader := r.Header.Get("Authorization")
	if authHeader == "" {
		return "", fmt.Errorf("Authorization header required")
	}

	parts := strings.Split(authHeader, " ")
	if len(parts) != 2 || parts[0] != "Bearer" {
		return "", fmt.Errorf("Invalid authorization header format")
	}

	return parts[1], nil
}

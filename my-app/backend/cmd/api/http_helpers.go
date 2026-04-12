package main

import (
	"encoding/json"
	"errors"
	"net/http"
	"net/url"
	"os"
	"strings"
)

func jsonResponse(w http.ResponseWriter, status int, data interface{}) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(data)
}

func errorIs(err error, target interface{}) bool {
	return errors.As(err, target)
}

var configuredAllowedOrigins = loadConfiguredAllowedOrigins()

func enableCORS(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if !applyCORSHeaders(w, r) {
			http.Error(w, "Origin not allowed", http.StatusForbidden)
			return
		}

		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, OPTIONS, PUT, DELETE")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization")

		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusOK)
			return
		}

		next.ServeHTTP(w, r)
	})
}

func loadConfiguredAllowedOrigins() map[string]struct{} {
	rawOrigins := strings.Split(os.Getenv("CORS_ALLOWED_ORIGINS"), ",")
	allowed := make(map[string]struct{}, len(rawOrigins))

	for _, rawOrigin := range rawOrigins {
		origin := strings.TrimSpace(rawOrigin)
		if origin == "" {
			continue
		}
		allowed[origin] = struct{}{}
	}

	return allowed
}

func applyCORSHeaders(w http.ResponseWriter, r *http.Request) bool {
	origin := strings.TrimSpace(r.Header.Get("Origin"))
	if origin == "" {
		return true
	}

	if !isAllowedOrigin(origin, r) {
		return false
	}

	w.Header().Set("Access-Control-Allow-Origin", origin)
	w.Header().Add("Vary", "Origin")
	return true
}

func isAllowedOrigin(origin string, r *http.Request) bool {
	parsedOrigin, err := url.Parse(origin)
	if err != nil || parsedOrigin.Host == "" {
		return false
	}

	if parsedOrigin.Host == r.Host && (parsedOrigin.Scheme == "http" || parsedOrigin.Scheme == "https") {
		return true
	}

	_, ok := configuredAllowedOrigins[origin]
	return ok
}

func registerRoutes(mux *http.ServeMux) {
	registerCoreRoutes(mux)
	registerAuthRoutes(mux)
	registerUploadRoutes(mux)
	registerRequestRoutes(mux)
	registerRealtimeRoutes(mux)
}

func registerCoreRoutes(mux *http.ServeMux) {
	mux.HandleFunc("/health", handleHealth)
	mux.HandleFunc("/api/v1/hello", handleAPIGreeting)
	mux.HandleFunc("/helloworld", handleHelloWorld)
	mux.HandleFunc("/", handleRoot)
}

func handleHealth(w http.ResponseWriter, r *http.Request) {
	jsonResponse(w, http.StatusOK, map[string]string{"status": "healthy"})
}

func handleAPIGreeting(w http.ResponseWriter, r *http.Request) {
	jsonResponse(w, http.StatusOK, map[string]string{
		"message": "Hello from Panta Go Backend (DynamoDB Connected)!",
		"backend": "Go",
	})
}

func handleHelloWorld(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "text/plain")
	w.WriteHeader(http.StatusOK)
	_, _ = w.Write([]byte("Hello World"))
}

func handleRoot(w http.ResponseWriter, r *http.Request) {
	if r.URL.Path != "/" {
		http.NotFound(w, r)
		return
	}
	jsonResponse(w, http.StatusOK, map[string]string{
		"message":   "Welcome to the Panta Go Backend",
		"endpoints": "/health, /api/v1/hello",
	})
}

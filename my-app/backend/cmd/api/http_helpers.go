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
		origin, ok := normalizeAllowedOrigin(rawOrigin)
		if !ok {
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
	normalizedOrigin, ok := normalizeAllowedOrigin(origin)
	if !ok {
		return false
	}

	if sameOriginRequest(normalizedOrigin, r) {
		return true
	}

	_, isConfiguredOrigin := configuredAllowedOrigins[normalizedOrigin]
	return isConfiguredOrigin
}

func normalizeAllowedOrigin(rawOrigin string) (string, bool) {
	origin := strings.TrimSpace(rawOrigin)
	if origin == "" {
		return "", false
	}

	parsedOrigin, err := url.Parse(origin)
	if err != nil || parsedOrigin.Host == "" {
		return "", false
	}

	if parsedOrigin.Scheme != "http" && parsedOrigin.Scheme != "https" {
		return "", false
	}

	if parsedOrigin.Path != "" && parsedOrigin.Path != "/" {
		return "", false
	}

	if parsedOrigin.RawQuery != "" || parsedOrigin.Fragment != "" || parsedOrigin.User != nil {
		return "", false
	}

	return parsedOrigin.Scheme + "://" + parsedOrigin.Host, true
}

func sameOriginRequest(origin string, r *http.Request) bool {
	requestOrigin, ok := normalizedRequestOrigin(r)
	if !ok {
		return false
	}
	return origin == requestOrigin
}

func normalizedRequestOrigin(r *http.Request) (string, bool) {
	host := strings.TrimSpace(r.Host)
	if host == "" {
		return "", false
	}

	scheme := strings.TrimSpace(r.Header.Get("X-Forwarded-Proto"))
	if scheme == "" {
		if r.TLS != nil {
			scheme = "https"
		} else {
			scheme = "http"
		}
	}

	scheme = strings.ToLower(scheme)
	if scheme != "http" && scheme != "https" {
		return "", false
	}

	parsedRequestHost, err := url.Parse(scheme + "://" + host)
	if err != nil || parsedRequestHost.Host == "" {
		return "", false
	}

	return parsedRequestHost.Scheme + "://" + parsedRequestHost.Host, true
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

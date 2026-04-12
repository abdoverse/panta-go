package main

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"strings"
	"testing"
)

func TestBearerTokenFromRequest(t *testing.T) {
	t.Parallel()

	tests := []struct {
		name          string
		header        string
		wantToken     string
		wantErrorText string
	}{
		{name: "accepts bearer tokens", header: "Bearer abc123", wantToken: "abc123"},
		{name: "requires auth header", wantErrorText: "Authorization header required"},
		{name: "rejects malformed header", header: "Token abc123", wantErrorText: "Invalid authorization header format"},
	}

	for _, tt := range tests {
		tt := tt
		t.Run(tt.name, func(t *testing.T) {
			t.Parallel()

			req := httptest.NewRequest(http.MethodGet, "/api/v1/requests", nil)
			if tt.header != "" {
				req.Header.Set("Authorization", tt.header)
			}

			got, err := bearerTokenFromRequest(req)
			if tt.wantErrorText != "" {
				if err == nil || err.Error() != tt.wantErrorText {
					t.Fatalf("bearerTokenFromRequest() error = %v, want %q", err, tt.wantErrorText)
				}
				return
			}
			if err != nil {
				t.Fatalf("bearerTokenFromRequest() unexpected error = %v", err)
			}
			if got != tt.wantToken {
				t.Fatalf("bearerTokenFromRequest() = %q, want %q", got, tt.wantToken)
			}
		})
	}
}

func TestHandleLogin(t *testing.T) {
	originalSecret := jwtSecret
	jwtSecret = []byte("test-secret")
	t.Cleanup(func() {
		jwtSecret = originalSecret
	})

	t.Run("rejects unsupported roles", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodPost, "/api/v1/login", strings.NewReader(`{"role":"admin","username":"abdo"}`))
		recorder := httptest.NewRecorder()

		handleLogin(recorder, req)

		if recorder.Code != http.StatusBadRequest {
			t.Fatalf("handleLogin() status = %d, want %d", recorder.Code, http.StatusBadRequest)
		}
	})

	t.Run("returns a signed token for supported roles", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodPost, "/api/v1/login", strings.NewReader(`{"role":"helper","username":"abdo"}`))
		recorder := httptest.NewRecorder()

		handleLogin(recorder, req)

		if recorder.Code != http.StatusOK {
			t.Fatalf("handleLogin() status = %d, want %d", recorder.Code, http.StatusOK)
		}

		var response LoginResponse
		if err := json.NewDecoder(recorder.Body).Decode(&response); err != nil {
			t.Fatalf("decode login response: %v", err)
		}
		if strings.TrimSpace(response.Token) == "" {
			t.Fatal("handleLogin() returned an empty token")
		}
	})
}

func TestResolveJWTSecret(t *testing.T) {
	originalSecret, hasOriginalSecret := os.LookupEnv("JWT_SECRET")
	originalEnv, hasOriginalEnv := os.LookupEnv("APP_ENV")
	t.Cleanup(func() {
		if hasOriginalSecret {
			t.Setenv("JWT_SECRET", originalSecret)
		} else {
			t.Setenv("JWT_SECRET", "")
		}
		if hasOriginalEnv {
			t.Setenv("APP_ENV", originalEnv)
		} else {
			t.Setenv("APP_ENV", "")
		}
	})

	t.Run("requires JWT secret in production", func(t *testing.T) {
		t.Setenv("APP_ENV", "production")
		t.Setenv("JWT_SECRET", "")

		if _, err := resolveJWTSecret(); err == nil {
			t.Fatal("resolveJWTSecret() error = nil, want production failure")
		}
	})

	t.Run("falls back locally", func(t *testing.T) {
		t.Setenv("APP_ENV", "development")
		t.Setenv("JWT_SECRET", "")

		secret, err := resolveJWTSecret()
		if err != nil {
			t.Fatalf("resolveJWTSecret() unexpected error = %v", err)
		}
		if got := string(secret); got != "default-secret-key-change-me" {
			t.Fatalf("resolveJWTSecret() = %q, want %q", got, "default-secret-key-change-me")
		}
	})
}

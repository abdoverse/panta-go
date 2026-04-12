package main

import (
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestNormalizeAllowedOrigin(t *testing.T) {
	t.Parallel()

	tests := []struct {
		name   string
		origin string
		want   string
		ok     bool
	}{
		{name: "accepts https origin", origin: " https://example.com ", want: "https://example.com", ok: true},
		{name: "rejects path", origin: "https://example.com/path", ok: false},
		{name: "rejects query", origin: "https://example.com?debug=true", ok: false},
		{name: "rejects unsupported scheme", origin: "ftp://example.com", ok: false},
	}

	for _, tt := range tests {
		tt := tt
		t.Run(tt.name, func(t *testing.T) {
			t.Parallel()

			got, ok := normalizeAllowedOrigin(tt.origin)
			if ok != tt.ok {
				t.Fatalf("normalizeAllowedOrigin() ok = %v, want %v", ok, tt.ok)
			}
			if got != tt.want {
				t.Fatalf("normalizeAllowedOrigin() = %q, want %q", got, tt.want)
			}
		})
	}
}

func TestApplyCORSHeaders(t *testing.T) {
	t.Parallel()

	originalOrigins := configuredAllowedOrigins
	configuredAllowedOrigins = map[string]struct{}{
		"https://mobile.panta.app": {},
	}
	t.Cleanup(func() {
		configuredAllowedOrigins = originalOrigins
	})

	t.Run("allows same-origin requests", func(t *testing.T) {
		t.Parallel()

		req := httptest.NewRequest(http.MethodGet, "http://api.panta.local/health", nil)
		req.Host = "api.panta.local"
		req.Header.Set("Origin", "http://api.panta.local")

		recorder := httptest.NewRecorder()
		if ok := applyCORSHeaders(recorder, req); !ok {
			t.Fatalf("applyCORSHeaders() = false, want true")
		}

		if got := recorder.Header().Get("Access-Control-Allow-Origin"); got != "http://api.panta.local" {
			t.Fatalf("Access-Control-Allow-Origin = %q, want %q", got, "http://api.panta.local")
		}
	})

	t.Run("rejects origins outside the allow list", func(t *testing.T) {
		t.Parallel()

		req := httptest.NewRequest(http.MethodGet, "http://api.panta.local/health", nil)
		req.Host = "api.panta.local"
		req.Header.Set("Origin", "https://evil.example")

		if ok := applyCORSHeaders(httptest.NewRecorder(), req); ok {
			t.Fatalf("applyCORSHeaders() = true, want false")
		}
	})

	t.Run("allows configured cross-origin requests", func(t *testing.T) {
		t.Parallel()

		req := httptest.NewRequest(http.MethodGet, "http://api.panta.local/health", nil)
		req.Host = "api.panta.local"
		req.Header.Set("Origin", "https://mobile.panta.app")

		recorder := httptest.NewRecorder()
		if ok := applyCORSHeaders(recorder, req); !ok {
			t.Fatalf("applyCORSHeaders() = false, want true")
		}
	})
}

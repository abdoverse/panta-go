package main

import (
	"context"
	"encoding/json"
	"log"
	"net/http"
	"strings"
)

func registerRealtimeRoutes(mux *http.ServeMux) {
	mux.HandleFunc("/api/v1/ws", handleWebSocket)
}

func broadcastRequestUpdate(ctx context.Context, request RecyclingRequest) {
	if hub == nil {
		return
	}

	clientRequest := request
	if err := enrichRequestForClient(ctx, &clientRequest); err != nil {
		log.Printf("Failed to enrich request %s for websocket update: %v", request.ID, err)
		return
	}

	payload, err := json.Marshal(map[string]interface{}{
		"type":    "request-updated",
		"request": clientRequest,
	})
	if err != nil {
		log.Printf("Failed to marshal request update for %s: %v", request.ID, err)
		return
	}

	hub.broadcast <- payload
}

func handleWebSocket(w http.ResponseWriter, r *http.Request) {
	tokenString := strings.TrimSpace(r.URL.Query().Get("token"))
	if tokenString == "" {
		authHeader := r.Header.Get("Authorization")
		if strings.HasPrefix(authHeader, "Bearer ") {
			tokenString = strings.TrimPrefix(authHeader, "Bearer ")
		}
	}
	if tokenString == "" {
		http.Error(w, "Unauthorized: missing token", http.StatusUnauthorized)
		return
	}

	if _, err := validateToken(tokenString); err != nil {
		http.Error(w, "Unauthorized: invalid token", http.StatusUnauthorized)
		return
	}

	serveWs(hub, w, r)
}

package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"strings"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/feature/dynamodb/attributevalue"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb/types"
)

func registerRealtimeRoutes(mux *http.ServeMux) {
	mux.HandleFunc("/api/v1/ws", handleWebSocket)
	mux.HandleFunc("/api/v1/chat", authMiddleware(handleChat))
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

func broadcastChatMessage(ctx context.Context, message ChatMessage) {
	if hub == nil {
		return
	}

	payload, err := json.Marshal(map[string]interface{}{
		"type":    "chat-message",
		"message": message,
	})
	if err != nil {
		log.Printf("Failed to marshal chat message %s: %v", message.ID, err)
		return
	}

	hub.broadcast <- payload
}

func handleChat(w http.ResponseWriter, r *http.Request) {
	claims, ok := currentClaims(r)
	if !ok || claims == nil {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}

	switch r.Method {
	case http.MethodGet:
		requestID := strings.TrimSpace(r.URL.Query().Get("requestId"))
		if requestID == "" {
			http.Error(w, "requestId is required", http.StatusBadRequest)
			return
		}

		out, err := svc.GetItem(r.Context(), &dynamodb.GetItemInput{
			TableName: aws.String(tableName),
			Key: map[string]types.AttributeValue{
				"id": &types.AttributeValueMemberS{Value: requestID},
			},
		})
		if err != nil || len(out.Item) == 0 {
			http.Error(w, "Request not found", http.StatusNotFound)
			return
		}

		var req RecyclingRequest
		if err := attributevalue.UnmarshalMap(out.Item, &req); err != nil {
			http.Error(w, "Failed to parse request", http.StatusInternalServerError)
			return
		}

		if req.Messages == nil {
			req.Messages = []ChatMessage{}
		}

		jsonResponse(w, http.StatusOK, map[string]interface{}{
			"requestId": req.ID,
			"messages":  req.Messages,
		})

	case http.MethodPost:
		var payload SendChatMessagePayload
		if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
			http.Error(w, "Invalid request payload", http.StatusBadRequest)
			return
		}

		payload.RequestID = strings.TrimSpace(payload.RequestID)
		payload.Text = strings.TrimSpace(payload.Text)
		if payload.RequestID == "" || payload.Text == "" {
			http.Error(w, "requestId and text cannot be empty", http.StatusBadRequest)
			return
		}

		out, err := svc.GetItem(r.Context(), &dynamodb.GetItemInput{
			TableName: aws.String(tableName),
			Key: map[string]types.AttributeValue{
				"id": &types.AttributeValueMemberS{Value: payload.RequestID},
			},
		})
		if err != nil || len(out.Item) == 0 {
			http.Error(w, "Request not found", http.StatusNotFound)
			return
		}

		var req RecyclingRequest
		if err := attributevalue.UnmarshalMap(out.Item, &req); err != nil {
			http.Error(w, "Failed to parse request", http.StatusInternalServerError)
			return
		}

		senderID := claims.requestOwnerID()
		if req.CreatorID != "" && senderID != req.CreatorID && senderID != req.HelperID {
			http.Error(w, "Forbidden: not a participant of this request", http.StatusForbidden)
			return
		}

		senderName := "Recycler"
		if claims.Role == "helper" {
			senderName = "Helper"
		} else if claims.DisplayName != "" {
			senderName = claims.DisplayName
		}

		newMsg := ChatMessage{
			ID:         fmt.Sprintf("msg-%d", time.Now().UnixNano()),
			RequestID:  payload.RequestID,
			SenderID:   senderID,
			SenderRole: claims.Role,
			SenderName: senderName,
			Text:       payload.Text,
			IsPreset:   payload.IsPreset,
			CreatedAt:  time.Now().UTC().Format(time.RFC3339),
		}

		msgAV, err := attributevalue.Marshal(newMsg)
		if err != nil {
			http.Error(w, "Failed to serialize message", http.StatusInternalServerError)
			return
		}

		_, err = svc.UpdateItem(r.Context(), &dynamodb.UpdateItemInput{
			TableName: aws.String(tableName),
			Key: map[string]types.AttributeValue{
				"id": &types.AttributeValueMemberS{Value: payload.RequestID},
			},
			UpdateExpression: aws.String("SET #msgs = list_append(if_not_exists(#msgs, :empty_list), :new_msg)"),
			ExpressionAttributeNames: map[string]string{
				"#msgs": "messages",
			},
			ExpressionAttributeValues: map[string]types.AttributeValue{
				":empty_list": &types.AttributeValueMemberL{Value: []types.AttributeValue{}},
				":new_msg":    &types.AttributeValueMemberL{Value: []types.AttributeValue{msgAV}},
			},
		})
		if err != nil {
			log.Printf("Failed to append chat message to DynamoDB: %v", err)
			http.Error(w, "Failed to save message", http.StatusInternalServerError)
			return
		}

		broadcastChatMessage(r.Context(), newMsg)
		jsonResponse(w, http.StatusCreated, newMsg)

	default:
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
	}
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

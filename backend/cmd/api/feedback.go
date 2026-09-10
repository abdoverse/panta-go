package main

import (
	"encoding/json"
	"net/http"
	"strings"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/feature/dynamodb/attributevalue"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb"
	"github.com/google/uuid"
)

type feedbackSubmission struct {
	ID        string `dynamodbav:"id" json:"id"`
	Type      string `dynamodbav:"type" json:"type"`
	UserID    string `dynamodbav:"userId" json:"userId"`
	Category  string `dynamodbav:"category" json:"category"`
	Message   string `dynamodbav:"message" json:"message"`
	Contact   bool   `dynamodbav:"contactRequested" json:"contactRequested"`
	CreatedAt string `dynamodbav:"createdAt" json:"createdAt"`
}

func registerFeedbackRoutes(mux *http.ServeMux) {
	mux.HandleFunc("/api/v1/feedback", authMiddleware(handleFeedback))
	mux.HandleFunc("/api/v1/admin/feedback", authMiddleware(handleAdminFeedback))
}

func handleAdminFeedback(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}
	claims, ok := currentClaims(r)
	if !ok || claims == nil || !claims.isAdmin() {
		http.Error(w, "Forbidden: admin access required", http.StatusForbidden)
		return
	}
	items := make([]feedbackSubmission, 0)
	if svc != nil && tableName != "" {
		out, err := svc.Scan(r.Context(), &dynamodb.ScanInput{
			TableName: aws.String(tableName),
			Limit:     aws.Int32(200),
		})
		if err != nil {
			http.Error(w, "Failed to load feedback", http.StatusInternalServerError)
			return
		}
		{
			var stored []feedbackSubmission
			if err := attributevalue.UnmarshalListOfMaps(out.Items, &stored); err != nil {
				http.Error(w, "Failed to decode feedback", http.StatusInternalServerError)
				return
			}
			for _, item := range stored {
				if item.Type == "feedback" {
					items = append(items, item)
				}
			}
		}
	}
	for left, right := 0, len(items)-1; left < right; left, right = left+1, right-1 {
		items[left], items[right] = items[right], items[left]
	}
	jsonResponse(w, http.StatusOK, map[string]interface{}{"feedback": items})
}

func handleFeedback(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}
	claims, ok := currentClaims(r)
	if !ok || claims == nil {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}
	var payload struct {
		Category string `json:"category"`
		Message  string `json:"message"`
		Contact  bool   `json:"contactRequested"`
	}
	if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
		http.Error(w, "Invalid request payload", http.StatusBadRequest)
		return
	}
	payload.Category = strings.TrimSpace(payload.Category)
	payload.Message = strings.TrimSpace(payload.Message)
	if payload.Category == "" || payload.Message == "" || len(payload.Message) > 4000 {
		http.Error(w, "category and a message up to 4000 characters are required", http.StatusBadRequest)
		return
	}
	feedback := feedbackSubmission{
		ID: "feedback-" + uuid.NewString(), Type: "feedback", UserID: claims.requestOwnerID(),
		Category: payload.Category, Message: payload.Message, Contact: payload.Contact,
		CreatedAt: time.Now().UTC().Format(time.RFC3339),
	}
	item, err := attributevalue.MarshalMap(feedback)
	if err != nil || svc == nil || tableName == "" {
		http.Error(w, "Feedback storage is unavailable", http.StatusInternalServerError)
		return
	}
	if _, err := svc.PutItem(r.Context(), &dynamodb.PutItemInput{TableName: aws.String(tableName), Item: item}); err != nil {
		http.Error(w, "Failed to save feedback", http.StatusInternalServerError)
		return
	}
	jsonResponse(w, http.StatusCreated, feedback)
}

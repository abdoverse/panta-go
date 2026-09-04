package main

import (
	"context"
	"encoding/json"
	"log"
	"net/http"
	"strings"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/feature/dynamodb/attributevalue"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb/types"
)

type savedAddressesPayload struct {
	SavedAddresses []SavedAddress `json:"savedAddresses"`
}

type requestTemplatesPayload struct {
	Templates []RequestTemplate `json:"templates"`
}

func handleSavedAddresses(w http.ResponseWriter, r *http.Request) {
	claims, ok := currentClaims(r)
	if !ok {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}

	switch r.Method {
	case http.MethodGet:
		preferences, err := loadRequestPreferences(r.Context(), claims.requestOwnerID())
		if err != nil {
			log.Printf("Failed to load saved addresses: %v", err)
			jsonResponse(w, http.StatusInternalServerError, map[string]string{"error": "Failed to load saved addresses"})
			return
		}
		jsonResponse(w, http.StatusOK, savedAddressesPayload{SavedAddresses: preferences.SavedAddresses})
	case http.MethodPut:
		var payload savedAddressesPayload
		if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
			jsonResponse(w, http.StatusBadRequest, map[string]string{"error": "Invalid payload"})
			return
		}
		preferences, err := loadRequestPreferences(r.Context(), claims.requestOwnerID())
		if err != nil {
			log.Printf("Failed to load saved addresses before update: %v", err)
			jsonResponse(w, http.StatusInternalServerError, map[string]string{"error": "Failed to update saved addresses"})
			return
		}
		preferences.SavedAddresses = payload.SavedAddresses
		if err := saveRequestPreferences(r.Context(), claims.requestOwnerID(), preferences); err != nil {
			log.Printf("Failed to save addresses: %v", err)
			jsonResponse(w, http.StatusInternalServerError, map[string]string{"error": "Failed to save saved addresses"})
			return
		}
		jsonResponse(w, http.StatusOK, savedAddressesPayload{SavedAddresses: preferences.SavedAddresses})
	default:
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
	}
}

func handleRequestTemplates(w http.ResponseWriter, r *http.Request) {
	claims, ok := currentClaims(r)
	if !ok {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}

	switch r.Method {
	case http.MethodGet:
		preferences, err := loadRequestPreferences(r.Context(), claims.requestOwnerID())
		if err != nil {
			log.Printf("Failed to load request templates: %v", err)
			jsonResponse(w, http.StatusInternalServerError, map[string]string{"error": "Failed to load request templates"})
			return
		}
		jsonResponse(w, http.StatusOK, requestTemplatesPayload{Templates: preferences.Templates})
	case http.MethodPut:
		var payload requestTemplatesPayload
		if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
			jsonResponse(w, http.StatusBadRequest, map[string]string{"error": "Invalid payload"})
			return
		}
		preferences, err := loadRequestPreferences(r.Context(), claims.requestOwnerID())
		if err != nil {
			log.Printf("Failed to load templates before update: %v", err)
			jsonResponse(w, http.StatusInternalServerError, map[string]string{"error": "Failed to update request templates"})
			return
		}
		preferences.Templates = payload.Templates
		if err := saveRequestPreferences(r.Context(), claims.requestOwnerID(), preferences); err != nil {
			log.Printf("Failed to save request templates: %v", err)
			jsonResponse(w, http.StatusInternalServerError, map[string]string{"error": "Failed to save request templates"})
			return
		}
		jsonResponse(w, http.StatusOK, requestTemplatesPayload{Templates: preferences.Templates})
	default:
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
	}
}

func loadRequestPreferences(ctx context.Context, ownerID string) (RequestPreferences, error) {
	out, err := svc.GetItem(ctx, &dynamodb.GetItemInput{
		TableName: aws.String(tableName),
		Key: map[string]types.AttributeValue{
			"id": &types.AttributeValueMemberS{Value: requestPreferencesID(ownerID)},
		},
	})
	if err != nil {
		return RequestPreferences{}, err
	}
	if len(out.Item) == 0 {
		return RequestPreferences{ID: requestPreferencesID(ownerID)}, nil
	}

	var preferences RequestPreferences
	if err := attributevalue.UnmarshalMap(out.Item, &preferences); err != nil {
		return RequestPreferences{}, err
	}
	if strings.TrimSpace(preferences.ID) == "" {
		preferences.ID = requestPreferencesID(ownerID)
	}
	return preferences, nil
}

func saveRequestPreferences(ctx context.Context, ownerID string, preferences RequestPreferences) error {
	preferences.ID = requestPreferencesID(ownerID)
	item, err := attributevalue.MarshalMap(preferences)
	if err != nil {
		return err
	}
	_, err = svc.PutItem(ctx, &dynamodb.PutItemInput{
		TableName: aws.String(tableName),
		Item:      item,
	})
	return err
}

func requestPreferencesID(ownerID string) string {
	return "request-preferences#" + ownerID
}

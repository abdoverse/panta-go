package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"strings"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/feature/dynamodb/attributevalue"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb/types"
)

type requestIDPayload struct {
	ID string `json:"id"`
}

type requestRatingPayload struct {
	ID      string  `json:"id"`
	Rating  float64 `json:"rating"`
	Comment string  `json:"comment"`
}

func registerRequestRoutes(mux *http.ServeMux) {
	mux.HandleFunc("/api/v1/requests", authMiddleware(handleRequests))
	mux.HandleFunc("/api/v1/requests/accept", authMiddleware(handleAcceptRequest))
	mux.HandleFunc("/api/v1/requests/cancel", authMiddleware(handleCancelRequest))
	mux.HandleFunc("/api/v1/requests/complete", authMiddleware(handleCompleteRequest))
	mux.HandleFunc("/api/v1/requests/rate", authMiddleware(handleRateRequest))
}

func handleRequests(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Access-Control-Allow-Origin", "*")

	switch r.Method {
	case http.MethodGet:
		handleListRequests(w, r)
	case http.MethodPost:
		handleCreateRequest(w, r)
	default:
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
	}
}

func handleListRequests(w http.ResponseWriter, r *http.Request) {
	out, err := svc.Scan(context.TODO(), &dynamodb.ScanInput{
		TableName: aws.String(tableName),
	})
	if err != nil {
		log.Printf("Failed to scan table: %v", err)
		jsonResponse(w, http.StatusInternalServerError, map[string]string{"error": "Failed to fetch requests"})
		return
	}

	var requests []RecyclingRequest
	if err := attributevalue.UnmarshalListOfMaps(out.Items, &requests); err != nil {
		log.Printf("Failed to unmarshal storage: %v", err)
		jsonResponse(w, http.StatusInternalServerError, map[string]string{"error": "Failed to parse data"})
		return
	}

	for i := range requests {
		resolvedURL, err := resolveImageURL(r.Context(), requests[i].ImageUrl)
		if err != nil {
			log.Printf("Failed to resolve image URL for request %s: %v", requests[i].ID, err)
			jsonResponse(w, http.StatusInternalServerError, map[string]string{"error": "Failed to resolve request images"})
			return
		}
		requests[i].ImageUrl = resolvedURL
	}

	jsonResponse(w, http.StatusOK, requests)
}

func handleCreateRequest(w http.ResponseWriter, r *http.Request) {
	claims, ok := currentClaims(r)
	if !ok {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}

	var req RecyclingRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		jsonResponse(w, http.StatusBadRequest, map[string]string{"error": fmt.Sprintf("Invalid payload: %v", err)})
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
			jsonResponse(w, http.StatusBadRequest, map[string]string{"error": "Failed to process request image"})
			return
		}
		req.ImageUrl = imageReference
	}
	req.Status = "pending"

	item, err := attributevalue.MarshalMap(req)
	if err != nil {
		jsonResponse(w, http.StatusInternalServerError, map[string]string{"error": "Failed to marshal item"})
		return
	}

	_, err = svc.PutItem(context.TODO(), &dynamodb.PutItemInput{
		TableName: aws.String(tableName),
		Item:      item,
	})
	if err != nil {
		log.Printf("Failed to put item: %v", err)
		jsonResponse(w, http.StatusInternalServerError, map[string]string{"error": "Failed to save request"})
		return
	}

	if err := enrichRequestForClient(r.Context(), &req); err != nil {
		log.Printf("Failed to resolve image URL for created request %s: %v", req.ID, err)
		jsonResponse(w, http.StatusInternalServerError, map[string]string{"error": "Failed to resolve request image"})
		return
	}

	broadcastRequestUpdate(r.Context(), req)
	jsonResponse(w, http.StatusCreated, req)
}

func handleAcceptRequest(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	claims, ok := currentClaims(r)
	if !ok {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}

	var payload requestIDPayload
	if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
		jsonResponse(w, http.StatusBadRequest, map[string]string{"error": "Invalid payload"})
		return
	}

	out, err := svc.UpdateItem(context.TODO(), &dynamodb.UpdateItemInput{
		TableName: aws.String(tableName),
		Key: map[string]types.AttributeValue{
			"id": &types.AttributeValueMemberS{Value: payload.ID},
		},
		UpdateExpression:         aws.String("SET #status = :accepted, helperId = :helperId"),
		ConditionExpression:      aws.String("#status = :pending"),
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
			jsonResponse(w, http.StatusBadRequest, map[string]string{"error": "Request already accepted or not found"})
		} else {
			jsonResponse(w, http.StatusInternalServerError, map[string]string{"error": "Failed to update request"})
		}
		return
	}

	var updatedReq RecyclingRequest
	if err := attributevalue.UnmarshalMap(out.Attributes, &updatedReq); err != nil {
		log.Printf("Failed to parse accepted request: %v", err)
		jsonResponse(w, http.StatusInternalServerError, map[string]string{"error": "Failed to parse request update"})
		return
	}

	if updatedReq.CreatorDeviceToken != "" {
		go sendPushNotification(
			updatedReq.CreatorDeviceToken,
			"Request Accepted! 🚛",
			fmt.Sprintf("%s has accepted your request and is on the way.", claims.notificationName()),
		)
	}

	respondWithUpdatedRequest(w, r, updatedReq, "accepted")
}

func handleCancelRequest(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	claims, ok := currentClaims(r)
	if !ok {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}

	var payload requestIDPayload
	if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
		jsonResponse(w, http.StatusBadRequest, map[string]string{"error": "Invalid payload"})
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
			":accepted":  &types.AttributeValueMemberS{Value: "accepted"},
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
			jsonResponse(w, http.StatusBadRequest, map[string]string{"error": "Request is no longer assigned to you"})
		} else {
			jsonResponse(w, http.StatusInternalServerError, map[string]string{"error": "Failed to cancel pickup"})
		}
		return
	}

	var updatedReq RecyclingRequest
	if err := attributevalue.UnmarshalMap(out.Attributes, &updatedReq); err != nil {
		log.Printf("Failed to parse cancelled request: %v", err)
		jsonResponse(w, http.StatusInternalServerError, map[string]string{"error": "Failed to parse request update"})
		return
	}

	if updatedReq.CreatorDeviceToken != "" {
		go sendPushNotification(
			updatedReq.CreatorDeviceToken,
			"Pickup Cancelled",
			fmt.Sprintf("%s can no longer complete your pickup. Your request is available for another helper again.", claims.notificationName()),
		)
	}

	respondWithUpdatedRequest(w, r, updatedReq, "cancelled")
}

func handleCompleteRequest(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	claims, ok := currentClaims(r)
	if !ok {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}

	var payload requestIDPayload
	if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
		jsonResponse(w, http.StatusBadRequest, map[string]string{"error": "Invalid payload"})
		return
	}

	out, err := svc.UpdateItem(context.TODO(), &dynamodb.UpdateItemInput{
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
		ReturnValues: types.ReturnValueAllNew,
	})
	if err != nil {
		log.Printf("Failed to complete request: %v", err)
		var cfe *types.ConditionalCheckFailedException
		if errorIs(err, &cfe) {
			jsonResponse(w, http.StatusBadRequest, map[string]string{"error": "Request is no longer assigned to you"})
		} else {
			jsonResponse(w, http.StatusInternalServerError, map[string]string{"error": "Failed to update request"})
		}
		return
	}

	var updatedReq RecyclingRequest
	if err := attributevalue.UnmarshalMap(out.Attributes, &updatedReq); err != nil {
		log.Printf("Failed to parse completed request: %v", err)
		jsonResponse(w, http.StatusInternalServerError, map[string]string{"error": "Failed to parse request update"})
		return
	}

	respondWithUpdatedRequest(w, r, updatedReq, "completed")
}

func handleRateRequest(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var payload requestRatingPayload
	if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
		jsonResponse(w, http.StatusBadRequest, map[string]string{"error": "Invalid payload"})
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
		jsonResponse(w, http.StatusInternalServerError, map[string]string{"error": "Failed to update request"})
		return
	}

	if hub != nil {
		hub.broadcast <- []byte(`{"type":"refresh"}`)
	}

	jsonResponse(w, http.StatusOK, map[string]string{"status": "rated"})
}

func respondWithUpdatedRequest(w http.ResponseWriter, r *http.Request, updatedReq RecyclingRequest, action string) {
	if err := enrichRequestForClient(r.Context(), &updatedReq); err != nil {
		log.Printf("Failed to resolve image URL for %s request %s: %v", action, updatedReq.ID, err)
		jsonResponse(w, http.StatusInternalServerError, map[string]string{"error": "Failed to resolve request image"})
		return
	}

	broadcastRequestUpdate(r.Context(), updatedReq)
	jsonResponse(w, http.StatusOK, updatedReq)
}

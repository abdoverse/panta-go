package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"sort"
	"strings"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/feature/dynamodb/attributevalue"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb/types"
)

const (
	requestsByCreatorIndexName = "requests-by-creator"
	requestsByStatusIndexName  = "requests-by-status"
	requestsByHelperIndexName  = "requests-by-helper"
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
	claims, ok := currentClaims(r)
	if !ok {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}

	requests, err := listRequestsForClaims(r.Context(), claims)
	if err != nil {
		log.Printf("Failed to load accessible requests: %v", err)
		jsonResponse(w, http.StatusInternalServerError, map[string]string{"error": "Failed to fetch requests"})
		return
	}

	sort.SliceStable(requests, func(i, j int) bool {
		if requests[i].ScheduledFrom.Equal(requests[j].ScheduledFrom) {
			return requests[i].ID < requests[j].ID
		}
		return requests[i].ScheduledFrom.Before(requests[j].ScheduledFrom)
	})

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

func listRequestsForClaims(ctx context.Context, claims *Claims) ([]RecyclingRequest, error) {
	if claims.isHelper() {
		return listHelperAccessibleRequests(ctx, claims.helperID())
	}
	return listCreatorRequests(ctx, claims.requestOwnerID())
}

func listCreatorRequests(ctx context.Context, creatorID string) ([]RecyclingRequest, error) {
	return queryRequests(ctx, &dynamodb.QueryInput{
		TableName:              aws.String(tableName),
		IndexName:              aws.String(requestsByCreatorIndexName),
		KeyConditionExpression: aws.String("creatorId = :creatorId"),
		ExpressionAttributeValues: map[string]types.AttributeValue{
			":creatorId": &types.AttributeValueMemberS{Value: creatorID},
		},
	})
}

func listHelperAccessibleRequests(ctx context.Context, helperID string) ([]RecyclingRequest, error) {
	pendingRequests, err := queryRequests(ctx, &dynamodb.QueryInput{
		TableName:              aws.String(tableName),
		IndexName:              aws.String(requestsByStatusIndexName),
		KeyConditionExpression: aws.String("#status = :pending"),
		ExpressionAttributeNames: map[string]string{
			"#status": "status",
		},
		ExpressionAttributeValues: map[string]types.AttributeValue{
			":pending": &types.AttributeValueMemberS{Value: "pending"},
		},
	})
	if err != nil {
		return nil, err
	}

	assignedRequests, err := queryRequests(ctx, &dynamodb.QueryInput{
		TableName:              aws.String(tableName),
		IndexName:              aws.String(requestsByHelperIndexName),
		KeyConditionExpression: aws.String("helperId = :helperId"),
		ExpressionAttributeValues: map[string]types.AttributeValue{
			":helperId": &types.AttributeValueMemberS{Value: helperID},
		},
	})
	if err != nil {
		return nil, err
	}

	return mergeRequestsByID(pendingRequests, assignedRequests), nil
}

func queryRequests(ctx context.Context, input *dynamodb.QueryInput) ([]RecyclingRequest, error) {
	var (
		requests []RecyclingRequest
		startKey map[string]types.AttributeValue
	)

	for {
		queryInput := *input
		queryInput.ExclusiveStartKey = startKey

		out, err := svc.Query(ctx, &queryInput)
		if err != nil {
			return nil, err
		}

		var batch []RecyclingRequest
		if err := attributevalue.UnmarshalListOfMaps(out.Items, &batch); err != nil {
			return nil, err
		}
		requests = append(requests, batch...)

		if len(out.LastEvaluatedKey) == 0 {
			return requests, nil
		}
		startKey = out.LastEvaluatedKey
	}
}

func mergeRequestsByID(groups ...[]RecyclingRequest) []RecyclingRequest {
	merged := make([]RecyclingRequest, 0)
	seen := make(map[string]struct{})

	for _, group := range groups {
		for _, request := range group {
			if _, ok := seen[request.ID]; ok {
				continue
			}
			seen[request.ID] = struct{}{}
			merged = append(merged, request)
		}
	}

	return merged
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
	req.CreatorID = claims.requestOwnerID()
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

	claims, ok := currentClaims(r)
	if !ok {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
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
		UpdateExpression:    aws.String("SET isRated = :true, rating = :r, ratingComment = :c"),
		ConditionExpression: aws.String("(attribute_not_exists(creatorId) OR creatorId = :creatorId) AND #status = :pickedUp AND (attribute_not_exists(isRated) OR isRated = :false)"),
		ExpressionAttributeNames: map[string]string{
			"#status": "status",
		},
		ExpressionAttributeValues: map[string]types.AttributeValue{
			":true":      &types.AttributeValueMemberBOOL{Value: true},
			":false":     &types.AttributeValueMemberBOOL{Value: false},
			":r":         &types.AttributeValueMemberN{Value: fmt.Sprintf("%f", payload.Rating)},
			":c":         &types.AttributeValueMemberS{Value: payload.Comment},
			":creatorId": &types.AttributeValueMemberS{Value: claims.requestOwnerID()},
			":pickedUp":  &types.AttributeValueMemberS{Value: "pickedUp"},
		},
	})
	if err != nil {
		log.Printf("Failed to rate request: %v", err)
		var cfe *types.ConditionalCheckFailedException
		if errorIs(err, &cfe) {
			jsonResponse(w, http.StatusBadRequest, map[string]string{"error": "Request is not eligible for rating"})
		} else {
			jsonResponse(w, http.StatusInternalServerError, map[string]string{"error": "Failed to update request"})
		}
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

package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"sort"
	"strings"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/feature/dynamodb/attributevalue"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb/types"
	"github.com/google/uuid"
)

const (
	requestsByCreatorIndexName = "requests-by-creator"
	requestsByStatusIndexName  = "requests-by-status"
	requestsByHelperIndexName  = "requests-by-helper"
)

func registerRequestRoutes(mux *http.ServeMux) {
	mux.HandleFunc("/api/v1/requests", authMiddleware(handleRequests))
	mux.HandleFunc("/api/v1/requests/templates", authMiddleware(handleRequestTemplates))
	mux.HandleFunc("/api/v1/requests/saved-addresses", authMiddleware(handleSavedAddresses))
	mux.HandleFunc("/api/v1/requests/accept", authMiddleware(handleAcceptRequest))
	mux.HandleFunc("/api/v1/requests/cancel", authMiddleware(handleCancelRequest))
	mux.HandleFunc("/api/v1/requests/complete", authMiddleware(handleCompleteRequest))
	mux.HandleFunc("/api/v1/requests/location", authMiddleware(handleUpdateLocation))
	mux.HandleFunc("/api/v1/requests/rate", authMiddleware(handleRateRequest))
	mux.HandleFunc("/api/v1/requests/arrived", authMiddleware(handleArrivedAtDoor))
	mux.HandleFunc("/api/v1/users/device-token", authMiddleware(handleRegisterDeviceToken))
	mux.HandleFunc("/api/v1/analytics", authMiddleware(handleAnalytics))
	mux.HandleFunc("/api/v1/market/config", authMiddleware(handleMarketConfig))
	mux.HandleFunc("/api/v1/demo/seed", handleDemoSeed)
}

func handleRequests(w http.ResponseWriter, r *http.Request) {
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

	sort.Slice(requests, func(i, j int) bool {
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
		if len(requests[i].Messages) > 0 {
			requests[i].Messages = sanitizeAndDecryptMessages(requests[i].Messages, requests[i].ID)
		}
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
	returnableRequests := make([]RecyclingRequest, 0)
	for _, status := range helperPoolCandidateStatuses() {
		requestsForStatus, err := queryRequests(ctx, &dynamodb.QueryInput{
			TableName:              aws.String(tableName),
			IndexName:              aws.String(requestsByStatusIndexName),
			KeyConditionExpression: aws.String("#status = :status"),
			ExpressionAttributeNames: map[string]string{
				"#status": "status",
			},
			ExpressionAttributeValues: map[string]types.AttributeValue{
				":status": &types.AttributeValueMemberS{Value: status},
			},
		})
		if err != nil {
			return nil, err
		}
		returnableRequests = mergeRequestsByID(returnableRequests, requestsForStatus)
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

	return mergeRequestsByID(
		filterHelperVisiblePendingRequests(returnableRequests, helperID),
		filterHelperAssignedRequests(assignedRequests, helperID),
	), nil
}

func listHelperAssignedRequests(ctx context.Context, helperID string) ([]RecyclingRequest, error) {
	return queryRequests(ctx, &dynamodb.QueryInput{
		TableName:              aws.String(tableName),
		IndexName:              aws.String(requestsByHelperIndexName),
		KeyConditionExpression: aws.String("helperId = :helperId"),
		ExpressionAttributeValues: map[string]types.AttributeValue{
			":helperId": &types.AttributeValueMemberS{Value: helperID},
		},
	})
}

func helperPoolCandidateStatuses() []string {
	return []string{"pending"}
}

func filterHelperVisiblePendingRequests(requests []RecyclingRequest, helperID string) []RecyclingRequest {
	filtered := make([]RecyclingRequest, 0, len(requests))
	for _, request := range requests {
		if request.Status != "pending" {
			continue
		}
		if helperHasCancelledRequest(request.CanceledHelperIDs, helperID) {
			continue
		}
		request.HelperID = ""
		filtered = append(filtered, request)
	}
	return filtered
}

func helperHasCancelledRequest(cancelledHelperIDs []string, helperID string) bool {
	normalizedHelperID := strings.TrimSpace(helperID)
	if normalizedHelperID == "" {
		return false
	}
	for _, cancelledHelperID := range cancelledHelperIDs {
		if strings.EqualFold(strings.TrimSpace(cancelledHelperID), normalizedHelperID) {
			return true
		}
	}
	return false
}

func filterHelperAssignedRequests(requests []RecyclingRequest, helperID string) []RecyclingRequest {
	filtered := make([]RecyclingRequest, 0, len(requests))
	normalizedHelperID := strings.TrimSpace(helperID)
	for _, request := range requests {
		if !strings.EqualFold(strings.TrimSpace(request.HelperID), normalizedHelperID) {
			continue
		}
		if request.Status != "accepted" && request.Status != "pickedUp" {
			continue
		}
		filtered = append(filtered, request)
	}
	return filtered
}

func normalizeRequest(req *RecyclingRequest) {
	if req.CreatorID != "" {
		if _, err := uuid.Parse(req.CreatorID); err != nil {
			if req.CreatorName == "" {
				req.CreatorName = req.CreatorID
			}
			req.CreatorID = userUUID(req.CreatorID)
		}
	}
	if req.HelperID != "" {
		if _, err := uuid.Parse(req.HelperID); err != nil {
			if req.HelperName == "" {
				req.HelperName = req.HelperID
			}
			req.HelperID = userUUID(req.HelperID)
		}
	}
	if req.Market == "" {
		req.Market = "SE"
	}
	if req.Currency == "" {
		mCfg := getMarketConfig(req.Market)
		req.Currency = mCfg.Currency
		req.CurrencySymbol = mCfg.CurrencySymbol
	}
	if req.CurrencySymbol == "" {
		mCfg := getMarketConfig(req.Market)
		req.CurrencySymbol = mCfg.CurrencySymbol
	}
}

func queryRequests(ctx context.Context, input *dynamodb.QueryInput) ([]RecyclingRequest, error) {
	out, err := svc.Query(ctx, input)
	if err != nil {
		return nil, err
	}

	requests := make([]RecyclingRequest, 0, len(out.Items))
	for _, item := range out.Items {
		var req RecyclingRequest
		if err := attributevalue.UnmarshalMap(item, &req); err != nil {
			return nil, err
		}
		normalizeRequest(&req)
		requests = append(requests, req)
	}
	return requests, nil
}

func mergeRequestsByID(groups ...[]RecyclingRequest) []RecyclingRequest {
	seen := make(map[string]struct{})
	merged := make([]RecyclingRequest, 0)

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

	market := strings.TrimSpace(r.URL.Query().Get("market"))
	if market == "" && req.Market != "" {
		market = req.Market
	}
	if market == "" {
		market = "SE"
	}
	marketConfig := getMarketConfig(market)

	creatorRequests, err := listCreatorRequests(r.Context(), claims.requestOwnerID())
	if err == nil {
		activeCount := 0
		for _, cr := range creatorRequests {
			if cr.Status == "pending" || cr.Status == "accepted" {
				activeCount++
			}
		}
		if activeCount >= marketConfig.MaxActiveRequestsPerRecycler {
			jsonResponse(w, http.StatusConflict, map[string]interface{}{
				"error":   fmt.Sprintf("Personal active request limit reached (%d/%d active requests). To prevent spam, please complete or cancel an existing pickup before posting a new one.", activeCount, marketConfig.MaxActiveRequestsPerRecycler),
				"code":    "ACTIVE_LIMIT_REACHED",
				"limit":   marketConfig.MaxActiveRequestsPerRecycler,
				"current": activeCount,
			})
			return
		}
	}

	req.ID = newRequestID()
	req.CreatorID = claims.requestOwnerID()
	req.CreatorName = claims.notificationName()
	if req.Market == "" {
		req.Market = marketConfig.MarketCode
	}
	if req.Currency == "" {
		req.Currency = marketConfig.Currency
	}
	if req.CurrencySymbol == "" {
		req.CurrencySymbol = marketConfig.CurrencySymbol
	}
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
	if req.SplitPercentage <= 0 || req.SplitPercentage > 100 {
		req.SplitPercentage = 70.0
	}
	req.Status = "pending"
	req.CreatorBankIdVerified = claims.BankIdVerified || isUserBankIdVerified(claims.requestOwnerID())

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

func handleDemoSeed(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	creatorID := userUUID("anna.recycler@example.com")
	creatorName := "Anna Recycler"
	helperID := userUUID("erik.helper@example.com")
	helperName := "Erik Helper"

	if tokenString, err := bearerTokenFromRequest(r); err == nil && tokenString != "" {
		if claims, err := validateToken(tokenString); err == nil && claims != nil {
			if claims.isHelper() {
				helperID = claims.helperID()
				helperName = claims.notificationName()
			} else {
				creatorID = claims.requestOwnerID()
				creatorName = claims.notificationName()
			}
		}
	}

	now := time.Now().UTC()
	yesterday := now.Add(-24 * time.Hour)
	lat1, lon1 := 59.3365, 18.0610
	lat2, lon2 := 59.3175, 18.0720
	lat3, lon3 := 59.3320, 18.0310
	eta12 := 12

	rec185 := 185.0
	recShare129 := 129.50
	helpShare105 := 105.50

	sampleRequests := []RecyclingRequest{
		{
			ID:                    "demo-pending-1",
			CreatorID:             creatorID,
			CreatorName:           creatorName,
			Title:                 "Bottles & Cans Pickup",
			Location:              "Sveavägen 44, Stockholm",
			LocationLatitude:      &lat1,
			LocationLongitude:     &lon1,
			Description:           "3 bags of sorted pant cans and PET bottles ready at door",
			Reward:                45.0,
			Currency:              "SEK",
			CurrencySymbol:        "kr",
			Market:                "SE",
			SplitPercentage:       70.0,
			Status:                "pending",
			CreatorBankIdVerified: true,
			ScheduledFrom:         now,
			ScheduledTo:           now.Add(2 * time.Hour),
			ImageUrl:              "assets/images/generic.png",
		},
		{
			ID:                    "demo-accepted-1",
			CreatorID:             creatorID,
			CreatorName:           creatorName,
			HelperID:              helperID,
			HelperName:            helperName,
			Title:                 "Glass & Aluminum Return",
			Location:              "Götgatan 22, Stockholm",
			LocationLatitude:      &lat2,
			LocationLongitude:     &lon2,
			Description:           "Large box of glass bottles + cans from weekend party",
			Reward:                65.0,
			Currency:              "SEK",
			CurrencySymbol:        "kr",
			Market:                "SE",
			SplitPercentage:       75.0,
			Status:                "accepted",
			EtaMinutes:            &eta12,
			Milestone:             "on_the_way",
			LeaveAtDoor:           true,
			DoorInstructions:      "Leave behind inner courtyard door code 4821",
			CreatorBankIdVerified: true,
			HelperBankIdVerified:  true,
			ScheduledFrom:         now,
			ScheduledTo:           now.Add(1 * time.Hour),
			ImageUrl:              "assets/images/generic.png",
			CreatorDeviceToken:    "fcm-demo-creator-token",
			Messages: []ChatMessage{
				{
					ID:         "msg-seed-1",
					RequestID:  "demo-accepted-1",
					SenderID:   creatorID,
					SenderRole: "user",
					SenderName: creatorName,
					Text:       "Hej! The recycling bags are ready outside apartment 3B.",
					IsPreset:   false,
					CreatedAt:  now.Add(-10 * time.Minute).Format(time.RFC3339),
				},
				{
					ID:         "msg-seed-2",
					RequestID:  "demo-accepted-1",
					SenderID:   helperID,
					SenderRole: "helper",
					SenderName: helperName,
					Text:       "Great, I am on my way with a cargo bike! ETA 12 mins.",
					IsPreset:   false,
					CreatedAt:  now.Add(-5 * time.Minute).Format(time.RFC3339),
				},
			},
		},
		{
			ID:                    "demo-completed-1",
			CreatorID:             creatorID,
			CreatorName:           creatorName,
			HelperID:              helperID,
			HelperName:            helperName,
			Title:                 "Bulk PET Bottles - Completed",
			Location:              "Drottningholmsvägen 12, Stockholm",
			LocationLatitude:      &lat3,
			LocationLongitude:     &lon3,
			Description:           "Office recycling pickup completed yesterday",
			Reward:                50.0,
			Currency:              "SEK",
			CurrencySymbol:        "kr",
			Market:                "SE",
			SplitPercentage:       70.0,
			Status:                "pickedUp",
			ReceiptAmount:         rec185,
			RecyclerPayout:        &recShare129,
			HelperPayout:          &helpShare105,
			DropoffPhotoUrl:       "https://images.unsplash.com/photo-1532996122724-e3c354a0b15b?auto=format&fit=crop&w=400&q=80",
			ReceiptScannedAt:      &yesterday,
			DropoffConfirmedAt:    &yesterday,
			CreatorBankIdVerified: true,
			HelperBankIdVerified:  true,
			ScheduledFrom:         yesterday.Add(-2 * time.Hour),
			ScheduledTo:           yesterday.Add(-1 * time.Hour),
			ImageUrl:              "assets/images/generic.png",
		},
	}

	for _, req := range sampleRequests {
		// Preserve existing dynamic chat messages & status if item exists
		existingOut, err := svc.GetItem(context.TODO(), &dynamodb.GetItemInput{
			TableName: aws.String(tableName),
			Key: map[string]types.AttributeValue{
				"id": &types.AttributeValueMemberS{Value: req.ID},
			},
		})
		if err == nil && len(existingOut.Item) > 0 {
			var existing RecyclingRequest
			if err := attributevalue.UnmarshalMap(existingOut.Item, &existing); err == nil {
				if len(existing.Messages) > 0 {
					req.Messages = existing.Messages
				}
				if existing.Status != "" {
					req.Status = existing.Status
				}
				if existing.HelperID != "" {
					if _, err := uuid.Parse(existing.HelperID); err == nil {
						req.HelperID = existing.HelperID
					} else {
						req.HelperID = helperID
						req.HelperName = helperName
					}
				}
			}
		}

		item, err := attributevalue.MarshalMap(req)
		if err != nil {
			log.Printf("Error marshalling demo request: %v", err)
			continue
		}
		_, err = svc.PutItem(context.TODO(), &dynamodb.PutItemInput{
			TableName: aws.String(tableName),
			Item:      item,
		})
		if err != nil {
			log.Printf("Error putting demo request item: %v", err)
		}
	}

	jsonResponse(w, http.StatusOK, map[string]interface{}{
		"success":  true,
		"message":  "Demo data seeded successfully",
		"requests": sampleRequests,
	})
}

type registerDeviceTokenPayload struct {
	DeviceToken string `json:"deviceToken"`
}

func handleRegisterDeviceToken(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	claims, ok := currentClaims(r)
	if !ok || claims == nil {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}

	var payload registerDeviceTokenPayload
	if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
		jsonResponse(w, http.StatusBadRequest, map[string]string{"error": "Invalid payload"})
		return
	}

	token := strings.TrimSpace(payload.DeviceToken)
	if token == "" {
		jsonResponse(w, http.StatusBadRequest, map[string]string{"error": "deviceToken is required"})
		return
	}

	// Attach device token to any currently active requests created by this user
	reqs, err := listCreatorRequests(r.Context(), claims.requestOwnerID())
	if err == nil {
		for _, req := range reqs {
			if req.Status == "pending" || req.Status == "accepted" {
				_, _ = svc.UpdateItem(r.Context(), &dynamodb.UpdateItemInput{
					TableName: aws.String(tableName),
					Key: map[string]types.AttributeValue{
						"id": &types.AttributeValueMemberS{Value: req.ID},
					},
					UpdateExpression: aws.String("SET creatorDeviceToken = :token"),
					ExpressionAttributeValues: map[string]types.AttributeValue{
						":token": &types.AttributeValueMemberS{Value: token},
					},
				})
			}
		}
	}

	jsonResponse(w, http.StatusOK, map[string]interface{}{
		"status":      "registered",
		"deviceToken": token,
	})
}


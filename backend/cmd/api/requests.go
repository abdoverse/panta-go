package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"net/url"
	"sort"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/feature/dynamodb/attributevalue"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb/types"
	"github.com/google/uuid"
)

var (
	geocacheMutex sync.RWMutex
	geocache      = make(map[string][2]float64)
)

func geocodeAddress(location string) (float64, float64, error) {
	trimmed := strings.TrimSpace(location)
	if trimmed == "" {
		return 0, 0, fmt.Errorf("empty location")
	}

	geocacheMutex.RLock()
	coords, found := geocache[strings.ToLower(trimmed)]
	geocacheMutex.RUnlock()
	if found {
		return coords[0], coords[1], nil
	}

	query := url.QueryEscape(trimmed)
	endpoint := fmt.Sprintf("https://nominatim.openstreetmap.org/search?q=%s&format=json&limit=1", query)
	req, err := http.NewRequest(http.MethodGet, endpoint, nil)
	if err != nil {
		return 0, 0, err
	}
	req.Header.Set("User-Agent", "Panta_Recycling_App/1.0")

	client := &http.Client{Timeout: 3 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return 0, 0, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return 0, 0, fmt.Errorf("geocoding status: %d", resp.StatusCode)
	}

	var results []struct {
		Lat string `json:"lat"`
		Lon string `json:"lon"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&results); err != nil || len(results) == 0 {
		return 0, 0, fmt.Errorf("no geocoding results")
	}

	lat, err1 := strconv.ParseFloat(results[0].Lat, 64)
	lon, err2 := strconv.ParseFloat(results[0].Lon, 64)
	if err1 != nil || err2 != nil {
		return 0, 0, fmt.Errorf("parse geocoding coords error")
	}

	geocacheMutex.Lock()
	geocache[strings.ToLower(trimmed)] = [2]float64{lat, lon}
	geocacheMutex.Unlock()

	return lat, lon, nil
}

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
		if requests[i].ReceiptImageUrl != "" {
			if rUrl, err := resolveImageURL(r.Context(), requests[i].ReceiptImageUrl); err == nil {
				requests[i].ReceiptImageUrl = rUrl
			}
		}
		if requests[i].DropoffPhotoUrl != "" {
			if dUrl, err := resolveImageURL(r.Context(), requests[i].DropoffPhotoUrl); err == nil {
				requests[i].DropoffPhotoUrl = dUrl
			}
		}
		if len(requests[i].Messages) > 0 {
			requests[i].Messages = sanitizeAndDecryptMessages(requests[i].Messages, requests[i].ID)
		}
		if (requests[i].LocationLatitude == nil || requests[i].LocationLongitude == nil) && strings.TrimSpace(requests[i].Location) != "" {
			if lat, lon, err := geocodeAddress(requests[i].Location); err == nil {
				requests[i].LocationLatitude = &lat
				requests[i].LocationLongitude = &lon
				go func(id string, latVal, lonVal float64) {
					_, _ = svc.UpdateItem(context.Background(), &dynamodb.UpdateItemInput{
						TableName: aws.String(tableName),
						Key: map[string]types.AttributeValue{
							"id": &types.AttributeValueMemberS{Value: id},
						},
						UpdateExpression: aws.String("SET locationLatitude = :lat, locationLongitude = :lon"),
						ExpressionAttributeValues: map[string]types.AttributeValue{
							":lat": &types.AttributeValueMemberN{Value: strconv.FormatFloat(latVal, 'f', 7, 64)},
							":lon": &types.AttributeValueMemberN{Value: strconv.FormatFloat(lonVal, 'f', 7, 64)},
						},
					})
				}(requests[i].ID, lat, lon)
			}
		}
	}

	jsonResponse(w, http.StatusOK, requests)
}

func listRequestsForClaims(ctx context.Context, claims *Claims) ([]RecyclingRequest, error) {
	if claims.isHelper() {
		return listHelperAccessibleRequests(ctx, claims.helperID(), claims)
	}
	return listCreatorRequests(ctx, claims.requestOwnerID(), claims)
}

func listCreatorRequests(ctx context.Context, creatorID string, claims *Claims) ([]RecyclingRequest, error) {
	requests, err := queryRequests(ctx, &dynamodb.QueryInput{
		TableName:              aws.String(tableName),
		IndexName:              aws.String(requestsByCreatorIndexName),
		KeyConditionExpression: aws.String("creatorId = :creatorId"),
		ExpressionAttributeValues: map[string]types.AttributeValue{
			":creatorId": &types.AttributeValueMemberS{Value: creatorID},
		},
	})
	if err != nil {
		return nil, err
	}

	// Fetch for all known aliases if claims are provided and match the target user
	if claims != nil && claims.matchesUser(creatorID) {
		for _, aliasID := range claims.candidateIDs() {
			if strings.EqualFold(aliasID, creatorID) {
				continue
			}
			aliasRequests, _ := queryRequests(ctx, &dynamodb.QueryInput{
				TableName:              aws.String(tableName),
				IndexName:              aws.String(requestsByCreatorIndexName),
				KeyConditionExpression: aws.String("creatorId = :creatorId"),
				ExpressionAttributeValues: map[string]types.AttributeValue{
					":creatorId": &types.AttributeValueMemberS{Value: aliasID},
				},
			})
			if len(aliasRequests) > 0 {
				requests = mergeRequestsByID(requests, aliasRequests)
			}
		}
	}

	return requests, nil
}

func listHelperAccessibleRequests(ctx context.Context, helperID string, claims *Claims) ([]RecyclingRequest, error) {
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

	// Fetch for all known aliases if claims are provided and match the target helper
	if claims != nil && claims.matchesUser(helperID) {
		for _, aliasID := range claims.candidateIDs() {
			if strings.EqualFold(aliasID, helperID) {
				continue
			}
			aliasRequests, _ := queryRequests(ctx, &dynamodb.QueryInput{
				TableName:              aws.String(tableName),
				IndexName:              aws.String(requestsByHelperIndexName),
				KeyConditionExpression: aws.String("helperId = :helperId"),
				ExpressionAttributeValues: map[string]types.AttributeValue{
					":helperId": &types.AttributeValueMemberS{Value: aliasID},
				},
			})
			if len(aliasRequests) > 0 {
				assignedRequests = mergeRequestsByID(assignedRequests, aliasRequests)
			}
		}
	}

	return mergeRequestsByID(
		filterHelperVisiblePendingRequests(returnableRequests, helperID),
		filterHelperAssignedRequests(assignedRequests, helperID),
	), nil
}

func listHelperAssignedRequests(ctx context.Context, helperID string) ([]RecyclingRequest, error) {
	requests, err := queryRequests(ctx, &dynamodb.QueryInput{
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

	erikEmailUUID := userUUID("erik.helper@example.com")
	erikNameUUID := userUUID("Erik Helper")
	aliasID := ""
	if strings.EqualFold(helperID, erikEmailUUID) {
		aliasID = erikNameUUID
	} else if strings.EqualFold(helperID, erikNameUUID) {
		aliasID = erikEmailUUID
	}
	if aliasID != "" {
		aliasRequests, _ := queryRequests(ctx, &dynamodb.QueryInput{
			TableName:              aws.String(tableName),
			IndexName:              aws.String(requestsByHelperIndexName),
			KeyConditionExpression: aws.String("helperId = :helperId"),
			ExpressionAttributeValues: map[string]types.AttributeValue{
				":helperId": &types.AttributeValueMemberS{Value: aliasID},
			},
		})
		if len(aliasRequests) > 0 {
			requests = mergeRequestsByID(requests, aliasRequests)
		}
	}

	return requests, nil
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

func helperIDsMatch(id1, id2 string) bool {
	a := strings.TrimSpace(id1)
	b := strings.TrimSpace(id2)
	if a == "" || b == "" {
		return false
	}
	return strings.EqualFold(a, b)
}

func helperHasCancelledRequest(cancelledHelperIDs []string, helperID string) bool {
	normalizedHelperID := strings.TrimSpace(helperID)
	if normalizedHelperID == "" {
		return false
	}
	for _, cancelledHelperID := range cancelledHelperIDs {
		if helperIDsMatch(cancelledHelperID, normalizedHelperID) {
			return true
		}
	}
	return false
}

func filterHelperAssignedRequests(requests []RecyclingRequest, helperID string) []RecyclingRequest {
	filtered := make([]RecyclingRequest, 0, len(requests))
	normalizedHelperID := strings.TrimSpace(helperID)
	for _, request := range requests {
		if !helperIDsMatch(request.HelperID, normalizedHelperID) {
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

	if blocked, blockRec := isUserBlocked(claims.requestOwnerID(), claims.Email); blocked {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusForbidden)
		_ = json.NewEncoder(w).Encode(map[string]interface{}{
			"error":           "Account restricted",
			"code":            "ACCOUNT_RESTRICTED",
			"message":         fmt.Sprintf("%s Reference: %s", NonSensitiveAccountRestrictionMessage, blockRec.CaseReferenceID),
			"caseReferenceId": blockRec.CaseReferenceID,
		})
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

	creatorRequests, err := listCreatorRequests(r.Context(), claims.requestOwnerID(), claims)
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
	req.CreatorBankIdVerified = claims.BankIdVerified

	if (req.LocationLatitude == nil || req.LocationLongitude == nil) && strings.TrimSpace(req.Location) != "" {
		if lat, lon, err := geocodeAddress(req.Location); err == nil {
			req.LocationLatitude = &lat
			req.LocationLongitude = &lon
		}
	}

	item, err := attributevalue.MarshalMap(req)
	if err != nil {
		jsonResponse(w, http.StatusInternalServerError, map[string]string{"error": "Failed to marshal item"})
		return
	}

	_, err = svc.PutItem(r.Context(), &dynamodb.PutItemInput{
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
	reqs, err := listCreatorRequests(r.Context(), claims.requestOwnerID(), claims)
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

	// Also attach device token to any currently active requests assigned to this helper
	helperReqs, err := listHelperAssignedRequests(r.Context(), claims.helperID())
	if err == nil {
		for _, req := range helperReqs {
			if req.Status == "accepted" || req.Status == "pickedup" {
				_, _ = svc.UpdateItem(r.Context(), &dynamodb.UpdateItemInput{
					TableName: aws.String(tableName),
					Key: map[string]types.AttributeValue{
						"id": &types.AttributeValueMemberS{Value: req.ID},
					},
					UpdateExpression: aws.String("SET helperDeviceToken = :token"),
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


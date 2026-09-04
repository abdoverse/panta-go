package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"time"

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

	var payload CompleteRequestPayload
	if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
		jsonResponse(w, http.StatusBadRequest, map[string]string{"error": "Invalid payload"})
		return
	}

	updateExpr := "SET #status = :pickedUp"
	exprValues := map[string]types.AttributeValue{
		":pickedUp": &types.AttributeValueMemberS{Value: "pickedUp"},
		":accepted": &types.AttributeValueMemberS{Value: "accepted"},
		":helperId": &types.AttributeValueMemberS{Value: claims.helperID()},
	}

	if payload.ReceiptAmount > 0 {
		split := payload.SplitPercentage
		if split <= 0 || split > 100 {
			split = 70.0
		}
		payout := CalculatePayout(payload.ReceiptAmount, split, 0)
		updateExpr += ", receiptAmount = :receiptAmount, splitPercentage = :splitPercentage, recyclerPayout = :recyclerPayout, helperPayout = :helperPayout"
		exprValues[":receiptAmount"] = &types.AttributeValueMemberN{Value: fmt.Sprintf("%f", payout.ReceiptAmount)}
		exprValues[":splitPercentage"] = &types.AttributeValueMemberN{Value: fmt.Sprintf("%f", payout.SplitPercentage)}
		exprValues[":recyclerPayout"] = &types.AttributeValueMemberN{Value: fmt.Sprintf("%f", payout.RecyclerShare)}
		exprValues[":helperPayout"] = &types.AttributeValueMemberN{Value: fmt.Sprintf("%f", payout.HelperShare)}

		now := time.Now().UTC().Format(time.RFC3339)
		updateExpr += ", receiptScannedAt = :receiptScannedAt"
		exprValues[":receiptScannedAt"] = &types.AttributeValueMemberS{Value: now}
	}

	if payload.ReceiptImageUrl != "" {
		updateExpr += ", receiptImageUrl = :receiptImageUrl"
		exprValues[":receiptImageUrl"] = &types.AttributeValueMemberS{Value: payload.ReceiptImageUrl}
	}

	if payload.DropoffPhotoUrl != "" {
		updateExpr += ", dropoffPhotoUrl = :dropoffPhotoUrl, dropoffConfirmedAt = :dropoffConfirmedAt"
		exprValues[":dropoffPhotoUrl"] = &types.AttributeValueMemberS{Value: payload.DropoffPhotoUrl}
		now := time.Now().UTC().Format(time.RFC3339)
		exprValues[":dropoffConfirmedAt"] = &types.AttributeValueMemberS{Value: now}
	}

	out, err := svc.UpdateItem(context.TODO(), &dynamodb.UpdateItemInput{
		TableName: aws.String(tableName),
		Key: map[string]types.AttributeValue{
			"id": &types.AttributeValueMemberS{Value: payload.ID},
		},
		UpdateExpression:    aws.String(updateExpr),
		ConditionExpression: aws.String("#status = :accepted AND helperId = :helperId"),
		ExpressionAttributeNames: map[string]string{
			"#status": "status",
		},
		ExpressionAttributeValues: exprValues,
		ReturnValues:              types.ReturnValueAllNew,
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

func handleUpdateLocation(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	claims, ok := currentClaims(r)
	if !ok {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}

	var payload UpdateLocationPayload
	if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
		jsonResponse(w, http.StatusBadRequest, map[string]string{"error": "Invalid payload"})
		return
	}

	if payload.ID == "" || payload.HelperLatitude == nil || payload.HelperLongitude == nil {
		jsonResponse(w, http.StatusBadRequest, map[string]string{"error": "id, helperLatitude and helperLongitude are required"})
		return
	}

	expr := "SET helperLatitude = :lat, helperLongitude = :lng"
	exprValues := map[string]types.AttributeValue{
		":lat":      &types.AttributeValueMemberN{Value: fmt.Sprintf("%f", *payload.HelperLatitude)},
		":lng":      &types.AttributeValueMemberN{Value: fmt.Sprintf("%f", *payload.HelperLongitude)},
		":accepted": &types.AttributeValueMemberS{Value: "accepted"},
		":helperId": &types.AttributeValueMemberS{Value: claims.helperID()},
	}

	if payload.EtaMinutes != nil {
		expr += ", etaMinutes = :eta"
		exprValues[":eta"] = &types.AttributeValueMemberN{Value: fmt.Sprintf("%d", *payload.EtaMinutes)}
	}
	if payload.Milestone != "" {
		expr += ", milestone = :milestone"
		exprValues[":milestone"] = &types.AttributeValueMemberS{Value: payload.Milestone}
	}

	out, err := svc.UpdateItem(context.TODO(), &dynamodb.UpdateItemInput{
		TableName: aws.String(tableName),
		Key: map[string]types.AttributeValue{
			"id": &types.AttributeValueMemberS{Value: payload.ID},
		},
		UpdateExpression:    aws.String(expr),
		ConditionExpression: aws.String("status = :accepted AND helperId = :helperId"),
		ExpressionAttributeValues: exprValues,
		ReturnValues:        types.ReturnValueAllNew,
	})
	if err != nil {
		log.Printf("Failed to update location: %v", err)
		jsonResponse(w, http.StatusInternalServerError, map[string]string{"error": "Failed to update location"})
		return
	}

	var updatedReq RecyclingRequest
	if err := attributevalue.UnmarshalMap(out.Attributes, &updatedReq); err != nil {
		jsonResponse(w, http.StatusInternalServerError, map[string]string{"error": "Failed to parse updated request"})
		return
	}

	respondWithUpdatedRequest(w, r, updatedReq, "location_updated")
}

func handleArrivedAtDoor(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	claims, ok := currentClaims(r)
	if !ok || claims == nil {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}

	var payload ArrivedAtDoorPayload
	if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
		jsonResponse(w, http.StatusBadRequest, map[string]string{"error": "Invalid payload"})
		return
	}

	if payload.ID == "" {
		jsonResponse(w, http.StatusBadRequest, map[string]string{"error": "id is required"})
		return
	}

	now := time.Now().UTC()
	nowStr := now.Format(time.RFC3339)
	eta0 := 0

	expr := "SET arrivedAtDoor = :now, milestone = :milestone, etaMinutes = :eta"
	exprValues := map[string]types.AttributeValue{
		":now":       &types.AttributeValueMemberS{Value: nowStr},
		":milestone": &types.AttributeValueMemberS{Value: "arrived"},
		":eta":       &types.AttributeValueMemberN{Value: fmt.Sprintf("%d", eta0)},
		":accepted":  &types.AttributeValueMemberS{Value: "accepted"},
		":helperId":  &types.AttributeValueMemberS{Value: claims.helperID()},
	}

	out, err := svc.UpdateItem(r.Context(), &dynamodb.UpdateItemInput{
		TableName: aws.String(tableName),
		Key: map[string]types.AttributeValue{
			"id": &types.AttributeValueMemberS{Value: payload.ID},
		},
		UpdateExpression:          aws.String(expr),
		ConditionExpression:       aws.String("status = :accepted AND helperId = :helperId"),
		ExpressionAttributeValues: exprValues,
		ReturnValues:              types.ReturnValueAllNew,
	})
	if err != nil {
		log.Printf("Failed to record arrived at door: %v", err)
		jsonResponse(w, http.StatusInternalServerError, map[string]string{"error": "Failed to update arrival state"})
		return
	}

	var updatedReq RecyclingRequest
	if err := attributevalue.UnmarshalMap(out.Attributes, &updatedReq); err != nil {
		jsonResponse(w, http.StatusInternalServerError, map[string]string{"error": "Failed to parse updated request"})
		return
	}

	// Broadcast arrival alert via WebSocket
	arrivedMsg := map[string]interface{}{
		"type":      "helper-arrived-at-door",
		"requestId": updatedReq.ID,
		"arrivedAt": nowStr,
		"title":     "Helper is at your door!",
		"message":   fmt.Sprintf("%s is outside your door with Panta Go.", claims.notificationName()),
	}
	rawMsg, _ := json.Marshal(arrivedMsg)
	hub.broadcast <- rawMsg

	// Push notification to creator device if token exists
	if updatedReq.CreatorDeviceToken != "" {
		go sendPushNotification(
			updatedReq.CreatorDeviceToken,
			"Ding-Dong! Helper is at your door 🛎️",
			fmt.Sprintf("%s has arrived for your recycling pickup.", claims.notificationName()),
		)
	}

	respondWithUpdatedRequest(w, r, updatedReq, "arrived_at_door")
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

	if payload.ID == "" || payload.Rating < 1 || payload.Rating > 5 {
		jsonResponse(w, http.StatusBadRequest, map[string]string{"error": "id and rating (1-5) are required"})
		return
	}

	_, err := svc.UpdateItem(context.TODO(), &dynamodb.UpdateItemInput{
		TableName: aws.String(tableName),
		Key: map[string]types.AttributeValue{
			"id": &types.AttributeValueMemberS{Value: payload.ID},
		},
		UpdateExpression:    aws.String("SET isRated = :true, rating = :r, ratingComment = :c"),
		ConditionExpression: aws.String("isRated = :false AND creatorId = :creatorId AND #status = :pickedUp"),
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

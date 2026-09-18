package main

import (
	"log"
	"net/http"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/feature/dynamodb/attributevalue"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb/types"
)

func handleDemoSeed(w http.ResponseWriter, r *http.Request) {
	if isProductionEnvironment() {
		http.Error(w, "Demo seed is disabled in production", http.StatusForbidden)
		return
	}

	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	creatorID := userUUID("anna.recycler@example.com")
	creatorName := "Anna Recycler"
	helperID := userUUID("erik.helper@example.com")
	helperName := "Erik Helper"

	callerIsBankIdVerified := false
	isUser := false
	isHelper := false
	if tokenString, err := bearerTokenFromRequest(r); err == nil && tokenString != "" {
		if claims, err := validateToken(tokenString); err == nil && claims != nil {
			callerIsBankIdVerified = claims.BankIdVerified
			if claims.isHelper() {
				isHelper = true
				helperID = claims.helperID()
				helperName = claims.notificationName()
			} else {
				isUser = true
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
			CreatorBankIdVerified: isUser && callerIsBankIdVerified,
			ScheduledFrom:         now,
			ScheduledTo:           now.Add(2 * time.Hour),
			ImageUrl:              "assets/images/generic.png",
		},
		{
			ID:                    "demo-bankid-1",
			CreatorID:             userUUID("johan.bankid@example.com"),
			CreatorName:           "Johan Bergström",
			Title:                 "BankID Verified: Sorterade burkar & flaskor",
			Location:              "Kungsgatan 14, Stockholm",
			LocationLatitude:      &lat1,
			LocationLongitude:     &lon1,
			Description:           "2 stora pantkassar färdigsorterade vid entrén. Verifierad med BankID.",
			Reward:                55.0,
			Currency:              "SEK",
			CurrencySymbol:        "kr",
			Market:                "SE",
			SplitPercentage:       70.0,
			Status:                "pending",
			CreatorBankIdVerified: true,
			ScheduledFrom:         now,
			ScheduledTo:           now.Add(3 * time.Hour),
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
			CreatorBankIdVerified: isUser && callerIsBankIdVerified,
			HelperBankIdVerified:  isHelper && callerIsBankIdVerified,
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
			CreatorBankIdVerified: isUser && callerIsBankIdVerified,
			HelperBankIdVerified:  isHelper && callerIsBankIdVerified,
			ScheduledFrom:         yesterday.Add(-2 * time.Hour),
			ScheduledTo:           yesterday.Add(-1 * time.Hour),
			ImageUrl:              "assets/images/generic.png",
		},
	}

	for _, req := range sampleRequests {
		// Preserve existing dynamic chat messages & status if item exists
		existingOut, err := svc.GetItem(r.Context(), &dynamodb.GetItemInput{
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
			}
		}

		item, err := attributevalue.MarshalMap(req)
		if err != nil {
			log.Printf("Error marshalling demo request: %v", err)
			continue
		}
		_, err = svc.PutItem(r.Context(), &dynamodb.PutItemInput{
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

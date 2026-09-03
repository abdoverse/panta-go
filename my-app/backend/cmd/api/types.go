package main

import (
	"math"
	"strings"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

type RecyclingRequest struct {
	ID                 string    `json:"id" dynamodbav:"id"`
	CreatorID          string    `json:"-" dynamodbav:"creatorId,omitempty"`
	Title              string    `json:"title" dynamodbav:"title"`
	ImageUrl           string    `json:"imageUrl" dynamodbav:"imageUrl"`
	ImageUploadKey     string    `json:"imageUploadKey,omitempty" dynamodbav:"-"`
	ScheduledFrom      time.Time `json:"scheduledFrom" dynamodbav:"scheduledFrom"`
	ScheduledTo        time.Time `json:"scheduledTo" dynamodbav:"scheduledTo"`
	Location           string    `json:"location" dynamodbav:"location"`
	LocationLatitude   *float64  `json:"locationLatitude,omitempty" dynamodbav:"locationLatitude,omitempty"`
	LocationLongitude  *float64  `json:"locationLongitude,omitempty" dynamodbav:"locationLongitude,omitempty"`
	Description        string    `json:"description" dynamodbav:"description"`
	Reward             float64   `json:"reward" dynamodbav:"reward"`
	Status             string    `json:"status" dynamodbav:"status"`
	HelperID           string    `json:"helperId,omitempty" dynamodbav:"helperId,omitempty"`
	CanceledHelperIDs  []string  `json:"canceledHelperIds,omitempty" dynamodbav:"canceledHelperIds,omitempty"`
	IsRated            bool      `json:"isRated" dynamodbav:"isRated"`
	Rating             float64   `json:"rating,omitempty" dynamodbav:"rating,omitempty"`
	RatingComment      string    `json:"ratingComment,omitempty" dynamodbav:"ratingComment,omitempty"`
	CreatorDeviceToken string    `json:"creatorDeviceToken,omitempty" dynamodbav:"creatorDeviceToken,omitempty"`
	ReceiptImageUrl    string     `json:"receiptImageUrl,omitempty" dynamodbav:"receiptImageUrl,omitempty"`
	ReceiptAmount      float64    `json:"receiptAmount,omitempty" dynamodbav:"receiptAmount,omitempty"`
	ReceiptScannedAt   *time.Time `json:"receiptScannedAt,omitempty" dynamodbav:"receiptScannedAt,omitempty"`
	SplitPercentage    float64    `json:"splitPercentage,omitempty" dynamodbav:"splitPercentage,omitempty"`
	RecyclerPayout     *float64   `json:"recyclerPayout,omitempty" dynamodbav:"recyclerPayout,omitempty"`
	HelperPayout       *float64   `json:"helperPayout,omitempty" dynamodbav:"helperPayout,omitempty"`
	HelperLatitude     *float64   `json:"helperLatitude,omitempty" dynamodbav:"helperLatitude,omitempty"`
	HelperLongitude    *float64   `json:"helperLongitude,omitempty" dynamodbav:"helperLongitude,omitempty"`
	EtaMinutes         *int       `json:"etaMinutes,omitempty" dynamodbav:"etaMinutes,omitempty"`
	Milestone          string     `json:"milestone,omitempty" dynamodbav:"milestone,omitempty"`
	LeaveAtDoor        bool       `json:"leaveAtDoor" dynamodbav:"leaveAtDoor"`
	DoorInstructions   string     `json:"doorInstructions,omitempty" dynamodbav:"doorInstructions,omitempty"`
	DropoffPhotoUrl    string        `json:"dropoffPhotoUrl,omitempty" dynamodbav:"dropoffPhotoUrl,omitempty"`
	DropoffConfirmedAt *time.Time    `json:"dropoffConfirmedAt,omitempty" dynamodbav:"dropoffConfirmedAt,omitempty"`
	Messages           []ChatMessage `json:"messages,omitempty" dynamodbav:"messages,omitempty"`
}

type ChatMessage struct {
	ID         string `json:"id" dynamodbav:"id"`
	RequestID  string `json:"requestId" dynamodbav:"requestId"`
	SenderID   string `json:"senderId" dynamodbav:"senderId"`
	SenderRole string `json:"senderRole" dynamodbav:"senderRole"` // "user" or "helper"
	SenderName string `json:"senderName" dynamodbav:"senderName"`
	Text       string `json:"text" dynamodbav:"text"`
	IsPreset   bool   `json:"isPreset" dynamodbav:"isPreset"`
	CreatedAt  string `json:"createdAt" dynamodbav:"createdAt"`
}

type SendChatMessagePayload struct {
	RequestID string `json:"requestId"`
	Text      string `json:"text"`
	IsPreset  bool   `json:"isPreset"`
}

type PayoutBreakdown struct {
	ReceiptAmount     float64 `json:"receiptAmount"`
	SplitPercentage   float64 `json:"splitPercentage"`
	RecyclerShare     float64 `json:"recyclerShare"`
	HelperShare       float64 `json:"helperShare"`
	HelperBaseReward  float64 `json:"helperBaseReward"`
	TotalHelperEarned float64 `json:"totalHelperEarned"`
}

func CalculatePayout(receiptAmount float64, splitPercentage float64, baseReward float64) PayoutBreakdown {
	if splitPercentage <= 0 || splitPercentage > 100 {
		splitPercentage = 70.0 // Default to 70% to recycler
	}
	if receiptAmount < 0 {
		receiptAmount = 0
	}
	if baseReward < 0 {
		baseReward = 0
	}

	recyclerShare := (receiptAmount * splitPercentage) / 100.0
	helperShare := (receiptAmount * (100.0 - splitPercentage)) / 100.0
	totalHelper := helperShare + baseReward

	return PayoutBreakdown{
		ReceiptAmount:     math.Round(receiptAmount*100) / 100,
		SplitPercentage:   splitPercentage,
		RecyclerShare:     math.Round(recyclerShare*100) / 100,
		HelperShare:       math.Round(helperShare*100) / 100,
		HelperBaseReward:  math.Round(baseReward*100) / 100,
		TotalHelperEarned: math.Round(totalHelper*100) / 100,
	}
}

type ImpactActivityItem struct {
	ID            string  `json:"id"`
	Title         string  `json:"title"`
	CompletedAt   string  `json:"completedAt"`
	ReceiptAmount float64 `json:"receiptAmount"`
	Earnings      float64 `json:"earnings"`
	CO2SavedKg    float64 `json:"co2SavedKg"`
}

type ImpactSummary struct {
	TotalPickups       int                  `json:"totalPickups"`
	TotalReceiptAmount float64              `json:"totalReceiptAmount"`
	TotalEarnings      float64              `json:"totalEarnings"`
	ContainersRecycled int                  `json:"containersRecycled"`
	CO2SavedKg         float64              `json:"co2SavedKg"`
	TreesEquivalent    float64              `json:"treesEquivalent"`
	RecentActivity     []ImpactActivityItem `json:"recentActivity"`
}

func CalculateImpact(requests []RecyclingRequest, isHelper bool) ImpactSummary {
	var totalReceipt float64
	var totalEarned float64
	completedCount := 0
	recent := make([]ImpactActivityItem, 0)

	for _, req := range requests {
		if req.Status != "pickedUp" {
			continue
		}
		completedCount++
		totalReceipt += req.ReceiptAmount

		var earnings float64
		if isHelper {
			if req.HelperPayout != nil {
				earnings = *req.HelperPayout
			} else {
				earnings = req.ReceiptAmount * (100.0 - req.SplitPercentage) / 100.0
			}
		} else {
			if req.RecyclerPayout != nil {
				earnings = *req.RecyclerPayout
			} else {
				earnings = req.ReceiptAmount * req.SplitPercentage / 100.0
			}
		}
		totalEarned += earnings

		completedAt := ""
		if req.ReceiptScannedAt != nil {
			completedAt = req.ReceiptScannedAt.UTC().Format(time.RFC3339)
		} else {
			completedAt = req.ScheduledTo.UTC().Format(time.RFC3339)
		}

		itemCO2 := math.Round(req.ReceiptAmount*0.08*100) / 100

		recent = append(recent, ImpactActivityItem{
			ID:            req.ID,
			Title:         req.Title,
			CompletedAt:   completedAt,
			ReceiptAmount: req.ReceiptAmount,
			Earnings:      math.Round(earnings*100) / 100,
			CO2SavedKg:    itemCO2,
		})
	}

	containers := int(math.Round(totalReceipt / 1.5))
	if containers == 0 && totalReceipt > 0 {
		containers = int(totalReceipt)
	}
	co2Saved := math.Round(float64(containers)*0.09*100) / 100
	treesEquiv := math.Round((co2Saved/21.0)*100) / 100

	return ImpactSummary{
		TotalPickups:       completedCount,
		TotalReceiptAmount: math.Round(totalReceipt*100) / 100,
		TotalEarnings:      math.Round(totalEarned*100) / 100,
		ContainersRecycled: containers,
		CO2SavedKg:         co2Saved,
		TreesEquivalent:    treesEquiv,
		RecentActivity:     recent,
	}
}

type UpdateLocationPayload struct {
	ID              string   `json:"id"`
	HelperLatitude  *float64 `json:"helperLatitude"`
	HelperLongitude *float64 `json:"helperLongitude"`
	EtaMinutes      *int     `json:"etaMinutes,omitempty"`
	Milestone       string   `json:"milestone,omitempty"`
}

type CompleteRequestPayload struct {
	ID              string  `json:"id"`
	ReceiptImageUrl string  `json:"receiptImageUrl,omitempty"`
	ReceiptAmount   float64 `json:"receiptAmount,omitempty"`
	SplitPercentage float64 `json:"splitPercentage,omitempty"`
	DropoffPhotoUrl string  `json:"dropoffPhotoUrl,omitempty"`
}

type SavedAddress struct {
	Label     string   `json:"label" dynamodbav:"label"`
	Location  string   `json:"location" dynamodbav:"location"`
	Latitude  *float64 `json:"latitude,omitempty" dynamodbav:"latitude,omitempty"`
	Longitude *float64 `json:"longitude,omitempty" dynamodbav:"longitude,omitempty"`
}

type RequestTemplate struct {
	Name        string  `json:"name" dynamodbav:"name"`
	Title       string  `json:"title" dynamodbav:"title"`
	Description string  `json:"description" dynamodbav:"description"`
	Reward      float64 `json:"reward" dynamodbav:"reward"`
}

type RequestPreferences struct {
	ID             string            `json:"id,omitempty" dynamodbav:"id"`
	SavedAddresses []SavedAddress    `json:"savedAddresses,omitempty" dynamodbav:"savedAddresses,omitempty"`
	Templates      []RequestTemplate `json:"templates,omitempty" dynamodbav:"templates,omitempty"`
}

type LoginRequest struct {
	Role string `json:"role"`
	Name string `json:"username"`
}

type LoginResponse struct {
	Token string `json:"token"`
}

type Claims struct {
	Role            string `json:"nickname"`
	CognitoUsername string `json:"cognito:username"`
	DisplayName     string `json:"name"`
	Email           string `json:"email"`
	jwt.RegisteredClaims
}

func (c *Claims) helperID() string {
	return c.requestOwnerID()
}

func (c *Claims) requestOwnerID() string {
	if username := strings.TrimSpace(c.CognitoUsername); username != "" {
		return username
	}
	if name := strings.TrimSpace(c.DisplayName); name != "" {
		return name
	}
	return strings.TrimSpace(c.Email)
}

func (c *Claims) notificationName() string {
	if name := strings.TrimSpace(c.DisplayName); name != "" {
		return name
	}
	if email := strings.TrimSpace(c.Email); email != "" {
		return strings.Split(email, "@")[0]
	}
	return c.requestOwnerID()
}

func (c *Claims) isHelper() bool {
	return strings.EqualFold(strings.TrimSpace(c.Role), "helper")
}

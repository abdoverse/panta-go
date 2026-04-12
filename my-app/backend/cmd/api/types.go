package main

import (
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

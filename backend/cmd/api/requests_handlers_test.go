package main

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb"
)

func TestHandleRequests_GET(t *testing.T) {
	queryCalled := false
	mockDB := &mockDynamoDB{
		queryFunc: func(ctx context.Context, params *dynamodb.QueryInput, optFns ...func(*dynamodb.Options)) (*dynamodb.QueryOutput, error) {
			queryCalled = true
			return &dynamodb.QueryOutput{}, nil
		},
	}
	
	oldSvc := svc
	svc = mockDB
	defer func() { svc = oldSvc }()

	req := httptest.NewRequest(http.MethodGet, "/api/v1/requests", nil)
	
	claims := &Claims{
		UserID: "user-123",
		Role: "recycler",
	}
	req = req.WithContext(context.WithValue(req.Context(), userContextKey, claims))

	rr := httptest.NewRecorder()
	handleRequests(rr, req)

	if rr.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d: %s", rr.Code, rr.Body.String())
	}
	
	if !queryCalled {
		t.Fatalf("expected Query to be called when fetching requests")
	}
}

func TestHandleRequests_POST(t *testing.T) {
	putCalled := false
	mockDB := &mockDynamoDB{
		putItemFunc: func(ctx context.Context, params *dynamodb.PutItemInput, optFns ...func(*dynamodb.Options)) (*dynamodb.PutItemOutput, error) {
			putCalled = true
			return &dynamodb.PutItemOutput{}, nil
		},
	}
	
	oldSvc := svc
	svc = mockDB
	defer func() { svc = oldSvc }()

	payload := map[string]interface{}{
		"title": "Need pickup",
		"location": "Stockholm",
		"scheduledFrom": "2026-09-12T16:00:00Z",
		"scheduledTo": "2026-09-12T18:00:00Z",
	}
	body, _ := json.Marshal(payload)
	req := httptest.NewRequest(http.MethodPost, "/api/v1/requests", bytes.NewReader(body))
	
	claims := &Claims{
		UserID: "user-123",
		Role: "recycler",
	}
	req = req.WithContext(context.WithValue(req.Context(), userContextKey, claims))

	rr := httptest.NewRecorder()
	handleRequests(rr, req)

	if rr.Code != http.StatusCreated {
		t.Fatalf("expected status 201, got %d: %s", rr.Code, rr.Body.String())
	}
	
	if !putCalled {
		t.Fatalf("expected PutItem to be called when creating a request")
	}
}

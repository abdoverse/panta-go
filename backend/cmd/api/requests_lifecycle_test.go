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

type mockDynamoDB struct {
	DynamoDBAPI
	deleteItemFunc func(ctx context.Context, params *dynamodb.DeleteItemInput, optFns ...func(*dynamodb.Options)) (*dynamodb.DeleteItemOutput, error)
	updateItemFunc func(ctx context.Context, params *dynamodb.UpdateItemInput, optFns ...func(*dynamodb.Options)) (*dynamodb.UpdateItemOutput, error)
}

func (m *mockDynamoDB) DeleteItem(ctx context.Context, params *dynamodb.DeleteItemInput, optFns ...func(*dynamodb.Options)) (*dynamodb.DeleteItemOutput, error) {
	if m.deleteItemFunc != nil {
		return m.deleteItemFunc(ctx, params, optFns...)
	}
	return &dynamodb.DeleteItemOutput{}, nil
}

func (m *mockDynamoDB) UpdateItem(ctx context.Context, params *dynamodb.UpdateItemInput, optFns ...func(*dynamodb.Options)) (*dynamodb.UpdateItemOutput, error) {
	if m.updateItemFunc != nil {
		return m.updateItemFunc(ctx, params, optFns...)
	}
	return &dynamodb.UpdateItemOutput{}, nil
}

func TestHandleCancelRequest_Creator(t *testing.T) {
	

	deletedCalled := false
	mockDB := &mockDynamoDB{
		deleteItemFunc: func(ctx context.Context, params *dynamodb.DeleteItemInput, optFns ...func(*dynamodb.Options)) (*dynamodb.DeleteItemOutput, error) {
			deletedCalled = true
			return &dynamodb.DeleteItemOutput{}, nil
		},
	}
	
	// Temporarily replace the global svc
	oldSvc := svc
	svc = mockDB
	defer func() { svc = oldSvc }()

	payload := requestIDPayload{ID: "req-123"}
	body, _ := json.Marshal(payload)
	req := httptest.NewRequest(http.MethodPost, "/api/v1/requests/cancel", bytes.NewReader(body))
	
	// Inject a creator claims (role not "helper")
	claims := &Claims{
		UserID: "user-123",
		Role: "recycler",
	}
	req = req.WithContext(context.WithValue(req.Context(), userContextKey, claims))

	rr := httptest.NewRecorder()
	handleCancelRequest(rr, req)

	if rr.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d: %s", rr.Code, rr.Body.String())
	}
	
	if !deletedCalled {
		t.Fatalf("expected DeleteItem to be called for a creator")
	}
}

func TestHandleCancelRequest_Helper(t *testing.T) {
	

	updatedCalled := false
	mockDB := &mockDynamoDB{
		updateItemFunc: func(ctx context.Context, params *dynamodb.UpdateItemInput, optFns ...func(*dynamodb.Options)) (*dynamodb.UpdateItemOutput, error) {
			updatedCalled = true
			return &dynamodb.UpdateItemOutput{}, nil
		},
	}
	
	oldSvc := svc
	svc = mockDB
	defer func() { svc = oldSvc }()

	payload := requestIDPayload{ID: "req-123"}
	body, _ := json.Marshal(payload)
	req := httptest.NewRequest(http.MethodPost, "/api/v1/requests/cancel", bytes.NewReader(body))
	
	claims := &Claims{
		UserID: "helper-123",
		Role: "helper",
	}
	req = req.WithContext(context.WithValue(req.Context(), userContextKey, claims))

	rr := httptest.NewRecorder()
	handleCancelRequest(rr, req)

	if rr.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d: %s", rr.Code, rr.Body.String())
	}
	
	if !updatedCalled {
		t.Fatalf("expected UpdateItem to be called for a helper")
	}
}

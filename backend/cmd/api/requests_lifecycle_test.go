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
	putItemFunc    func(ctx context.Context, params *dynamodb.PutItemInput, optFns ...func(*dynamodb.Options)) (*dynamodb.PutItemOutput, error)
	getItemFunc    func(ctx context.Context, params *dynamodb.GetItemInput, optFns ...func(*dynamodb.Options)) (*dynamodb.GetItemOutput, error)
	queryFunc      func(ctx context.Context, params *dynamodb.QueryInput, optFns ...func(*dynamodb.Options)) (*dynamodb.QueryOutput, error)
	scanFunc       func(ctx context.Context, params *dynamodb.ScanInput, optFns ...func(*dynamodb.Options)) (*dynamodb.ScanOutput, error)
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

func (m *mockDynamoDB) PutItem(ctx context.Context, params *dynamodb.PutItemInput, optFns ...func(*dynamodb.Options)) (*dynamodb.PutItemOutput, error) {
	if m.putItemFunc != nil {
		return m.putItemFunc(ctx, params, optFns...)
	}
	return &dynamodb.PutItemOutput{}, nil
}

func (m *mockDynamoDB) GetItem(ctx context.Context, params *dynamodb.GetItemInput, optFns ...func(*dynamodb.Options)) (*dynamodb.GetItemOutput, error) {
	if m.getItemFunc != nil {
		return m.getItemFunc(ctx, params, optFns...)
	}
	return &dynamodb.GetItemOutput{}, nil
}

func (m *mockDynamoDB) Query(ctx context.Context, params *dynamodb.QueryInput, optFns ...func(*dynamodb.Options)) (*dynamodb.QueryOutput, error) {
	if m.queryFunc != nil {
		return m.queryFunc(ctx, params, optFns...)
	}
	return &dynamodb.QueryOutput{}, nil
}

func (m *mockDynamoDB) Scan(ctx context.Context, params *dynamodb.ScanInput, optFns ...func(*dynamodb.Options)) (*dynamodb.ScanOutput, error) {
	if m.scanFunc != nil {
		return m.scanFunc(ctx, params, optFns...)
	}
	return &dynamodb.ScanOutput{}, nil
}

func TestHandleCancelRequest_Creator(t *testing.T) {
	deletedCalled := false
	mockDB := &mockDynamoDB{
		deleteItemFunc: func(ctx context.Context, params *dynamodb.DeleteItemInput, optFns ...func(*dynamodb.Options)) (*dynamodb.DeleteItemOutput, error) {
			deletedCalled = true
			return &dynamodb.DeleteItemOutput{}, nil
		},
	}
	
	oldSvc := svc
	svc = mockDB
	defer func() { svc = oldSvc }()

	payload := requestIDPayload{ID: "req-123"}
	body, _ := json.Marshal(payload)
	req := httptest.NewRequest(http.MethodPost, "/api/v1/requests/cancel", bytes.NewReader(body))
	
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

func TestHandleAcceptRequest(t *testing.T) {
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
	req := httptest.NewRequest(http.MethodPost, "/api/v1/requests/accept", bytes.NewReader(body))
	
	claims := &Claims{
		UserID: "helper-123",
		Role: "helper",
	}
	req = req.WithContext(context.WithValue(req.Context(), userContextKey, claims))

	rr := httptest.NewRecorder()
	handleAcceptRequest(rr, req)

	if rr.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d: %s", rr.Code, rr.Body.String())
	}
	
	if !updatedCalled {
		t.Fatalf("expected UpdateItem to be called when accepting a request")
	}
}

func TestHandleCompleteRequest(t *testing.T) {
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

	payload := map[string]interface{}{
		"id": "req-123",
		"receiptAmount": 50.0,
	}
	body, _ := json.Marshal(payload)
	req := httptest.NewRequest(http.MethodPost, "/api/v1/requests/complete", bytes.NewReader(body))
	
	claims := &Claims{
		UserID: "helper-123",
		Role: "helper",
	}
	req = req.WithContext(context.WithValue(req.Context(), userContextKey, claims))

	rr := httptest.NewRecorder()
	handleCompleteRequest(rr, req)

	if rr.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d: %s", rr.Code, rr.Body.String())
	}
	
	if !updatedCalled {
		t.Fatalf("expected UpdateItem to be called when completing a request")
	}
}

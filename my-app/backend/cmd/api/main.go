package main

import (
	"context"
	"encoding/json"
	"errors"
	"log"
	"net/http"
	"os"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/feature/dynamodb/attributevalue"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb/types"
)

// Request Data Model
type RecyclingRequest struct {
	ID            string    `json:"id" dynamodbav:"id"`
	Title         string    `json:"title" dynamodbav:"title"`
	ImageUrl      string    `json:"imageUrl" dynamodbav:"imageUrl"`
	ScheduledFrom time.Time `json:"scheduledFrom" dynamodbav:"scheduledFrom"`
	ScheduledTo   time.Time `json:"scheduledTo" dynamodbav:"scheduledTo"`
	Location      string    `json:"location" dynamodbav:"location"`
	Status        string    `json:"status" dynamodbav:"status"`
	HelperID      string    `json:"helperId,omitempty" dynamodbav:"helperId,omitempty"`
	IsRated       bool      `json:"isRated" dynamodbav:"isRated"`
}

var (
	svc       *dynamodb.Client
	tableName string
)

func init() {
	// Initialize AWS Client
	cfg, err := config.LoadDefaultConfig(context.TODO())
	if err != nil {
		log.Fatalf("unable to load SDK config, %v", err)
	}

	svc = dynamodb.NewFromConfig(cfg)
	tableName = os.Getenv("TABLE_NAME")
	if tableName == "" {
		log.Println("Warning: TABLE_NAME environment variable is not set")
	}
}

// Simple JSON helper
func jsonResponse(w http.ResponseWriter, status int, data interface{}) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(data)
}

// Basic error checking helper
func errorIs(err error, target interface{}) bool {
	return errors.As(err, target)
}

func main() {
	mux := http.NewServeMux()

	// 1. Health Check
	mux.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		jsonResponse(w, 200, map[string]string{"status": "healthy"})
	})

	// 2. API Endpoint
	mux.HandleFunc("/api/v1/hello", func(w http.ResponseWriter, r *http.Request) {
		jsonResponse(w, 200, map[string]string{
			"message": "Hello from Panta Go Backend (DynamoDB Connected)!",
			"backend": "Go",
		})
	})

	// -------------------------------------------------------------------------
	// Recycling Requests API
	// -------------------------------------------------------------------------

	// GET /api/v1/requests - Get all requests
	mux.HandleFunc("/api/v1/requests", func(w http.ResponseWriter, r *http.Request) {
		// Enable CORS
		w.Header().Set("Access-Control-Allow-Origin", "*")
		if r.Method == http.MethodGet {
			out, err := svc.Scan(context.TODO(), &dynamodb.ScanInput{
				TableName: aws.String(tableName),
			})
			if err != nil {
				log.Printf("Failed to scan table: %v", err)
				jsonResponse(w, 500, map[string]string{"error": "Failed to fetch requests"})
				return
			}

			var requests []RecyclingRequest
			if err := attributevalue.UnmarshalListOfMaps(out.Items, &requests); err != nil {
				log.Printf("Failed to unmarshal storage: %v", err)
				jsonResponse(w, 500, map[string]string{"error": "Failed to parse data"})
				return
			}

			jsonResponse(w, 200, requests)
			return
		}

		// POST /api/v1/requests - Create a new request
		if r.Method == http.MethodPost {
			var req RecyclingRequest
			if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
				jsonResponse(w, 400, map[string]string{"error": "Invalid payload"})
				return
			}

			req.ID = time.Now().Format("20060102150405")
			if req.ImageUrl == "" {
				req.ImageUrl = "assets/images/generic.png"
			}
			req.Status = "pending"

			item, err := attributevalue.MarshalMap(req)
			if err != nil {
				jsonResponse(w, 500, map[string]string{"error": "Failed to marshal item"})
				return
			}

			_, err = svc.PutItem(context.TODO(), &dynamodb.PutItemInput{
				TableName: aws.String(tableName),
				Item:      item,
			})
			if err != nil {
				log.Printf("Failed to put item: %v", err)
				jsonResponse(w, 500, map[string]string{"error": "Failed to save request"})
				return
			}

			jsonResponse(w, 201, req)
			return
		}

		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
	})

	// POST /api/v1/requests/accept
	mux.HandleFunc("/api/v1/requests/accept", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
			return
		}

		var payload struct {
			ID string `json:"id"`
		}
		if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
			jsonResponse(w, 400, map[string]string{"error": "Invalid payload"})
			return
		}

		_, err := svc.UpdateItem(context.TODO(), &dynamodb.UpdateItemInput{
			TableName: aws.String(tableName),
			Key: map[string]types.AttributeValue{
				"id": &types.AttributeValueMemberS{Value: payload.ID},
			},
			UpdateExpression:          aws.String("SET #status = :accepted, helperId = :helperId"),
			ConditionExpression:       aws.String("#status = :pending"),
			ExpressionAttributeNames:  map[string]string{"#status": "status"},
			ExpressionAttributeValues: map[string]types.AttributeValue{
				":accepted": &types.AttributeValueMemberS{Value: "accepted"},
				":helperId": &types.AttributeValueMemberS{Value: "currentHelper"},
				":pending":  &types.AttributeValueMemberS{Value: "pending"},
			},
			ReturnValues: types.ReturnValueAllNew,
		})

		if err != nil {
			log.Printf("Failed to accept request: %v", err)
			var cfe *types.ConditionalCheckFailedException
			if errorIs(err, &cfe) {
				jsonResponse(w, 400, map[string]string{"error": "Request already accepted or not found"})
			} else {
				jsonResponse(w, 500, map[string]string{"error": "Failed to update request"})
			}
			return
		}

		jsonResponse(w, 200, map[string]string{"status": "accepted"})
	})

	// POST /api/v1/requests/complete
	mux.HandleFunc("/api/v1/requests/complete", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
			return
		}

		var payload struct {
			ID string `json:"id"`
		}
		if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
			jsonResponse(w, 400, map[string]string{"error": "Invalid payload"})
			return
		}

		_, err := svc.UpdateItem(context.TODO(), &dynamodb.UpdateItemInput{
			TableName: aws.String(tableName),
			Key: map[string]types.AttributeValue{
				"id": &types.AttributeValueMemberS{Value: payload.ID},
			},
			UpdateExpression:          aws.String("SET #status = :pickedUp"),
			ExpressionAttributeNames:  map[string]string{"#status": "status"},
			ExpressionAttributeValues: map[string]types.AttributeValue{
				":pickedUp": &types.AttributeValueMemberS{Value: "pickedUp"},
			},
		})

		if err != nil {
			log.Printf("Failed to complete request: %v", err)
			jsonResponse(w, 500, map[string]string{"error": "Failed to update request"})
			return
		}

		jsonResponse(w, 200, map[string]string{"status": "pickedUp"})
	})

	// POST /api/v1/requests/rate
	mux.HandleFunc("/api/v1/requests/rate", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
			return
		}

		var payload struct {
			ID     string  `json:"id"`
			Rating float64 `json:"rating"`
		}
		if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
			jsonResponse(w, 400, map[string]string{"error": "Invalid payload"})
			return
		}

		_, err := svc.UpdateItem(context.TODO(), &dynamodb.UpdateItemInput{
			TableName: aws.String(tableName),
			Key: map[string]types.AttributeValue{
				"id": &types.AttributeValueMemberS{Value: payload.ID},
			},
			UpdateExpression:          aws.String("SET isRated = :true"),
			ExpressionAttributeValues: map[string]types.AttributeValue{
				":true": &types.AttributeValueMemberBOOL{Value: true},
			},
		})

		if err != nil {
			log.Printf("Failed to rate request: %v", err)
			jsonResponse(w, 500, map[string]string{"error": "Failed to update request"})
			return
		}

		jsonResponse(w, 200, map[string]string{"status": "rated"})
	})

	// Hello World
	mux.HandleFunc("/helloworld", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "text/plain")
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("Hello World"))
	})

	// 3. Root Endpoint
	mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/" {
			http.NotFound(w, r)
			return
		}
		jsonResponse(w, 200, map[string]string{
			"message":   "Welcome to the Panta Go Backend",
			"endpoints": "/health, /api/v1/hello",
		})
	})

	// 4. Start Server
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}
	log.Printf("Server starting on port %s", port)
	if err := http.ListenAndServe(":"+port, mux); err != nil {
		log.Fatal(err)
	}
}


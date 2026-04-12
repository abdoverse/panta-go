package main

import (
	"context"
	"fmt"
	"log"
	"os"
	"strings"

	"firebase.google.com/go/v4/messaging"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb"
	"github.com/aws/aws-sdk-go-v2/service/s3"
)

var (
	svc             *dynamodb.Client
	s3Client        *s3.Client
	s3PresignClient *s3.PresignClient
	tableName       string
	imageBucketName string
	jwtSecret       = []byte(os.Getenv("JWT_SECRET"))
	hub             *Hub
	fcmClient       *messaging.Client
)

func initializeApplication() error {
	cfg, err := config.LoadDefaultConfig(context.TODO())
	if err != nil {
		return fmt.Errorf("load AWS SDK config: %w", err)
	}

	svc = dynamodb.NewFromConfig(cfg)
	s3Client = s3.NewFromConfig(cfg)
	s3PresignClient = s3.NewPresignClient(s3Client)
	tableName = os.Getenv("TABLE_NAME")
	imageBucketName = os.Getenv("IMAGE_BUCKET_NAME")
	if tableName == "" {
		log.Println("Warning: TABLE_NAME environment variable is not set")
	}
	if imageBucketName == "" {
		log.Println("Warning: IMAGE_BUCKET_NAME environment variable is not set")
	}

	resolvedSecret, err := resolveJWTSecret()
	if err != nil {
		return err
	}
	jwtSecret = resolvedSecret

	initFirebase()
	checkCredentials()
	return nil
}

func resolveJWTSecret() ([]byte, error) {
	if configuredSecret := strings.TrimSpace(os.Getenv("JWT_SECRET")); configuredSecret != "" {
		return []byte(configuredSecret), nil
	}

	if isProductionEnvironment() {
		return nil, fmt.Errorf("JWT_SECRET must be set when APP_ENV=production")
	}

	log.Println("Warning: JWT_SECRET is unset; using the local development fallback secret")
	return []byte("default-secret-key-change-me"), nil
}

func isProductionEnvironment() bool {
	env := strings.ToLower(strings.TrimSpace(os.Getenv("APP_ENV")))
	return env == "production"
}

func checkCredentials() {
	if os.Getenv("FIREBASE_SERVICE_ACCOUNT_JSON") != "" {
		log.Println("✅ Firebase service account injected via secret")
		return
	}

	path := os.Getenv("GOOGLE_APPLICATION_CREDENTIALS")
	if path == "" {
		log.Println("⚠️  FIREBASE_SERVICE_ACCOUNT_JSON and GOOGLE_APPLICATION_CREDENTIALS are both unset.")
		return
	}
	if _, err := os.Stat(path); err != nil {
		log.Printf("⚠️  Credentials file not found at %s: %v", path, err)
	} else {
		log.Printf("✅ Credentials file found at %s", path)
	}
}

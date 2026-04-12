package main

import (
	"context"
	"log"
	"os"

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

func init() {
	cfg, err := config.LoadDefaultConfig(context.TODO())
	if err != nil {
		log.Fatalf("unable to load SDK config, %v", err)
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
	if len(jwtSecret) == 0 {
		jwtSecret = []byte("default-secret-key-change-me")
	}

	initFirebase()
	checkCredentials()
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

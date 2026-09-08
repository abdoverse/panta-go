package config

import (
	"context"
	"fmt"
	"log"
	"os"
	"strings"

	firebase "firebase.google.com/go/v4"
	"firebase.google.com/go/v4/messaging"
	"github.com/MicahParks/keyfunc/v2"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb"
	"github.com/aws/aws-sdk-go-v2/service/s3"
	"google.golang.org/api/option"
)

// AppConfig holds all runtime dependencies for the application.
type AppConfig struct {
	DynamoDB        *dynamodb.Client
	S3              *s3.Client
	S3Presign       *s3.PresignClient
	FCM             *messaging.Client
	JWKS            *keyfunc.JWKS
	TableName       string
	ImageBucketName string
	JWTSecret       []byte
}

// Load initialises all external clients and returns a populated AppConfig.
func Load() (*AppConfig, error) {
	cfg := &AppConfig{}

	awsCfg, err := config.LoadDefaultConfig(context.TODO())
	if err != nil {
		return nil, fmt.Errorf("load AWS SDK config: %w", err)
	}

	cfg.DynamoDB = dynamodb.NewFromConfig(awsCfg)
	cfg.S3 = s3.NewFromConfig(awsCfg)
	cfg.S3Presign = s3.NewPresignClient(cfg.S3)

	cfg.TableName = os.Getenv("TABLE_NAME")
	if cfg.TableName == "" {
		log.Println("Warning: TABLE_NAME environment variable is not set")
	}

	cfg.ImageBucketName = os.Getenv("IMAGE_BUCKET_NAME")
	if cfg.ImageBucketName == "" {
		log.Println("Warning: IMAGE_BUCKET_NAME environment variable is not set")
	}

	jwtSecret, err := resolveJWTSecret()
	if err != nil {
		return nil, err
	}
	cfg.JWTSecret = jwtSecret

	cfg.FCM = initFirebase()
	checkCredentials()

	return cfg, nil
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

func initFirebase() *messaging.Client {
	ctx := context.Background()
	var opts []option.ClientOption

	if serviceAccountJSON := os.Getenv("FIREBASE_SERVICE_ACCOUNT_JSON"); serviceAccountJSON != "" {
		opts = append(opts, option.WithCredentialsJSON([]byte(serviceAccountJSON)))
		log.Println("Firebase service account loaded from injected secret")
	} else if credentialsPath := os.Getenv("GOOGLE_APPLICATION_CREDENTIALS"); credentialsPath != "" {
		opts = append(opts, option.WithCredentialsFile(credentialsPath))
		log.Printf("Firebase service account loaded from %s", credentialsPath)
	} else {
		log.Println("⚠️  Firebase service account not configured. Notifications will not work.")
	}

	app, err := firebase.NewApp(ctx, nil, opts...)
	if err != nil {
		log.Printf("Warning: error initializing Firebase App: %v. Notifications will not work.", err)
		return nil
	}

	fcmClient, err := app.Messaging(ctx)
	if err != nil {
		log.Printf("Warning: error getting Messaging client: %v", err)
		return nil
	}

	log.Println("Firebase Messaging initialized successfully")
	return fcmClient
}

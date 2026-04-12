package main

import (
	"context"
	"log"
	"os"
	"time"

	"firebase.google.com/go/v4"
	"firebase.google.com/go/v4/messaging"
	"google.golang.org/api/option"
)

func sendPushNotification(token string, title string, body string) {
	if fcmClient == nil {
		log.Println("Skipping notification: FCM client not initialized")
		return
	}
	if token == "" {
		return
	}

	start := time.Now()
	_, err := fcmClient.Send(context.Background(), &messaging.Message{
		Token: token,
		Notification: &messaging.Notification{
			Title: title,
			Body:  body,
		},
		Data: map[string]string{
			"click_action": "FLUTTER_NOTIFICATION_CLICK",
		},
	})
	if err != nil {
		log.Printf("Error sending FCM message: %v", err)
		return
	}

	log.Printf("Notification sent to %s (took %v)", token, time.Since(start))
}

func initFirebase() {
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
		return
	}

	fcmClient, err = app.Messaging(ctx)
	if err != nil {
		log.Printf("Warning: error getting Messaging client: %v", err)
		return
	}

	log.Println("Firebase Messaging initialized successfully")
}

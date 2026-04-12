package main

import (
	"log"
	"net/http"
	"os"
)

func main() {
	initJWKS()

	hub = newHub()
	go hub.run()

	mux := http.NewServeMux()
	registerRoutes(mux)

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}
	log.Printf("Server starting on port %s", port)

	handler := enableCORS(mux)
	certFile := os.Getenv("TLS_CERT_FILE")
	keyFile := os.Getenv("TLS_KEY_FILE")

	if certFile != "" && keyFile != "" {
		log.Printf("Starting in HTTPS mode...")
		if err := http.ListenAndServeTLS(":"+port, certFile, keyFile, handler); err != nil {
			log.Fatal(err)
		}
		return
	}

	log.Printf("Starting in HTTP mode (HTTPS not configured)...")
	if err := http.ListenAndServe(":"+port, handler); err != nil {
		log.Fatal(err)
	}
}

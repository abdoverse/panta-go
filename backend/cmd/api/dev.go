package main

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"time"
)

type LogEntry struct {
	Level   string `json:"level"`
	Message string `json:"message"`
	Time    string `json:"time"`
}

func registerDevRoutes(mux *http.ServeMux) {
	mux.HandleFunc("/api/v1/dev/logs", handleDevLogs)
}

func handleDevLogs(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost && r.Method != http.MethodOptions {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	if r.Method == http.MethodOptions {
		w.WriteHeader(http.StatusOK)
		return
	}

	var entry LogEntry
	if err := json.NewDecoder(r.Body).Decode(&entry); err != nil {
		http.Error(w, "Invalid JSON", http.StatusBadRequest)
		return
	}

	// Format the log line
	logLine := fmt.Sprintf("[%s] [%s] %s\n", time.Now().Format(time.RFC3339), entry.Level, entry.Message)

	// Ensure the directory exists
	logDir := "../../.agents/logs/local-run"
	os.MkdirAll(logDir, 0755)

	logFile := filepath.Join(logDir, "frontend_console.log")
	
	f, err := os.OpenFile(logFile, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
	if err != nil {
		log.Printf("Failed to open dev log file: %v", err)
		http.Error(w, "Internal error", http.StatusInternalServerError)
		return
	}
	defer f.Close()

	if _, err := f.WriteString(logLine); err != nil {
		log.Printf("Failed to write to dev log file: %v", err)
	}

	w.WriteHeader(http.StatusOK)
}

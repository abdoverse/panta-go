package main

import (
	"strings"
	"testing"
	"time"
)

func TestChatEncryptionRoundTrip(t *testing.T) {
	requestID := "req-test-123"
	originalText := "Hello, this is a secret chat message!"

	cipherText, err := encryptChatMessageText(originalText, requestID)
	if err != nil {
		t.Fatalf("Failed to encrypt message: %v", err)
	}

	if !strings.HasPrefix(cipherText, chatEncryptionPrefix) {
		t.Fatalf("Expected encrypted text to start with %s, got: %s", chatEncryptionPrefix, cipherText)
	}

	if strings.Contains(cipherText, originalText) {
		t.Fatalf("Ciphertext unexpectedly contains plaintext: %s", cipherText)
	}

	decrypted := decryptChatMessageText(cipherText, requestID)
	if decrypted != originalText {
		t.Fatalf("Decrypted text mismatch: got %q, expected %q", decrypted, originalText)
	}
}

func TestMultilingualAndEmojiIntegrity(t *testing.T) {
	requestID := "req-nordic-test"
	cases := []string{
		"Hej! Jag kommer ner med panten nu! Åker hiss 🚪",
		"🏃 Coming down now!",
		"📦 Left outside the door",
		"🚲 Arrived outside. Räksmörgås & blåbärspaj!",
		"Special UTF-8: äöüß ñ ç 漢字 1234 € & % #",
	}

	for _, tc := range cases {
		cipherText, err := encryptChatMessageText(tc, requestID)
		if err != nil {
			t.Fatalf("Failed to encrypt %q: %v", tc, err)
		}

		decrypted := decryptChatMessageText(cipherText, requestID)
		if decrypted != tc {
			t.Errorf("Decryption mismatch for %q: got %q", tc, decrypted)
		}
	}
}

func TestBackwardCompatibilityUnencryptedMessages(t *testing.T) {
	requestID := "req-legacy"
	legacyPlaintext := "Legacy message stored before encryption was enabled"

	decrypted := decryptChatMessageText(legacyPlaintext, requestID)
	if decrypted != legacyPlaintext {
		t.Fatalf("Expected legacy plaintext to be returned untouched, got: %s", decrypted)
	}
}

func TestGDPRRetentionExpiration(t *testing.T) {
	retentionDays := 30

	freshTime := time.Now().Add(-1 * time.Hour).UTC().Format(time.RFC3339)
	if isMessageExpired(freshTime, retentionDays) {
		t.Errorf("Expected 1-hour old message not to be expired")
	}

	expiredTime := time.Now().Add(-35 * 24 * time.Hour).UTC().Format(time.RFC3339)
	if !isMessageExpired(expiredTime, retentionDays) {
		t.Errorf("Expected 35-day old message to be expired")
	}

	messages := []ChatMessage{
		{
			ID:        "msg-fresh",
			Text:      "Fresh message",
			CreatedAt: freshTime,
		},
		{
			ID:        "msg-expired",
			Text:      "Expired message",
			CreatedAt: expiredTime,
		},
	}

	sanitized := sanitizeAndDecryptMessages(messages, "req-retention")
	if len(sanitized) != 1 {
		t.Fatalf("Expected 1 sanitized message, got %d", len(sanitized))
	}
	if sanitized[0].ID != "msg-fresh" {
		t.Errorf("Expected msg-fresh to remain, got %s", sanitized[0].ID)
	}
}

package main

import (
	"context"
	"crypto/aes"
	"crypto/cipher"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"fmt"
	"io"
	"log"
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb/types"
)

const (
	chatEncryptionPrefix  = "enc:v1:"
	defaultRetentionDays  = 30
	fallbackEncryptionKey = "panta-default-chat-encryption-key-for-dev"
)

// getChatEncryptionKey returns a 32-byte (256-bit) AES key.
// It prioritizes CHAT_ENCRYPTION_KEY, then falls back to hashing the JWT secret or fallback key.
func getChatEncryptionKey() []byte {
	if keyEnv := strings.TrimSpace(os.Getenv("CHAT_ENCRYPTION_KEY")); keyEnv != "" {
		if len(keyEnv) == 32 {
			return []byte(keyEnv)
		}
		hash := sha256.Sum256([]byte(keyEnv))
		return hash[:]
	}

	if len(jwtSecret) > 0 {
		hash := sha256.Sum256(append(jwtSecret, []byte("-chat-enc-salt")...))
		return hash[:]
	}

	hash := sha256.Sum256([]byte(fallbackEncryptionKey))
	return hash[:]
}

// encryptChatMessageText encrypts UTF-8 plaintext using AES-256-GCM with a random 12-byte nonce.
// RequestID is included as additional authenticated data (AAD) to prevent cross-request ciphertext transplanting.
func encryptChatMessageText(plainText string, requestID string) (string, error) {
	if plainText == "" {
		return "", nil
	}

	key := getChatEncryptionKey()
	block, err := aes.NewCipher(key)
	if err != nil {
		return "", fmt.Errorf("create aes cipher: %w", err)
	}

	aesGCM, err := cipher.NewGCM(block)
	if err != nil {
		return "", fmt.Errorf("create gcm: %w", err)
	}

	nonce := make([]byte, aesGCM.NonceSize())
	if _, err := io.ReadFull(rand.Reader, nonce); err != nil {
		return "", fmt.Errorf("generate nonce: %w", err)
	}

	var aad []byte
	if requestID != "" {
		aad = []byte(requestID)
	}

	// Encrypt UTF-8 bytes preserving all special characters and emojis
	sealed := aesGCM.Seal(nil, nonce, []byte(plainText), aad)

	// Combine nonce + sealed payload
	combined := make([]byte, len(nonce)+len(sealed))
	copy(combined[:len(nonce)], nonce)
	copy(combined[len(nonce):], sealed)

	return chatEncryptionPrefix + base64.StdEncoding.EncodeToString(combined), nil
}

// decryptChatMessageText decrypts ciphertext encrypted with encryptChatMessageText.
// If the text is unencrypted (legacy messages), it is returned unmodified for seamless backwards compatibility.
func decryptChatMessageText(cipherText string, requestID string) string {
	if !strings.HasPrefix(cipherText, chatEncryptionPrefix) {
		return cipherText
	}

	rawB64 := strings.TrimPrefix(cipherText, chatEncryptionPrefix)
	data, err := base64.StdEncoding.DecodeString(rawB64)
	if err != nil {
		log.Printf("Failed to base64 decode chat ciphertext: %v", err)
		return cipherText
	}

	key := getChatEncryptionKey()
	block, err := aes.NewCipher(key)
	if err != nil {
		log.Printf("Failed to create aes cipher for decryption: %v", err)
		return cipherText
	}

	aesGCM, err := cipher.NewGCM(block)
	if err != nil {
		log.Printf("Failed to create gcm for decryption: %v", err)
		return cipherText
	}

	nonceSize := aesGCM.NonceSize()
	if len(data) < nonceSize {
		log.Printf("Ciphertext too short to contain nonce")
		return cipherText
	}

	nonce := data[:nonceSize]
	ciphertext := data[nonceSize:]

	var aad []byte
	if requestID != "" {
		aad = []byte(requestID)
	}

	plainBytes, err := aesGCM.Open(nil, nonce, ciphertext, aad)
	if err != nil {
		// Fallback: try with empty AAD in case message was encrypted without requestID binding
		if fallbackBytes, fallbackErr := aesGCM.Open(nil, nonce, ciphertext, nil); fallbackErr == nil {
			return string(fallbackBytes)
		}
		log.Printf("Failed to decrypt chat message with AES-256-GCM: %v", err)
		return "[Encrypted message]"
	}

	return string(plainBytes)
}

// getChatRetentionDays returns the configured GDPR retention window in days.
func getChatRetentionDays() int {
	if val := strings.TrimSpace(os.Getenv("CHAT_RETENTION_DAYS")); val != "" {
		if days, err := strconv.Atoi(val); err == nil && days > 0 {
			return days
		}
	}
	return defaultRetentionDays
}

// isMessageExpired checks if a message exceeds the GDPR retention window.
func isMessageExpired(createdAt string, retentionDays int) bool {
	if createdAt == "" {
		return false
	}
	parsedTime, err := time.Parse(time.RFC3339, createdAt)
	if err != nil {
		return false
	}
	return time.Since(parsedTime) > time.Duration(retentionDays)*24*time.Hour
}

// sanitizeAndDecryptMessages decrypts encrypted messages and drops expired ones per GDPR policy.
func sanitizeAndDecryptMessages(messages []ChatMessage, requestID string) []ChatMessage {
	if len(messages) == 0 {
		return []ChatMessage{}
	}

	retentionDays := getChatRetentionDays()
	result := make([]ChatMessage, 0, len(messages))

	for _, msg := range messages {
		if isMessageExpired(msg.CreatedAt, retentionDays) {
			continue
		}
		msg.Text = decryptChatMessageText(msg.Text, requestID)
		result = append(result, msg)
	}

	return result
}

// eraseChatHistory fulfills GDPR Article 17 (Right to Erasure) by atomically wiping all chat messages for a request.
func eraseChatHistory(ctx context.Context, requestID string) error {
	if svc == nil || tableName == "" {
		return fmt.Errorf("DynamoDB service or table name not configured")
	}

	_, err := svc.UpdateItem(ctx, &dynamodb.UpdateItemInput{
		TableName: aws.String(tableName),
		Key: map[string]types.AttributeValue{
			"id": &types.AttributeValueMemberS{Value: requestID},
		},
		UpdateExpression: aws.String("SET #msgs = :empty_list"),
		ExpressionAttributeNames: map[string]string{
			"#msgs": "messages",
		},
		ExpressionAttributeValues: map[string]types.AttributeValue{
			":empty_list": &types.AttributeValueMemberL{Value: []types.AttributeValue{}},
		},
	})
	return err
}

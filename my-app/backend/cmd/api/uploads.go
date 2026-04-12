package main

import (
	"bytes"
	"context"
	"crypto/rand"
	"encoding/base64"
	"encoding/hex"
	"fmt"
	"io"
	"log"
	"net/http"
	pathpkg "path"
	"strings"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/service/s3"
)

const (
	requestImageUploadLimitBytes = 8 << 20
	requestImageURLTTL           = 24 * time.Hour
)

var allowedImageContentTypes = map[string]string{
	"image/jpeg": "jpg",
	"image/png":  "png",
	"image/webp": "webp",
	"image/gif":  "gif",
}

func registerUploadRoutes(mux *http.ServeMux) {
	mux.HandleFunc("/api/v1/uploads/request-image", authMiddleware(handleRequestImageUpload))
}

func newRequestID() string {
	return fmt.Sprintf("%s-%s", time.Now().UTC().Format("20060102150405"), randomHex(8))
}

func randomHex(length int) string {
	if length <= 0 {
		return ""
	}

	buf := make([]byte, (length+1)/2)
	if _, err := rand.Read(buf); err != nil {
		log.Fatalf("failed to generate random bytes: %v", err)
	}

	return hex.EncodeToString(buf)[:length]
}

func sanitizePathSegment(value string) string {
	trimmed := strings.TrimSpace(value)
	if trimmed == "" {
		return "anonymous"
	}

	replacer := strings.NewReplacer("/", "-", "\\", "-", " ", "-", ":", "-")
	return replacer.Replace(trimmed)
}

func tempUploadPrefix(ownerID string) string {
	return fmt.Sprintf("users/%s/request-images/uploads/", sanitizePathSegment(ownerID))
}

func finalRequestImageKey(requestID string, extension string) string {
	return fmt.Sprintf("requests/%s/images/original.%s", sanitizePathSegment(requestID), strings.TrimPrefix(extension, "."))
}

func parseS3ImageReference(reference string) (bucket string, key string, ok bool) {
	if !strings.HasPrefix(reference, "s3://") {
		return "", "", false
	}

	trimmed := strings.TrimPrefix(reference, "s3://")
	parts := strings.SplitN(trimmed, "/", 2)
	if len(parts) != 2 || parts[0] == "" || parts[1] == "" {
		return "", "", false
	}

	return parts[0], parts[1], true
}

func resolveImageURL(ctx context.Context, storedValue string) (string, error) {
	storedValue = strings.TrimSpace(storedValue)
	if storedValue == "" {
		return storedValue, nil
	}

	bucket := imageBucketName
	key := storedValue
	if parsedBucket, parsedKey, ok := parseS3ImageReference(storedValue); ok {
		bucket = parsedBucket
		key = parsedKey
	} else if strings.HasPrefix(storedValue, "http") || strings.HasPrefix(storedValue, "data:") || strings.HasPrefix(storedValue, "assets/") {
		return storedValue, nil
	}

	if s3PresignClient == nil {
		return "", fmt.Errorf("s3 presign client is not configured")
	}

	presigned, err := s3PresignClient.PresignGetObject(ctx, &s3.GetObjectInput{
		Bucket: aws.String(bucket),
		Key:    aws.String(key),
	}, func(options *s3.PresignOptions) {
		options.Expires = requestImageURLTTL
	})
	if err != nil {
		return "", fmt.Errorf("presign image %s: %w", key, err)
	}

	return presigned.URL, nil
}

func enrichRequestForClient(ctx context.Context, request *RecyclingRequest) error {
	resolvedURL, err := resolveImageURL(ctx, request.ImageUrl)
	if err != nil {
		return err
	}
	request.ImageUrl = resolvedURL
	return nil
}

func imageExtensionForContentType(contentType string) (string, bool) {
	normalized := strings.ToLower(strings.TrimSpace(contentType))
	ext, ok := allowedImageContentTypes[normalized]
	return ext, ok
}

func uploadImageBytes(ctx context.Context, bucket string, key string, payload []byte, contentType string, metadata map[string]string) (string, error) {
	if s3Client == nil {
		return "", fmt.Errorf("s3 client is not configured")
	}
	if bucket == "" {
		return "", fmt.Errorf("image bucket is not configured")
	}

	_, err := s3Client.PutObject(ctx, &s3.PutObjectInput{
		Bucket:      aws.String(bucket),
		Key:         aws.String(key),
		Body:        bytes.NewReader(payload),
		ContentType: aws.String(contentType),
		Metadata:    metadata,
	})
	if err != nil {
		return "", fmt.Errorf("put object %s: %w", key, err)
	}

	return key, nil
}

func finalizeUploadedRequestImage(ctx context.Context, ownerID string, requestID string, uploadKey string) (string, error) {
	if imageBucketName == "" {
		return "", fmt.Errorf("image bucket is not configured")
	}

	expectedPrefix := tempUploadPrefix(ownerID)
	if !strings.HasPrefix(uploadKey, expectedPrefix) {
		return "", fmt.Errorf("upload key does not belong to the current user")
	}

	extension := pathpkg.Ext(uploadKey)
	if extension == "" {
		return "", fmt.Errorf("upload key is missing a file extension")
	}

	finalKey := finalRequestImageKey(requestID, extension)
	copySource := fmt.Sprintf("%s/%s", imageBucketName, uploadKey)
	if _, err := s3Client.CopyObject(ctx, &s3.CopyObjectInput{
		Bucket:            aws.String(imageBucketName),
		CopySource:        aws.String(copySource),
		Key:               aws.String(finalKey),
		MetadataDirective: "COPY",
	}); err != nil {
		return "", fmt.Errorf("copy uploaded image: %w", err)
	}
	if _, err := s3Client.DeleteObject(ctx, &s3.DeleteObjectInput{
		Bucket: aws.String(imageBucketName),
		Key:    aws.String(uploadKey),
	}); err != nil {
		return "", fmt.Errorf("delete temporary upload: %w", err)
	}

	return finalKey, nil
}

func parseDataURLImage(payload string) ([]byte, string, error) {
	if !strings.HasPrefix(payload, "data:") {
		return nil, "", fmt.Errorf("image payload is not a data URL")
	}

	header, encoded, found := strings.Cut(payload, ",")
	if !found {
		return nil, "", fmt.Errorf("invalid data URL payload")
	}

	contentType := strings.TrimPrefix(header, "data:")
	contentType = strings.TrimSuffix(contentType, ";base64")
	if _, ok := imageExtensionForContentType(contentType); !ok {
		return nil, "", fmt.Errorf("unsupported image content type: %s", contentType)
	}

	decoded, err := base64.StdEncoding.DecodeString(encoded)
	if err != nil {
		return nil, "", fmt.Errorf("decode base64 image: %w", err)
	}

	return decoded, contentType, nil
}

func prepareRequestImageReference(ctx context.Context, claims *Claims, requestID string, uploadKey string, imageURL string) (string, error) {
	switch {
	case strings.TrimSpace(uploadKey) != "":
		return finalizeUploadedRequestImage(ctx, claims.helperID(), requestID, strings.TrimSpace(uploadKey))
	case strings.HasPrefix(strings.TrimSpace(imageURL), "data:"):
		imageBytes, contentType, err := parseDataURLImage(strings.TrimSpace(imageURL))
		if err != nil {
			return "", err
		}

		extension, _ := imageExtensionForContentType(contentType)
		return uploadImageBytes(
			ctx,
			imageBucketName,
			finalRequestImageKey(requestID, extension),
			imageBytes,
			contentType,
			map[string]string{
				"request-id":  requestID,
				"uploaded-by": sanitizePathSegment(claims.helperID()),
				"source":      "legacy-data-url",
			},
		)
	case strings.TrimSpace(imageURL) == "":
		return "assets/images/generic.png", nil
	default:
		return imageURL, nil
	}
}

func handleRequestImageUpload(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	claims, ok := currentClaims(r)
	if !ok {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}
	if imageBucketName == "" {
		jsonResponse(w, http.StatusInternalServerError, map[string]string{"error": "Image storage is not configured"})
		return
	}

	r.Body = http.MaxBytesReader(w, r.Body, requestImageUploadLimitBytes+(1<<20))
	file, header, err := r.FormFile("file")
	if err != nil {
		jsonResponse(w, http.StatusBadRequest, map[string]string{"error": "Request image file is required"})
		return
	}
	defer file.Close()

	fileBytes, err := io.ReadAll(io.LimitReader(file, requestImageUploadLimitBytes+1))
	if err != nil {
		jsonResponse(w, http.StatusBadRequest, map[string]string{"error": "Failed to read request image"})
		return
	}
	if len(fileBytes) == 0 {
		jsonResponse(w, http.StatusBadRequest, map[string]string{"error": "Request image is empty"})
		return
	}
	if len(fileBytes) > requestImageUploadLimitBytes {
		jsonResponse(w, http.StatusBadRequest, map[string]string{"error": "Request image exceeds the 8 MB limit"})
		return
	}

	contentType := http.DetectContentType(fileBytes)
	extension, ok := imageExtensionForContentType(contentType)
	if !ok {
		jsonResponse(w, http.StatusBadRequest, map[string]string{"error": "Unsupported image type. Use JPEG, PNG, WebP, or GIF."})
		return
	}

	filename := strings.TrimSpace(header.Filename)
	if filename == "" {
		filename = "request-image"
	}
	if existingExtension := pathpkg.Ext(filename); existingExtension != "" {
		filename = strings.TrimSuffix(filename, existingExtension)
	}
	filename = sanitizePathSegment(filename)

	uploadKey := fmt.Sprintf(
		"%s%s-%s.%s",
		tempUploadPrefix(claims.helperID()),
		time.Now().UTC().Format("2006/01/02/150405"),
		fmt.Sprintf("%s-%s", filename, randomHex(8)),
		extension,
	)

	if _, err := uploadImageBytes(
		r.Context(),
		imageBucketName,
		uploadKey,
		fileBytes,
		contentType,
		map[string]string{
			"uploaded-by": sanitizePathSegment(claims.helperID()),
			"source":      "multipart-upload",
		},
	); err != nil {
		log.Printf("Failed to upload request image: %v", err)
		jsonResponse(w, http.StatusInternalServerError, map[string]string{"error": "Failed to upload request image"})
		return
	}

	jsonResponse(w, http.StatusCreated, map[string]string{"uploadKey": uploadKey})
}

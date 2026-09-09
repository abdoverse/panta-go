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
	"net/url"
	pathpkg "path"
	"strings"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/feature/dynamodb/attributevalue"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb/types"
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
	mux.HandleFunc("/api/v1/images/", handleServeImage)
	mux.HandleFunc("/api/v1/requests/image", handleServeRequestImage)
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
	trimmed := strings.TrimSpace(reference)
	if trimmed == "" {
		return "", "", false
	}

	// 1. Check for s3:// bucket/key
	if strings.HasPrefix(trimmed, "s3://") {
		withoutPrefix := strings.TrimPrefix(trimmed, "s3://")
		parts := strings.SplitN(withoutPrefix, "/", 2)
		if len(parts) == 2 && parts[0] != "" && parts[1] != "" {
			return parts[0], parts[1], true
		}
		return "", "", false
	}

	// 2. Check for AWS Management Console URL
	// e.g. https://269172689438-eywgkjb7.eu-north-1.console.aws.amazon.com/s3/object/panta-request-images?region=eu-north-1&prefix=requests/20260909190032-85a15cb9/images/original.jpg
	// e.g. https://eu-north-1.console.aws.amazon.com/s3/buckets/panta-request-images?prefix=requests/...
	if strings.Contains(trimmed, ".console.aws.amazon.com/s3/") || strings.Contains(trimmed, "console.aws.amazon.com") {
		parsed, err := url.Parse(trimmed)
		if err == nil {
			extractedBucket := ""
			extractedKey := ""

			if prefix := parsed.Query().Get("prefix"); prefix != "" {
				extractedKey = prefix
			} else if k := parsed.Query().Get("key"); k != "" {
				extractedKey = k
			}

			pathParts := strings.Split(strings.Trim(parsed.Path, "/"), "/")
			for i, seg := range pathParts {
				if (seg == "object" || seg == "buckets") && i+1 < len(pathParts) {
					extractedBucket = pathParts[i+1]
					if extractedKey == "" && i+2 < len(pathParts) {
						extractedKey = strings.Join(pathParts[i+2:], "/")
					}
					break
				}
			}

			if extractedBucket == "" {
				extractedBucket = imageBucketName
			}

			if extractedKey != "" {
				return extractedBucket, extractedKey, true
			}
		}
	}

	// 3. Check for S3 HTTP / HTTPS URLs (virtual-hosted style or path style)
	if strings.HasPrefix(trimmed, "http://") || strings.HasPrefix(trimmed, "https://") {
		parsed, err := url.Parse(trimmed)
		if err == nil {
			host := parsed.Hostname()
			path := strings.TrimPrefix(parsed.Path, "/")

			// Check virtual-hosted style: <bucket>.s3.<region>.amazonaws.com/<key>
			if strings.Contains(host, ".s3.") || strings.HasSuffix(host, ".s3.amazonaws.com") {
				idx := strings.Index(host, ".s3.")
				if idx == -1 {
					idx = strings.Index(host, ".s3.amazonaws.com")
				}
				if idx > 0 && path != "" {
					return host[:idx], path, true
				}
			}

			// Check path-style: s3.<region>.amazonaws.com/<bucket>/<key>
			if strings.HasPrefix(host, "s3.") || host == "s3.amazonaws.com" {
				parts := strings.SplitN(path, "/", 2)
				if len(parts) == 2 && parts[0] != "" && parts[1] != "" {
					return parts[0], parts[1], true
				}
			}

			// Check if it is a Panta API URL: e.g. http://.../api/v1/images/{key}
			if strings.Contains(path, "api/v1/images/") {
				idx := strings.Index(path, "api/v1/images/")
				keyFromPath := path[idx+len("api/v1/images/"):]
				if keyFromPath != "" {
					return imageBucketName, keyFromPath, true
				}
			}
		}
	}

	// 4. Check for relative API path: /api/v1/images/{key}
	if strings.HasPrefix(trimmed, "/api/v1/images/") {
		keyFromPath := strings.TrimPrefix(trimmed, "/api/v1/images/")
		if keyFromPath != "" {
			return imageBucketName, keyFromPath, true
		}
	}

	// 5. Check for known S3 key prefixes in Panta: requests/ or users/
	if strings.HasPrefix(trimmed, "requests/") || strings.HasPrefix(trimmed, "users/") {
		return imageBucketName, trimmed, true
	}

	return "", "", false
}

func resolveImageURL(ctx context.Context, storedValue string) (string, error) {
	storedValue = strings.TrimSpace(storedValue)
	if storedValue == "" {
		return storedValue, nil
	}

	if storedValue == "assets/images/generic.png" || strings.HasPrefix(storedValue, "data:") {
		return storedValue, nil
	}

	// If it matches an S3 image reference (key, s3://, console url, or direct S3 URL), resolve to proxy route
	if _, key, ok := parseS3ImageReference(storedValue); ok {
		return fmt.Sprintf("/api/v1/images/%s", strings.TrimPrefix(key, "/")), nil
	}

	// If it's already an /api/v1/ path
	if strings.HasPrefix(storedValue, "/api/v1/") {
		return storedValue, nil
	}

	// External HTTP URLs that are not AWS Console or S3
	if strings.HasPrefix(storedValue, "http://") || strings.HasPrefix(storedValue, "https://") {
		return storedValue, nil
	}

	// Fallback for relative path
	return fmt.Sprintf("/api/v1/images/%s", strings.TrimPrefix(storedValue, "/")), nil
}

func enrichRequestForClient(ctx context.Context, request *RecyclingRequest) error {
	resolvedURL, err := resolveImageURL(ctx, request.ImageUrl)
	if err != nil {
		return err
	}
	request.ImageUrl = resolvedURL

	if request.ReceiptImageUrl != "" {
		if rUrl, err := resolveImageURL(ctx, request.ReceiptImageUrl); err == nil {
			request.ReceiptImageUrl = rUrl
		}
	}
	if request.DropoffPhotoUrl != "" {
		if dUrl, err := resolveImageURL(ctx, request.DropoffPhotoUrl); err == nil {
			request.DropoffPhotoUrl = dUrl
		}
	}

	if len(request.Messages) > 0 {
		request.Messages = sanitizeAndDecryptMessages(request.Messages, request.ID)
	}
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
		trimmed := strings.TrimSpace(imageURL)
		if _, key, ok := parseS3ImageReference(trimmed); ok {
			return key, nil
		}
		return trimmed, nil
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

func getRequestItemByID(ctx context.Context, requestID string) (*RecyclingRequest, error) {
	if svc == nil || tableName == "" {
		return nil, fmt.Errorf("database not configured")
	}
	out, err := svc.GetItem(ctx, &dynamodb.GetItemInput{
		TableName: aws.String(tableName),
		Key: map[string]types.AttributeValue{
			"id": &types.AttributeValueMemberS{Value: requestID},
		},
	})
	if err != nil {
		return nil, err
	}
	if len(out.Item) == 0 {
		return nil, nil
	}
	var req RecyclingRequest
	if err := attributevalue.UnmarshalMap(out.Item, &req); err != nil {
		return nil, err
	}
	return &req, nil
}

func handleServeImage(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet && r.Method != http.MethodHead && r.Method != http.MethodOptions {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	w.Header().Set("Access-Control-Allow-Origin", "*")
	w.Header().Set("Access-Control-Allow-Methods", "GET, HEAD, OPTIONS")
	w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization")
	if r.Method == http.MethodOptions {
		w.WriteHeader(http.StatusOK)
		return
	}

	rawKey := strings.TrimPrefix(r.URL.Path, "/api/v1/images/")
	key, err := url.PathUnescape(rawKey)
	if err != nil {
		http.Error(w, "Invalid image key encoding", http.StatusBadRequest)
		return
	}
	key = strings.TrimSpace(key)
	key = strings.TrimPrefix(key, "/")

	if key == "" || strings.Contains(key, "..") {
		http.Error(w, "Invalid image key", http.StatusBadRequest)
		return
	}

	if s3Client == nil || imageBucketName == "" {
		http.Error(w, "Image storage is not configured", http.StatusInternalServerError)
		return
	}

	bucket := imageBucketName
	if b, k, ok := parseS3ImageReference(key); ok {
		if b != "" {
			bucket = b
		}
		key = k
	}

	output, err := s3Client.GetObject(r.Context(), &s3.GetObjectInput{
		Bucket: aws.String(bucket),
		Key:    aws.String(key),
	})
	if err != nil {
		log.Printf("Failed to get image from S3 (bucket: %s, key: %s): %v", bucket, key, err)
		http.Error(w, "Image not found", http.StatusNotFound)
		return
	}
	defer output.Body.Close()

	contentType := "image/jpeg"
	if output.ContentType != nil && *output.ContentType != "" {
		contentType = *output.ContentType
	}
	w.Header().Set("Content-Type", contentType)

	if output.ContentLength != nil && *output.ContentLength > 0 {
		w.Header().Set("Content-Length", fmt.Sprintf("%d", *output.ContentLength))
	}
	if output.ETag != nil && *output.ETag != "" {
		w.Header().Set("ETag", *output.ETag)
	}
	w.Header().Set("Cache-Control", "public, max-age=86400")

	if r.Method == http.MethodHead {
		w.WriteHeader(http.StatusOK)
		return
	}

	if _, err := io.Copy(w, output.Body); err != nil {
		log.Printf("Failed to stream image body: %v", err)
	}
}

func handleServeRequestImage(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet && r.Method != http.MethodHead && r.Method != http.MethodOptions {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	w.Header().Set("Access-Control-Allow-Origin", "*")
	w.Header().Set("Access-Control-Allow-Methods", "GET, HEAD, OPTIONS")
	w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization")
	if r.Method == http.MethodOptions {
		w.WriteHeader(http.StatusOK)
		return
	}

	query := r.URL.Query()
	requestID := strings.TrimSpace(query.Get("id"))
	if requestID == "" {
		requestID = strings.TrimSpace(query.Get("requestId"))
	}
	key := strings.TrimSpace(query.Get("key"))

	if requestID == "" && key == "" {
		http.Error(w, "Missing id or key query parameter", http.StatusBadRequest)
		return
	}

	if requestID != "" {
		req, err := getRequestItemByID(r.Context(), requestID)
		if err != nil {
			log.Printf("Failed to load request %s for image: %v", requestID, err)
			http.Error(w, "Request not found", http.StatusNotFound)
			return
		}
		if req == nil || req.ImageUrl == "" || req.ImageUrl == "assets/images/generic.png" {
			http.Error(w, "Request does not have an uploaded image", http.StatusNotFound)
			return
		}
		if _, parsedKey, ok := parseS3ImageReference(req.ImageUrl); ok {
			key = parsedKey
		} else {
			key = req.ImageUrl
		}
	}

	key = strings.TrimPrefix(key, "/")
	if s3Client == nil || imageBucketName == "" {
		http.Error(w, "Image storage is not configured", http.StatusInternalServerError)
		return
	}

	bucket := imageBucketName
	if b, k, ok := parseS3ImageReference(key); ok {
		if b != "" {
			bucket = b
		}
		key = k
	}

	output, err := s3Client.GetObject(r.Context(), &s3.GetObjectInput{
		Bucket: aws.String(bucket),
		Key:    aws.String(key),
	})
	if err != nil {
		log.Printf("Failed to get request image from S3 (bucket: %s, key: %s): %v", bucket, key, err)
		http.Error(w, "Image not found", http.StatusNotFound)
		return
	}
	defer output.Body.Close()

	contentType := "image/jpeg"
	if output.ContentType != nil && *output.ContentType != "" {
		contentType = *output.ContentType
	}
	w.Header().Set("Content-Type", contentType)

	if output.ContentLength != nil && *output.ContentLength > 0 {
		w.Header().Set("Content-Length", fmt.Sprintf("%d", *output.ContentLength))
	}
	if output.ETag != nil && *output.ETag != "" {
		w.Header().Set("ETag", *output.ETag)
	}
	w.Header().Set("Cache-Control", "public, max-age=86400")

	if r.Method == http.MethodHead {
		w.WriteHeader(http.StatusOK)
		return
	}

	if _, err := io.Copy(w, output.Body); err != nil {
		log.Printf("Failed to stream request image body: %v", err)
	}
}

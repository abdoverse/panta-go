package main

import (
	"context"
	"testing"
)

func TestParseS3ImageReference(t *testing.T) {
	t.Parallel()

	testCases := []struct {
		name       string
		input      string
		wantBucket string
		wantKey    string
		wantOk     bool
	}{
		{
			name:       "AWS Console S3 object URL with prefix param",
			input:      "https://269172689438-eywgkjb7.eu-north-1.console.aws.amazon.com/s3/object/panta-request-images?region=eu-north-1&prefix=requests/20260909190032-85a15cb9/images/original.jpg",
			wantBucket: "panta-request-images",
			wantKey:    "requests/20260909190032-85a15cb9/images/original.jpg",
			wantOk:     true,
		},
		{
			name:       "AWS Console S3 bucket URL with prefix param",
			input:      "https://eu-north-1.console.aws.amazon.com/s3/buckets/panta-request-images?prefix=requests/test-123/images/original.png",
			wantBucket: "panta-request-images",
			wantKey:    "requests/test-123/images/original.png",
			wantOk:     true,
		},
		{
			name:       "AWS S3 URI format",
			input:      "s3://panta-request-images/requests/20260909190032-85a15cb9/images/original.jpg",
			wantBucket: "panta-request-images",
			wantKey:    "requests/20260909190032-85a15cb9/images/original.jpg",
			wantOk:     true,
		},
		{
			name:       "S3 virtual hosted URL with presigned params",
			input:      "https://panta-request-images.s3.eu-north-1.amazonaws.com/requests/20260909190032-85a15cb9/images/original.jpg?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=ASIAT...",
			wantBucket: "panta-request-images",
			wantKey:    "requests/20260909190032-85a15cb9/images/original.jpg",
			wantOk:     true,
		},
		{
			name:       "S3 path style URL",
			input:      "https://s3.eu-north-1.amazonaws.com/panta-request-images/requests/20260909190032-85a15cb9/images/original.jpg",
			wantBucket: "panta-request-images",
			wantKey:    "requests/20260909190032-85a15cb9/images/original.jpg",
			wantOk:     true,
		},
		{
			name:       "Relative API proxy image URL",
			input:      "/api/v1/images/requests/20260909190032-85a15cb9/images/original.jpg",
			wantBucket: "",
			wantKey:    "requests/20260909190032-85a15cb9/images/original.jpg",
			wantOk:     true,
		},
		{
			name:       "Direct S3 key for requests",
			input:      "requests/20260909190032-85a15cb9/images/original.jpg",
			wantBucket: "",
			wantKey:    "requests/20260909190032-85a15cb9/images/original.jpg",
			wantOk:     true,
		},
		{
			name:       "Direct S3 key for user uploads",
			input:      "users/user-123/request-images/uploads/sample.jpg",
			wantBucket: "",
			wantKey:    "users/user-123/request-images/uploads/sample.jpg",
			wantOk:     true,
		},
		{
			name:       "Generic fallback asset",
			input:      "assets/images/generic.png",
			wantBucket: "",
			wantKey:    "",
			wantOk:     false,
		},
		{
			name:       "Data URL",
			input:      "data:image/jpeg;base64,/9j/4AAQSkZJRg==",
			wantBucket: "",
			wantKey:    "",
			wantOk:     false,
		},
		{
			name:       "Empty string",
			input:      "",
			wantBucket: "",
			wantKey:    "",
			wantOk:     false,
		},
	}

	for _, tc := range testCases {
		tc := tc
		t.Run(tc.name, func(t *testing.T) {
			t.Parallel()
			bucket, key, ok := parseS3ImageReference(tc.input)
			if ok != tc.wantOk {
				t.Fatalf("parseS3ImageReference(%q) ok = %v, want %v", tc.input, ok, tc.wantOk)
			}
			if tc.wantOk {
				if tc.wantBucket != "" && bucket != tc.wantBucket {
					t.Errorf("parseS3ImageReference(%q) bucket = %q, want %q", tc.input, bucket, tc.wantBucket)
				}
				if key != tc.wantKey {
					t.Errorf("parseS3ImageReference(%q) key = %q, want %q", tc.input, key, tc.wantKey)
				}
			}
		})
	}
}

func TestResolveImageURL(t *testing.T) {
	t.Parallel()

	ctx := context.Background()

	testCases := []struct {
		name    string
		input   string
		wantURL string
	}{
		{
			name:    "AWS Console URL resolves to proxy route",
			input:   "https://269172689438-eywgkjb7.eu-north-1.console.aws.amazon.com/s3/object/panta-request-images?region=eu-north-1&prefix=requests/20260909190032-85a15cb9/images/original.jpg",
			wantURL: "/api/v1/images/requests/20260909190032-85a15cb9/images/original.jpg",
		},
		{
			name:    "S3 URI resolves to proxy route",
			input:   "s3://panta-request-images/requests/20260909190032-85a15cb9/images/original.jpg",
			wantURL: "/api/v1/images/requests/20260909190032-85a15cb9/images/original.jpg",
		},
		{
			name:    "Direct key resolves to proxy route",
			input:   "requests/20260909190032-85a15cb9/images/original.jpg",
			wantURL: "/api/v1/images/requests/20260909190032-85a15cb9/images/original.jpg",
		},
		{
			name:    "Already proxy route is preserved",
			input:   "/api/v1/images/requests/20260909190032-85a15cb9/images/original.jpg",
			wantURL: "/api/v1/images/requests/20260909190032-85a15cb9/images/original.jpg",
		},
		{
			name:    "Generic placeholder asset is preserved",
			input:   "assets/images/generic.png",
			wantURL: "assets/images/generic.png",
		},
		{
			name:    "Empty input is preserved",
			input:   "",
			wantURL: "",
		},
	}

	for _, tc := range testCases {
		tc := tc
		t.Run(tc.name, func(t *testing.T) {
			t.Parallel()
			got, err := resolveImageURL(ctx, tc.input)
			if err != nil {
				t.Fatalf("resolveImageURL(%q) unexpected error: %v", tc.input, err)
			}
			if got != tc.wantURL {
				t.Errorf("resolveImageURL(%q) = %q, want %q", tc.input, got, tc.wantURL)
			}
		})
	}
}

func TestPrepareRequestImageReferenceStripsAWSConsole(t *testing.T) {
	t.Parallel()

	ctx := context.Background()
	claims := &Claims{UserID: "user-123"}

	consoleURL := "https://269172689438-eywgkjb7.eu-north-1.console.aws.amazon.com/s3/object/panta-request-images?region=eu-north-1&prefix=requests/20260909190032-85a15cb9/images/original.jpg"
	gotKey, err := prepareRequestImageReference(ctx, claims, "20260909190032-85a15cb9", "", consoleURL)
	if err != nil {
		t.Fatalf("prepareRequestImageReference failed: %v", err)
	}

	wantKey := "requests/20260909190032-85a15cb9/images/original.jpg"
	if gotKey != wantKey {
		t.Errorf("got key %q, want %q", gotKey, wantKey)
	}
}

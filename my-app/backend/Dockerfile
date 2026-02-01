# STAGE 1: Builder
FROM golang:1.23-alpine AS builder
# Install git required for fetching Go modules
RUN apk add --no-cache git
WORKDIR /app
COPY go.mod ./
# (If you had dependencies, we would run 'go mod download' here)
COPY . .
# Download dependencies
RUN go mod tidy
# Build static binary, strip debug info
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-w -s" -o /server ./cmd/api
# STAGE 2: Runtime (Distroless for security)
FROM gcr.io/distroless/static-debian12
WORKDIR /
COPY --from=builder /server /server
EXPOSE 8080
USER nonroot:nonroot
ENTRYPOINT ["/server"]

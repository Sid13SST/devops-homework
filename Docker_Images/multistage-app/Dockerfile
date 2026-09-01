# ---------------------------------------------------------------
# Stage 1 (builder): full Go toolchain, used only to compile
# ---------------------------------------------------------------
FROM golang:1.23-alpine AS builder

WORKDIR /src

# Copy the module definition and the source
COPY go.mod ./
COPY main.go ./

# CGO_ENABLED=0 produces a fully static binary so the runtime
# stage does not need any C libraries.
# -ldflags="-s -w" strips the symbol table and debug info.
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o /out/server main.go

# ---------------------------------------------------------------
# Stage 2 (runtime): tiny base image, only the compiled binary
# The Go compiler, module cache and source never reach this image.
# ---------------------------------------------------------------
FROM alpine:3.20

WORKDIR /app

# Copy just the built artifact out of the builder stage
COPY --from=builder /out/server /app/server

# Run as a non-root user
RUN addgroup -S app && adduser -S -G app app
USER app

EXPOSE 8080

CMD ["/app/server"]

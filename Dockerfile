# TSL Motion Capture Flutter Web Dockerfile
# Multi-stage build: Flutter SDK -> Nginx

# Stage 1: Build Flutter Web
FROM ghcr.io/cirruslabs/flutter:3.29.2 AS build

WORKDIR /app

# Copy pubspec files first for caching
COPY pubspec.yaml pubspec.lock ./

# Get dependencies
RUN flutter pub get

# Copy the rest of the app
COPY . .

# Build for web release
RUN flutter build web --release

# Stage 2: Serve with Nginx
FROM nginx:alpine

# Copy built web files to nginx
COPY --from=build /app/build/web /usr/share/nginx/html

# Expose port 80
EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]

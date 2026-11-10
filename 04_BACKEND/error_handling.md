# ⚠️ Error Handling — StreamMax

## Overview
Comprehensive error handling strategy for backend API, mobile app, and streaming system.

---

## 🚨 Error Categories

| Category | Examples | Severity |
|---------|---------|---------|
| Auth Errors | Invalid token, expired session | Medium |
| Content Errors | Movie not found, stream broken | High |
| Network Errors | CDN timeout, server down | Critical |
| Rate Limit | Too many requests | Low |
| Payment Errors | Subscription failed | High |
| App Crashes | Unhandled exceptions | Critical |

---

## 🔧 Backend Error Handling

### Standard Error Response Format
```typescript
// All errors follow this format
{
  "success": false,
  "error": {
    "code": "STREAM_NOT_AVAILABLE",      // Machine-readable code
    "message": "Stream server is down",   // Human-readable
    "details": {                           // Optional details
      "server_id": 1,
      "tried_servers": [1, 2, 3]
    },
    "request_id": "uuid"                  // For debugging
  }
}
```

### Error Codes Reference
```
AUTH_ERRORS:
  AUTH_TOKEN_MISSING         → 401: No token provided
  AUTH_TOKEN_INVALID         → 401: Token malformed
  AUTH_TOKEN_EXPIRED         → 401: Token expired (refresh needed)
  AUTH_INSUFFICIENT_ROLE     → 403: Not enough permissions
  AUTH_DEVICE_LIMIT          → 403: Too many devices
  
CONTENT_ERRORS:
  CONTENT_NOT_FOUND          → 404: Movie/series doesn't exist
  STREAM_NOT_AVAILABLE       → 503: All servers down for this content
  STREAM_URL_EXPIRED         → 410: CDN URL expired (re-request)
  SUBTITLE_NOT_FOUND         → 404: Subtitle not available
  CONTENT_GEO_BLOCKED        → 451: Not available in your region
  
USER_ERRORS:
  USER_NOT_FOUND             → 404
  USER_ALREADY_EXISTS        → 409: Email already registered
  USER_INVALID_CREDENTIALS   → 401: Wrong email/password
  USER_ACCOUNT_SUSPENDED     → 403: Account banned
  
RATE_LIMIT_ERRORS:
  RATE_LIMIT_EXCEEDED        → 429: Slow down
  
VALIDATION_ERRORS:
  VALIDATION_FAILED          → 400: Invalid input (with field details)
  
SERVER_ERRORS:
  INTERNAL_ERROR             → 500: Something went wrong
  SERVICE_UNAVAILABLE        → 503: Maintenance mode
  DATABASE_ERROR             → 500: DB connection issue
```

### Fastify Error Handler
```typescript
// src/plugins/errorHandler.ts

import { FastifyError, FastifyReply, FastifyRequest } from 'fastify';
import { logger } from '../utils/logger';

export function errorHandler(
  error: FastifyError,
  request: FastifyRequest,
  reply: FastifyReply
) {
  const requestId = request.id;
  
  // Log error
  logger.error({
    requestId,
    error: error.message,
    stack: error.stack,
    url: request.url,
    method: request.method,
    userId: (request as any).user?.id
  });
  
  // Known errors
  if (error.statusCode) {
    return reply.status(error.statusCode).send({
      success: false,
      error: {
        code: error.code || 'API_ERROR',
        message: error.message,
        request_id: requestId
      }
    });
  }
  
  // Validation errors
  if (error.validation) {
    return reply.status(400).send({
      success: false,
      error: {
        code: 'VALIDATION_FAILED',
        message: 'Invalid request data',
        details: error.validation,
        request_id: requestId
      }
    });
  }
  
  // Send alert for 500 errors
  if (!error.statusCode || error.statusCode >= 500) {
    sendTelegramAlert(`🚨 500 Error: ${error.message}\nURL: ${request.url}`);
  }
  
  // Generic 500
  return reply.status(500).send({
    success: false,
    error: {
      code: 'INTERNAL_ERROR',
      message: 'Something went wrong. Please try again.',
      request_id: requestId
    }
  });
}
```

---

## 📱 Mobile App Error Handling

### Network Error Handler
```dart
// lib/core/network/error_handler.dart

class ErrorHandler {
  static AppError handle(dynamic error) {
    if (error is DioException) {
      return _handleDioError(error);
    }
    return AppError(
      code: 'UNKNOWN_ERROR',
      message: 'Something went wrong. Please try again.',
    );
  }
  
  static AppError _handleDioError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
        return AppError(
          code: 'NETWORK_TIMEOUT',
          message: 'Connection timed out. Check your internet.',
        );
        
      case DioExceptionType.connectionError:
        return AppError(
          code: 'NO_INTERNET',
          message: 'No internet connection.',
        );
        
      case DioExceptionType.badResponse:
        return _handleHttpError(error.response!);
        
      default:
        return AppError(
          code: 'NETWORK_ERROR',
          message: 'Network error. Please try again.',
        );
    }
  }
  
  static AppError _handleHttpError(Response response) {
    final data = response.data as Map<String, dynamic>?;
    final errorCode = data?['error']?['code'] ?? 'API_ERROR';
    final message = data?['error']?['message'] ?? 'Request failed';
    
    switch (response.statusCode) {
      case 401:
        // Token expired → trigger re-auth
        AuthService.instance.handleUnauthorized();
        return AppError(code: 'AUTH_EXPIRED', message: 'Session expired');
        
      case 429:
        return AppError(
          code: 'RATE_LIMIT',
          message: 'Too many requests. Wait a moment.',
        );
        
      case 503:
        return AppError(
          code: 'SERVICE_DOWN',
          message: 'Stream temporarily unavailable.',
        );
        
      default:
        return AppError(code: errorCode, message: message);
    }
  }
}
```

### Video Player Error Handling
```dart
// lib/features/player/player_controller.dart

class PlayerController {
  int _currentServerIndex = 0;
  List<StreamServer> _servers = [];
  
  Future<void> playMovie(Movie movie) async {
    _servers = movie.activeServers;
    _currentServerIndex = 0;
    await _tryPlayWithServer(_currentServerIndex);
  }
  
  Future<void> _tryPlayWithServer(int serverIndex) async {
    if (serverIndex >= _servers.length) {
      // All servers failed
      _showError('No working stream available. Please try again later.');
      _reportBrokenStreams();
      return;
    }
    
    try {
      final server = _servers[serverIndex];
      final streamUrl = await _getSignedUrl(server);
      await _player.load(streamUrl);
      
    } on StreamExpiredException {
      // Signed URL expired — refetch
      await _refreshStreamUrl();
      
    } on PlayerException catch (e) {
      if (e.code == 'SOURCE_ERROR') {
        // Try next server
        _showSnackbar('Switching to backup server...');
        await _tryPlayWithServer(serverIndex + 1);
      }
      
    } on NetworkException {
      _showError('No internet connection. Check your network.');
    }
  }
  
  Future<void> _refreshStreamUrl() async {
    try {
      final newUrl = await StreamService.getStreamUrl(
        movieId: movie.id,
        server: _servers[_currentServerIndex].id,
      );
      await _player.load(newUrl);
    } catch (e) {
      await _tryPlayWithServer(_currentServerIndex + 1);
    }
  }
  
  void _reportBrokenStreams() {
    // Auto-report all servers as broken
    for (final server in _servers) {
      ReportService.reportBrokenStream(
        movieId: movie.id,
        serverId: server.id,
      );
    }
  }
}
```

---

## 📊 Error Monitoring Dashboard

```
Sentry Setup:
- Capture all Flutter crashes
- Capture all uncaught backend errors
- Group similar errors
- Alert on new error types

Key Metrics to Monitor:
  crash_free_sessions: > 99.5%
  api_error_rate:      < 1%
  stream_success_rate: > 95%
  broken_server_rate:  < 5%
```

---

## 🔄 Retry Logic

### API Retry Strategy
```dart
// Exponential backoff for failed requests
RetryInterceptor(
  retries: 3,
  retryDelays: [
    Duration(seconds: 1),   // 1st retry: wait 1s
    Duration(seconds: 2),   // 2nd retry: wait 2s
    Duration(seconds: 4),   // 3rd retry: wait 4s
  ],
  retryEvaluator: (error, attempt) {
    // Retry on network errors and 5xx
    return error.type == DioExceptionType.connectionError
        || (error.response?.statusCode ?? 0) >= 500;
  },
)
```

---

## 📱 User-Facing Error Messages

| Error | User Sees |
|-------|----------|
| No internet | "No internet connection. Check your WiFi." |
| Stream down | "Stream unavailable. Trying backup server..." |
| All servers down | "Video temporarily unavailable. Try again later." |
| URL expired | "Refreshing stream... (auto-handled)" |
| Rate limited | "Too many requests. Please wait a moment." |
| Auth expired | "Session expired. Please log in again." |
| Download failed | "Download failed. Check storage space and retry." |
| Region blocked | "Content not available in your region." |
| App crash | Sentry auto-report + "App restarting..." |


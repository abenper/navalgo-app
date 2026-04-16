package com.navalgo.backend.api;

import com.navalgo.backend.auth.InvalidCredentialsException;
import com.navalgo.backend.auth.RateLimitExceededException;
import jakarta.persistence.EntityNotFoundException;
import jakarta.servlet.http.HttpServletRequest;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.web.HttpRequestMethodNotSupportedException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.Map;

@RestControllerAdvice
public class GlobalExceptionHandler {

    private static final Logger LOG = LoggerFactory.getLogger(GlobalExceptionHandler.class);

    @ExceptionHandler(EntityNotFoundException.class)
    public ResponseEntity<ApiError> handleNotFound(EntityNotFoundException ex, HttpServletRequest request) {
        LOG.warn("Not found: {}", ex.getMessage());
        return build(HttpStatus.NOT_FOUND, "NOT_FOUND", ex.getMessage(), request, Map.of());
    }

    @ExceptionHandler(IllegalArgumentException.class)
    public ResponseEntity<ApiError> handleBadRequest(IllegalArgumentException ex, HttpServletRequest request) {
        LOG.warn("Bad request: {}", ex.getMessage());
        return build(HttpStatus.BAD_REQUEST, "BAD_REQUEST", ex.getMessage(), request, Map.of());
    }

    @ExceptionHandler({InvalidCredentialsException.class, BadCredentialsException.class})
    public ResponseEntity<ApiError> handleInvalidCredentials(Exception ex, HttpServletRequest request) {
        LOG.warn("Authentication failure: {}", ex.getMessage());
        return build(HttpStatus.UNAUTHORIZED, "INVALID_CREDENTIALS", "Credenciales invalidas", request, Map.of());
    }

    @ExceptionHandler(RateLimitExceededException.class)
    public ResponseEntity<ApiError> handleRateLimit(RateLimitExceededException ex, HttpServletRequest request) {
        LOG.warn("Rate limit triggered: {}", ex.getMessage());
        return build(HttpStatus.TOO_MANY_REQUESTS, "RATE_LIMIT", ex.getMessage(), request, Map.of());
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<ApiError> handleValidation(MethodArgumentNotValidException ex, HttpServletRequest request) {
        LOG.warn("Validation error: {}", ex.getMessage());
        Map<String, String> fieldErrors = new LinkedHashMap<>();
        ex.getBindingResult().getFieldErrors().forEach(error -> fieldErrors.put(error.getField(), error.getDefaultMessage()));
        return build(HttpStatus.BAD_REQUEST, "VALIDATION_ERROR", "Validation error", request, fieldErrors);
    }

    @ExceptionHandler(AccessDeniedException.class)
    public ResponseEntity<ApiError> handleForbidden(AccessDeniedException ex, HttpServletRequest request) {
        LOG.warn("Forbidden: {}", ex.getMessage());
        return build(HttpStatus.FORBIDDEN, "FORBIDDEN", "Forbidden", request, Map.of());
    }

    @ExceptionHandler(HttpRequestMethodNotSupportedException.class)
    public ResponseEntity<ApiError> handleMethodNotAllowed(HttpRequestMethodNotSupportedException ex, HttpServletRequest request) {
        LOG.warn("Method not allowed: {}", ex.getMessage());
        return build(HttpStatus.METHOD_NOT_ALLOWED, "METHOD_NOT_ALLOWED", "Method not allowed", request, Map.of());
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<ApiError> handleUnknown(Exception ex, HttpServletRequest request) {
        LOG.error("Unhandled server error", ex);
        return build(HttpStatus.INTERNAL_SERVER_ERROR, "INTERNAL_ERROR", "Internal server error", request, Map.of());
    }

    private ResponseEntity<ApiError> build(HttpStatus status,
                                           String code,
                                           String message,
                                           HttpServletRequest request,
                                           Map<String, String> fieldErrors) {
        String requestId = request == null ? null : (String) request.getAttribute(com.navalgo.backend.security.RequestIdFilter.REQUEST_ID_ATTRIBUTE);
        ApiError error = new ApiError(Instant.now(), status.value(), code, message, requestId, fieldErrors);
        return ResponseEntity.status(status).body(error);
    }
}

package com.syn.usermanagement.exception;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.multipart.MaxUploadSizeExceededException;

import java.util.Map;

/**
 * Converts exceptions into simple JSON error messages: { "message": "..." }
 */
@RestControllerAdvice
public class GlobalExceptionHandler {

    // Duplicate email -> 409 Conflict
    @ExceptionHandler(EmailAlreadyExistsException.class)
    public ResponseEntity<Map<String, String>> handleEmailExists(EmailAlreadyExistsException ex) {
        return error(HttpStatus.CONFLICT, ex.getMessage());
    }

    // @Valid failed (blank name, bad email, short password) -> 400 Bad Request
    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<Map<String, String>> handleValidation(MethodArgumentNotValidException ex) {
        return error(HttpStatus.BAD_REQUEST, ex.getBindingResult().getFieldErrors().get(0).getDefaultMessage());
    }

    // Unknown user id -> 404 Not Found
    @ExceptionHandler(ResourceNotFoundException.class)
    public ResponseEntity<Map<String, String>> handleNotFound(ResourceNotFoundException ex) {
        return error(HttpStatus.NOT_FOUND, ex.getMessage());
    }

    // Wrong file type / no file -> 400 Bad Request
    @ExceptionHandler(InvalidPhotoException.class)
    public ResponseEntity<Map<String, String>> handleInvalidPhoto(InvalidPhotoException ex) {
        return error(HttpStatus.BAD_REQUEST, ex.getMessage());
    }

    // File bigger than spring.servlet.multipart.max-file-size -> 413
    @ExceptionHandler(MaxUploadSizeExceededException.class)
    public ResponseEntity<Map<String, String>> handleTooLarge(MaxUploadSizeExceededException ex) {
        return error(HttpStatus.PAYLOAD_TOO_LARGE, "Photo is too large (max 5 MB)");
    }

    // S3 not configured -> 503
    @ExceptionHandler(PhotoStorageUnavailableException.class)
    public ResponseEntity<Map<String, String>> handleStorageOff(PhotoStorageUnavailableException ex) {
        return error(HttpStatus.SERVICE_UNAVAILABLE, ex.getMessage());
    }

    private ResponseEntity<Map<String, String>> error(HttpStatus status, String message) {
        return ResponseEntity.status(status).body(Map.of("message", message));
    }
}

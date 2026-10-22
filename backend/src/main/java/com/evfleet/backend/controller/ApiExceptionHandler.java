package com.evfleet.backend.controller;

import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.*;
import org.springframework.validation.FieldError;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.method.annotation.MethodArgumentTypeMismatchException;
import org.springframework.web.bind.MissingRequestHeaderException;
import org.springframework.web.bind.MissingServletRequestParameterException;
import org.springframework.web.server.ResponseStatusException;
import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.Map;

@RestControllerAdvice
public class ApiExceptionHandler {
    @ExceptionHandler(MethodArgumentNotValidException.class)
    ResponseEntity<Map<String, Object>> validation(MethodArgumentNotValidException ex) {
        Map<String, String> fields = new LinkedHashMap<>();
        for (FieldError error : ex.getBindingResult().getFieldErrors()) fields.putIfAbsent(error.getField(), error.getDefaultMessage());
        return response(HttpStatus.BAD_REQUEST, "Validation failed", fields);
    }

    @ExceptionHandler({MethodArgumentTypeMismatchException.class, MissingRequestHeaderException.class, MissingServletRequestParameterException.class, IllegalArgumentException.class})
    ResponseEntity<Map<String, Object>> badRequest(Exception ex) {
        return response(HttpStatus.BAD_REQUEST, "Invalid request", ex.getMessage());
    }

    @ExceptionHandler(ResponseStatusException.class)
    ResponseEntity<Map<String, Object>> status(ResponseStatusException ex) {
        return response(HttpStatusCode.valueOf(ex.getStatusCode().value()), ex.getReason(), null);
    }

    @ExceptionHandler(DataIntegrityViolationException.class)
    ResponseEntity<Map<String, Object>> duplicate(DataIntegrityViolationException ex) {
        return response(HttpStatus.CONFLICT, "Duplicate data conflicts with an existing record", null);
    }

    private ResponseEntity<Map<String, Object>> response(HttpStatusCode status, String message, Object details) {
        Map<String, Object> body = new LinkedHashMap<>();
        body.put("timestamp", Instant.now());
        body.put("status", status.value());
        body.put("error", HttpStatus.valueOf(status.value()).getReasonPhrase());
        body.put("message", message == null ? "Request failed" : message);
        if (details != null) body.put("details", details);
        return ResponseEntity.status(status).body(body);
    }
}

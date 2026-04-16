package com.navalgo.backend.common;

import org.springframework.stereotype.Component;

import java.net.URI;
import java.util.Locale;

@Component
public class InputSanitizer {

    public String requiredText(String value, String fieldName, int maxLength) {
        String sanitized = optionalText(value, maxLength);
        if (sanitized == null || sanitized.isBlank()) {
            throw new IllegalArgumentException(fieldName + " es obligatorio");
        }
        return sanitized;
    }

    public String optionalText(String value, int maxLength) {
        if (value == null) {
            return null;
        }

        String normalized = value
                .replaceAll("\\p{Cntrl}", " ")
                .replaceAll("\\s+", " ")
                .trim();

        if (normalized.isEmpty()) {
            return null;
        }
        if (normalized.length() > maxLength) {
            throw new IllegalArgumentException("El texto supera la longitud maxima permitida");
        }

        return normalized;
    }

    public String email(String value) {
        String normalized = requiredText(value, "El email", 255).toLowerCase(Locale.ROOT);
        if (!normalized.matches("^[A-Za-z0-9+_.-]+@[A-Za-z0-9.-]+$")) {
            throw new IllegalArgumentException("El email no es valido");
        }
        return normalized;
    }

    public String optionalUrl(String value, int maxLength) {
        String normalized = optionalText(value, maxLength);
        if (normalized == null) {
            return null;
        }
        try {
            URI uri = URI.create(normalized);
            String scheme = uri.getScheme();
            if (scheme == null || (!scheme.equalsIgnoreCase("http") && !scheme.equalsIgnoreCase("https"))) {
                throw new IllegalArgumentException("La URL no es valida");
            }
            return normalized;
        } catch (IllegalArgumentException exception) {
            throw new IllegalArgumentException("La URL no es valida");
        }
    }
}
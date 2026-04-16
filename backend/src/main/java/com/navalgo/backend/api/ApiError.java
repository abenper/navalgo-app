package com.navalgo.backend.api;

import java.time.Instant;
import java.util.Map;

public record ApiError(
		Instant timestamp,
		int status,
		String code,
		String message,
		String requestId,
		Map<String, String> fieldErrors
) {

	public ApiError(String message) {
		this(Instant.now(), 500, "INTERNAL_ERROR", message, null, Map.of());
	}
}

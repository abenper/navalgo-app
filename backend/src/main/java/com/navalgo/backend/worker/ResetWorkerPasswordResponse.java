package com.navalgo.backend.worker;

public record ResetWorkerPasswordResponse(
        Long workerId,
        String email,
        String temporaryPassword
) {
}

package com.navalgo.backend.worker;

public record CreateWorkerResponse(
        WorkerDto worker,
        String temporaryPassword
) {
}

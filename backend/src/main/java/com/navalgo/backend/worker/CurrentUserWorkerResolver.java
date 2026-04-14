package com.navalgo.backend.worker;

import jakarta.persistence.EntityNotFoundException;
import org.springframework.stereotype.Component;

@Component
public class CurrentUserWorkerResolver {

    private final WorkerRepository workerRepository;

    public CurrentUserWorkerResolver(WorkerRepository workerRepository) {
        this.workerRepository = workerRepository;
    }

    public Long findWorkerIdByEmail(String email) {
        return workerRepository.findByEmailIgnoreCase(email)
                .map(Worker::getId)
                .orElseThrow(() -> new EntityNotFoundException("Usuario no encontrado"));
    }
}

package com.navalgo.backend.worker;

import jakarta.persistence.EntityNotFoundException;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
public class WorkerService {

    private final WorkerRepository workerRepository;
    private final PasswordEncoder passwordEncoder;

    public WorkerService(WorkerRepository workerRepository, PasswordEncoder passwordEncoder) {
        this.workerRepository = workerRepository;
        this.passwordEncoder = passwordEncoder;
    }

    public List<WorkerDto> findAll() {
        return workerRepository.findAll().stream().map(WorkerDto::from).toList();
    }

    public WorkerDto create(CreateWorkerRequest request) {
        workerRepository.findByEmailIgnoreCase(request.email()).ifPresent(existing -> {
            throw new IllegalArgumentException("Ya existe un trabajador con ese email");
        });

        Worker worker = new Worker();
        worker.setFullName(request.fullName());
        worker.setEmail(request.email());
        worker.setPasswordHash(passwordEncoder.encode(request.password()));
        worker.setSpeciality(request.speciality());
        worker.setRole(request.role());
        worker.setActive(true);

        return WorkerDto.from(workerRepository.save(worker));
    }

    public WorkerDto setActive(Long workerId, boolean active) {
        Worker worker = workerRepository.findById(workerId)
                .orElseThrow(() -> new EntityNotFoundException("Trabajador no encontrado"));
        worker.setActive(active);
        return WorkerDto.from(workerRepository.save(worker));
    }
}

package com.navalgo.backend.leave;

import com.navalgo.backend.worker.Worker;
import com.navalgo.backend.worker.WorkerRepository;
import jakarta.persistence.EntityNotFoundException;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
public class LeaveRequestService {

    private final LeaveRequestRepository repository;
    private final WorkerRepository workerRepository;

    public LeaveRequestService(LeaveRequestRepository repository, WorkerRepository workerRepository) {
        this.repository = repository;
        this.workerRepository = workerRepository;
    }

    public LeaveRequestDto create(CreateLeaveRequest request) {
        Worker worker = workerRepository.findById(request.workerId())
                .orElseThrow(() -> new EntityNotFoundException("Trabajador no encontrado"));

        if (request.endDate().isBefore(request.startDate())) {
            throw new IllegalArgumentException("La fecha fin no puede ser menor que la fecha inicio");
        }

        LeaveRequestEntity entity = new LeaveRequestEntity();
        entity.setWorker(worker);
        entity.setReason(request.reason());
        entity.setStartDate(request.startDate());
        entity.setEndDate(request.endDate());
        entity.setStatus(LeaveStatus.PENDING);

        return LeaveRequestDto.from(repository.save(entity));
    }

    public List<LeaveRequestDto> list(Long workerId) {
        if (workerId == null) {
            return repository.findAll().stream().map(LeaveRequestDto::from).toList();
        }
        return repository.findByWorkerIdOrderByStartDateDesc(workerId)
                .stream()
                .map(LeaveRequestDto::from)
                .toList();
    }

    public LeaveRequestDto updateStatus(Long id, UpdateLeaveStatusRequest request) {
        LeaveRequestEntity entity = repository.findById(id)
                .orElseThrow(() -> new EntityNotFoundException("Solicitud no encontrada"));
        entity.setStatus(request.status());
        return LeaveRequestDto.from(repository.save(entity));
    }
}

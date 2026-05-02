package com.navalgo.backend.leave;

import com.navalgo.backend.common.InputSanitizer;
import com.navalgo.backend.notification.NotificationService;
import com.navalgo.backend.timetracking.TimeEntryRepository;
import com.navalgo.backend.worker.Worker;
import com.navalgo.backend.worker.WorkerRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.LocalDate;
import java.util.Collections;
import java.util.List;
import java.util.Optional;
import java.util.Set;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class LeaveRequestServiceTest {

    @Mock
    private LeaveRequestRepository repository;

    @Mock
    private WorkerRepository workerRepository;

    @Mock
    private NotificationService notificationService;

    @Mock
    private TimeEntryRepository timeEntryRepository;

    @Test
    void getBalanceReturnsNegativeAvailableDaysWhenWorkerHasConsumedMoreThanAccrued() {
        Worker worker = worker(7L, "Marinero");
        LeaveRequestEntity consumedRequest = leaveRequest(
                21L,
                worker,
                "Vacaciones",
                LocalDate.now().minusDays(10),
                LocalDate.now().minusDays(4),
                LeaveStatus.APPROVED
        );
        LeaveRequestService service = new LeaveRequestService(
                repository,
                workerRepository,
                notificationService,
                timeEntryRepository,
                new InputSanitizer()
        );

        when(workerRepository.findById(7L)).thenReturn(Optional.of(worker));
        when(repository.findByWorkerIdAndStatusIn(eq(7L), any(Set.class)))
                .thenReturn(List.of(consumedRequest));
        when(timeEntryRepository.findByWorkerIdOrderByClockInAsc(7L))
                .thenReturn(Collections.emptyList());

        LeaveBalanceDto balance = service.getBalance(7L);

        assertThat(balance.availableDays()).isNegative();
        assertThat(balance.availableDays()).isEqualTo(balance.accruedDays() + balance.bonusDays() - balance.consumedDays());
    }

    @Test
    void createAllowsVacationRequestEvenWhenItExceedsCurrentAvailableDays() {
        Worker worker = worker(9L, "Mecanico Naval");
        LeaveRequestService service = new LeaveRequestService(
                repository,
                workerRepository,
                notificationService,
                timeEntryRepository,
                new InputSanitizer()
        );
        CreateLeaveRequest request = new CreateLeaveRequest(
                9L,
                "Vacaciones",
                LocalDate.now().plusDays(1),
                LocalDate.now().plusDays(30)
        );

        when(workerRepository.findById(9L)).thenReturn(Optional.of(worker));
        when(repository.save(any(LeaveRequestEntity.class))).thenAnswer(invocation -> {
            LeaveRequestEntity entity = invocation.getArgument(0);
            entity.setId(33L);
            return entity;
        });

        LeaveRequestDto created = service.create(request);

        assertThat(created.id()).isEqualTo(33L);
        assertThat(created.workerId()).isEqualTo(9L);
        assertThat(created.reason()).isEqualTo("Vacaciones");
        assertThat(created.status()).isEqualTo(LeaveStatus.PENDING);
        assertThat(created.requestedDays()).isEqualTo(30L);
        verify(repository).save(any(LeaveRequestEntity.class));
    }

    private Worker worker(Long id, String fullName) {
        Worker worker = new Worker();
        worker.setId(id);
        worker.setFullName(fullName);
        worker.setContractStartDate(LocalDate.now());
        return worker;
    }

    private LeaveRequestEntity leaveRequest(Long id,
                                            Worker worker,
                                            String reason,
                                            LocalDate startDate,
                                            LocalDate endDate,
                                            LeaveStatus status) {
        LeaveRequestEntity entity = new LeaveRequestEntity();
        entity.setId(id);
        entity.setWorker(worker);
        entity.setReason(reason);
        entity.setStartDate(startDate);
        entity.setEndDate(endDate);
        entity.setStatus(status);
        return entity;
    }
}

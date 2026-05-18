package com.navalgo.backend.timetracking;

import com.navalgo.backend.leave.LeaveRequestRepository;
import com.navalgo.backend.workorder.WorkOrderRepository;
import com.navalgo.backend.worker.Worker;
import com.navalgo.backend.worker.WorkerRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.Instant;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class TimeTrackingServiceTest {

    @Mock
    private LeaveRequestRepository leaveRequestRepository;

    @Mock
    private TimeEntryRepository timeEntryRepository;

    @Mock
    private WorkOrderRepository workOrderRepository;

    @Mock
    private WorkerRepository workerRepository;

    @Test
    void createManualEntryCreatesClosedEntryForWorker() {
        TimeTrackingService service = new TimeTrackingService(
                leaveRequestRepository,
                timeEntryRepository,
                workOrderRepository,
                workerRepository
        );
        Worker worker = worker(7L, "Pablo Mecanico");
        Instant clockIn = Instant.parse("2026-05-14T08:00:00Z");
        Instant clockOut = Instant.parse("2026-05-14T15:00:00Z");
        CreateTimeEntryRequest request = new CreateTimeEntryRequest(
                7L,
                clockIn,
                clockOut,
                Instant.parse("2026-05-14T14:30:00Z"),
                TimeEntryWorkSite.WORKSHOP
        );

        when(workerRepository.findById(7L)).thenReturn(Optional.of(worker));
        when(timeEntryRepository.save(any(TimeEntry.class))).thenAnswer(invocation -> {
            TimeEntry entry = invocation.getArgument(0);
            entry.setId(21L);
            return entry;
        });

        TimeEntryDto created = service.createManualEntry(request);

        ArgumentCaptor<TimeEntry> captor = ArgumentCaptor.forClass(TimeEntry.class);
        verify(timeEntryRepository).save(captor.capture());
        TimeEntry savedEntry = captor.getValue();

        assertThat(created.id()).isEqualTo(21L);
        assertThat(created.workerId()).isEqualTo(7L);
        assertThat(created.clockIn()).isEqualTo(clockIn);
        assertThat(created.clockOut()).isEqualTo(clockOut);
        assertThat(created.workSite()).isEqualTo(TimeEntryWorkSite.WORKSHOP);
        assertThat(savedEntry.getWorker()).isEqualTo(worker);
        assertThat(savedEntry.getClockIn()).isEqualTo(clockIn);
        assertThat(savedEntry.getClockOut()).isEqualTo(clockOut);
        assertThat(savedEntry.getPlannedClockOut()).isEqualTo(
                Instant.parse("2026-05-14T14:30:00Z")
        );
    }

    @Test
    void createManualEntryRequiresClockOutToAssignHours() {
        TimeTrackingService service = new TimeTrackingService(
                leaveRequestRepository,
                timeEntryRepository,
                workOrderRepository,
                workerRepository
        );
        Worker worker = worker(9L, "Laura Marina");
        CreateTimeEntryRequest request = new CreateTimeEntryRequest(
                9L,
                Instant.parse("2026-05-14T08:00:00Z"),
                null,
                null,
                TimeEntryWorkSite.WORKSHOP
        );

        when(workerRepository.findById(9L)).thenReturn(Optional.of(worker));

        assertThatThrownBy(() -> service.createManualEntry(request))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("hora de salida");
    }

    private Worker worker(Long id, String fullName) {
        Worker worker = new Worker();
        worker.setId(id);
        worker.setFullName(fullName);
        return worker;
    }
}

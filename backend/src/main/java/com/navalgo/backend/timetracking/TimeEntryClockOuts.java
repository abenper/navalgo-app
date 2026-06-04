package com.navalgo.backend.timetracking;

import java.time.Instant;
import java.time.LocalTime;
import java.time.ZoneId;

final class TimeEntryClockOuts {

    static final ZoneId BUSINESS_ZONE = ZoneId.of("Europe/Madrid");
    private static final LocalTime END_OF_DAY_FORCE_CLOSE_CLOCK_OUT = LocalTime.of(15, 0);

    private TimeEntryClockOuts() {
    }

    static Instant effectiveClockOut(TimeEntry entry) {
        if (entry.getClockOut() == null) {
            return null;
        }
        if (entry.getAutoCloseReason() != TimeEntryAutoCloseReason.END_OF_DAY_FORCE_CLOSE) {
            return entry.getClockOut();
        }

        return entry.getClockIn()
                .atZone(BUSINESS_ZONE)
                .toLocalDate()
                .atTime(END_OF_DAY_FORCE_CLOSE_CLOCK_OUT)
                .atZone(BUSINESS_ZONE)
                .toInstant();
    }
}

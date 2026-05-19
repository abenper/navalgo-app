package com.navalgo.backend.notification;

import org.springframework.data.jpa.repository.JpaRepository;

import java.time.LocalDate;
import java.util.Collection;
import java.util.List;
import java.util.Optional;

public interface WhatsAppClockInConversationRepository extends JpaRepository<WhatsAppClockInConversation, Long> {

    Optional<WhatsAppClockInConversation> findFirstByWorkerIdAndReminderDateOrderByRequestedAtDesc(
            Long workerId,
            LocalDate reminderDate
    );

    List<WhatsAppClockInConversation> findByWorkerIdAndStateInOrderByRequestedAtDesc(
            Long workerId,
            Collection<WhatsAppClockInConversationState> states
    );

    Optional<WhatsAppClockInConversation> findFirstByPhoneNumberAndStateInOrderByRequestedAtDesc(
            String phoneNumber,
            Collection<WhatsAppClockInConversationState> states
    );
}

package com.navalgo.backend.notification;

import com.fasterxml.jackson.databind.JsonNode;
import com.navalgo.backend.common.Role;
import com.navalgo.backend.timetracking.TimeAdjustmentRequestService;
import com.navalgo.backend.timetracking.TimeEntry;
import com.navalgo.backend.timetracking.TimeEntryDto;
import com.navalgo.backend.timetracking.TimeEntryWorkSite;
import com.navalgo.backend.timetracking.TimeTrackingService;
import com.navalgo.backend.worker.Worker;
import com.navalgo.backend.worker.WorkerRepository;
import jakarta.persistence.EntityNotFoundException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.text.Normalizer;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalTime;
import java.time.ZoneId;
import java.util.EnumSet;
import java.util.List;
import java.util.Locale;
import java.util.Optional;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

@Service
@Transactional(readOnly = true)
public class WhatsAppClockInFlowService {

    private static final Logger log = LoggerFactory.getLogger(WhatsAppClockInFlowService.class);
    private static final Pattern HOUR_PATTERN = Pattern.compile("^(\\d{1,2})(?::(\\d{2}))?$");
    private static final Pattern DATE_TIME_PATTERN =
            Pattern.compile("^(\\d{1,2})/(\\d{1,2})(?:/(\\d{4}))?\\s+(\\d{1,2})(?::(\\d{2}))?$");
    private static final String QUICK_REPLY_ID_8AM = "clock_in_08_00";
    private static final String ACTION_CLOCK_IN_NOW = "action_clock_in_now";
    private static final String ACTION_TIME_ADJUSTMENT = "action_time_adjustment";
    private static final String ADJUSTMENT_REASON = "Solicitud enviada por WhatsApp por olvido de fichaje.";
    private static final EnumSet<Role> WHATSAPP_WORKER_ROLES = EnumSet.of(Role.WORKER, Role.COMERCIAL);
    private static final List<WhatsAppClockInConversationState> PENDING_TIME_STATES =
            List.of(WhatsAppClockInConversationState.AWAITING_TIME);
    private static final List<WhatsAppClockInConversationState> PENDING_ACTION_STATES =
            List.of(WhatsAppClockInConversationState.AWAITING_ACTION);
    private static final List<WhatsAppClockInConversationState> PENDING_ADJUSTMENT_STATES =
            List.of(WhatsAppClockInConversationState.AWAITING_ADJUSTMENT_TIME);
    private static final List<WhatsAppClockInConversationState> PENDING_LOCATION_STATES =
            List.of(WhatsAppClockInConversationState.AWAITING_LOCATION);
    private static final List<WhatsAppClockInConversationState> ACTIVE_STATES =
            List.of(
                    WhatsAppClockInConversationState.AWAITING_ACTION,
                    WhatsAppClockInConversationState.AWAITING_TIME,
                    WhatsAppClockInConversationState.AWAITING_ADJUSTMENT_TIME,
                    WhatsAppClockInConversationState.AWAITING_LOCATION
            );

    private final WhatsAppClockInConversationRepository conversationRepository;
    private final WhatsAppCloudService whatsAppCloudService;
    private final TimeTrackingService timeTrackingService;
    private final TimeAdjustmentRequestService timeAdjustmentRequestService;
    private final WorkerRepository workerRepository;

    public WhatsAppClockInFlowService(WhatsAppClockInConversationRepository conversationRepository,
                                      WhatsAppCloudService whatsAppCloudService,
                                      TimeTrackingService timeTrackingService,
                                      TimeAdjustmentRequestService timeAdjustmentRequestService,
                                      WorkerRepository workerRepository) {
        this.conversationRepository = conversationRepository;
        this.whatsAppCloudService = whatsAppCloudService;
        this.timeTrackingService = timeTrackingService;
        this.timeAdjustmentRequestService = timeAdjustmentRequestService;
        this.workerRepository = workerRepository;
    }

    @Transactional
    public boolean sendMissingClockInReminder(Worker worker, LocalDate today) {
        String normalizedPhone = normalizeWorkerPhone(worker).orElse(null);
        if (normalizedPhone == null) {
            log.info("No se envia recordatorio de WhatsApp. workerId={} sin telefono valido.", worker.getId());
            return false;
        }

        expireStaleConversations(worker, today);

        WhatsAppClockInConversation conversation = startConversation(
                worker,
                normalizedPhone,
                today,
                WhatsAppClockInConversationState.AWAITING_TIME
        );

        String firstName = resolveWorkerFirstName(worker);
        String body = "Buenos dias " + firstName + ". No has fichado esta manana. Responde solo con la hora de entrada. "
                + "Ejemplo: 8:00. Si has entrado a las 8:00, puedes pulsar el boton.";
        boolean sentTemplate = whatsAppCloudService.sendMissingClockInReminderTemplate(
                normalizedPhone,
                List.of(firstName),
                QUICK_REPLY_ID_8AM
        );
        if (sentTemplate) {
            return true;
        }

        return whatsAppCloudService.sendQuickReplyButtonMessage(normalizedPhone, body, QUICK_REPLY_ID_8AM, "8:00");
    }

    @Transactional
    public void handleIncomingMessage(JsonNode message) {
        if (message == null || message.isMissingNode()) {
            return;
        }

        String fromPhone = normalizePhoneDigits(message.path("from").asText());
        if (fromPhone == null) {
            return;
        }

        String messageType = message.path("type").asText("");
        switch (messageType) {
            case "text" -> handleTextMessage(fromPhone, message.path("text").path("body").asText(""));
            case "interactive" -> handleInteractiveMessage(fromPhone, message.path("interactive"));
            case "location" -> {
                JsonNode locationNode = message.path("location");
                if (locationNode.hasNonNull("latitude") && locationNode.hasNonNull("longitude")) {
                    handleLocationMessage(
                            fromPhone,
                            locationNode.path("latitude").asDouble(),
                            locationNode.path("longitude").asDouble()
                    );
                }
            }
            default -> log.debug("Mensaje de WhatsApp ignorado. type={}, from={}", messageType, fromPhone);
        }
    }

    private void handleTextMessage(String fromPhone, String text) {
        Optional<WhatsAppClockInConversation> activeConversation = findActiveConversation(fromPhone);
        if (activeConversation.isPresent()) {
            WhatsAppClockInConversation conversation = activeConversation.get();
            switch (conversation.getState()) {
                case AWAITING_ACTION -> processActionSelection(conversation, text);
                case AWAITING_TIME -> processClockInTime(conversation, text);
                case AWAITING_ADJUSTMENT_TIME -> processAdjustmentRequest(conversation, text);
                case AWAITING_LOCATION -> whatsAppCloudService.sendTextMessage(
                        fromPhone,
                        "La hora ya ha quedado registrada. Ahora comparte tu ubicacion desde el clip de WhatsApp."
                );
                default -> {
                }
            }
            return;
        }

        findWorkerByPhone(fromPhone).ifPresent(worker -> openActionMenu(worker, fromPhone));
    }

    private void handleInteractiveMessage(String fromPhone, JsonNode interactiveNode) {
        if (interactiveNode == null || interactiveNode.isMissingNode()) {
            return;
        }

        String interactiveType = interactiveNode.path("type").asText("");
        if (!"button_reply".equals(interactiveType)) {
            return;
        }

        JsonNode buttonReply = interactiveNode.path("button_reply");
        String selectedId = buttonReply.path("id").asText("");
        String selectedTitle = buttonReply.path("title").asText("");
        String value = hasText(selectedId) ? selectedId : selectedTitle;
        if (!hasText(value)) {
            return;
        }

        Optional<WhatsAppClockInConversation> activeConversation = findActiveConversation(fromPhone);
        if (activeConversation.isPresent()) {
            WhatsAppClockInConversation conversation = activeConversation.get();
            switch (conversation.getState()) {
                case AWAITING_ACTION -> processActionSelection(conversation, value);
                case AWAITING_TIME -> processClockInTime(conversation, hasText(selectedTitle) ? selectedTitle : value);
                default -> {
                }
            }
            return;
        }

        findWorkerByPhone(fromPhone).ifPresent(worker -> openActionMenu(worker, fromPhone));
    }

    private void handleLocationMessage(String fromPhone, double latitude, double longitude) {
        if (Double.isNaN(latitude) || Double.isNaN(longitude)) {
            return;
        }

        Optional<WhatsAppClockInConversation> awaitingLocation = conversationRepository
                .findFirstByPhoneNumberAndStateInOrderByRequestedAtDesc(fromPhone, PENDING_LOCATION_STATES);
        if (awaitingLocation.isPresent()) {
            processLocation(awaitingLocation.get(), latitude, longitude);
            return;
        }

        Optional<WhatsAppClockInConversation> awaitingTime = conversationRepository
                .findFirstByPhoneNumberAndStateInOrderByRequestedAtDesc(fromPhone, PENDING_TIME_STATES);
        if (awaitingTime.isPresent()) {
            whatsAppCloudService.sendTextMessage(
                    fromPhone,
                    "Antes necesito que me indiques la hora de entrada. Ejemplo: 8:00."
            );
            return;
        }

        Optional<WhatsAppClockInConversation> awaitingAction = conversationRepository
                .findFirstByPhoneNumberAndStateInOrderByRequestedAtDesc(fromPhone, PENDING_ACTION_STATES);
        if (awaitingAction.isPresent()) {
            whatsAppCloudService.sendTextMessage(
                    fromPhone,
                    "Primero dime que deseas hacer. Puedes pulsar Fichar o Ajuste."
            );
        }
    }

    private void processActionSelection(WhatsAppClockInConversation conversation, String rawText) {
        conversation.setLastInboundAt(Instant.now());
        conversation.setRawClockInText(rawText);
        conversationRepository.save(conversation);

        String normalized = normalizeKeyword(rawText);
        if (ACTION_CLOCK_IN_NOW.equals(rawText) || "fichar".equals(normalized)) {
            processImmediateClockIn(conversation);
            return;
        }
        if (ACTION_TIME_ADJUSTMENT.equals(rawText) || "ajuste".equals(normalized)) {
            conversation.setState(WhatsAppClockInConversationState.AWAITING_ADJUSTMENT_TIME);
            conversation.setTimeEntry(null);
            conversation.setClockInRecordedAt(null);
            conversation.setLocationRequestedAt(null);
            conversation.setCompletedAt(null);
            conversationRepository.save(conversation);
            whatsAppCloudService.sendTextMessage(
                    conversation.getPhoneNumber(),
                    "Responde con la fecha y la hora de entrada. Ejemplo: 19/05 8:00. "
                            + "Si es de hoy, tambien puedes responder solo con la hora. Ejemplo: 8:00."
            );
            return;
        }

        sendActionMenu(conversation.getWorker(), conversation.getPhoneNumber());
    }

    private void processImmediateClockIn(WhatsAppClockInConversation conversation) {
        try {
            TimeEntryDto timeEntry = timeTrackingService.clockInNowFromWhatsApp(
                    conversation.getWorker().getId(),
                    TimeEntryWorkSite.WORKSHOP
            );
            conversation.setTimeEntry(requireTimeEntryReference(timeEntry.id()));
            conversation.setClockInRecordedAt(Instant.now());
            conversation.setLocationRequestedAt(Instant.now());
            conversation.setCompletedAt(null);
            conversation.setState(WhatsAppClockInConversationState.AWAITING_LOCATION);
            conversationRepository.save(conversation);

            whatsAppCloudService.sendTextMessage(
                    conversation.getPhoneNumber(),
                    "Fichaje registrado. Ahora comparte tu ubicacion desde el clip de WhatsApp."
            );
        } catch (IllegalArgumentException | EntityNotFoundException exception) {
            log.warn("No se pudo registrar el fichaje inmediato por WhatsApp. conversationId={}", conversation.getId(), exception);
            conversation.setState(WhatsAppClockInConversationState.AWAITING_ACTION);
            conversationRepository.save(conversation);
            whatsAppCloudService.sendTextMessage(
                    conversation.getPhoneNumber(),
                    "Ya existe un fichaje registrado hoy. Si necesitas corregirlo, pulsa Ajuste."
            );
        }
    }

    private void processClockInTime(WhatsAppClockInConversation conversation, String rawText) {
        conversation.setLastInboundAt(Instant.now());
        conversation.setRawClockInText(rawText);

        Optional<LocalTime> parsed = parseHour(rawText);
        if (parsed.isEmpty()) {
            conversationRepository.save(conversation);
            whatsAppCloudService.sendTextMessage(
                    conversation.getPhoneNumber(),
                    "No he entendido la hora. Responde solo con la hora, por ejemplo: 8:00."
            );
            return;
        }

        try {
            TimeEntryDto timeEntry = timeTrackingService.clockInFromWhatsApp(
                    conversation.getWorker().getId(),
                    parsed.get(),
                    TimeEntryWorkSite.WORKSHOP
            );
            conversation.setTimeEntry(requireTimeEntryReference(timeEntry.id()));
            conversation.setClockInRecordedAt(Instant.now());
            conversation.setLocationRequestedAt(Instant.now());
            conversation.setState(WhatsAppClockInConversationState.AWAITING_LOCATION);
            conversationRepository.save(conversation);

            String formattedHour = formatHour(parsed.get());
            whatsAppCloudService.sendTextMessage(
                    conversation.getPhoneNumber(),
                    "Hora registrada a las " + formattedHour + ". "
                            + "Ahora comparte tu ubicacion desde el clip de WhatsApp."
            );
        } catch (IllegalArgumentException | EntityNotFoundException exception) {
            log.warn("No se pudo registrar el fichaje por WhatsApp. conversationId={}", conversation.getId(), exception);
            conversation.setState(WhatsAppClockInConversationState.EXPIRED);
            conversation.setCompletedAt(Instant.now());
            conversationRepository.save(conversation);
            whatsAppCloudService.sendTextMessage(
                    conversation.getPhoneNumber(),
                    "No he podido registrar el fichaje porque ya existe un registro para hoy o la hora no es valida."
            );
        }
    }

    private void processAdjustmentRequest(WhatsAppClockInConversation conversation, String rawText) {
        conversation.setLastInboundAt(Instant.now());
        conversation.setRawClockInText(rawText);

        Optional<AdjustmentInput> adjustmentInput = parseAdjustmentInput(rawText);
        if (adjustmentInput.isEmpty()) {
            conversationRepository.save(conversation);
            whatsAppCloudService.sendTextMessage(
                    conversation.getPhoneNumber(),
                    "No he entendido el ajuste. Responde con fecha y hora, por ejemplo: 19/05 8:00. "
                            + "Si es de hoy, tambien puedes responder solo con la hora."
            );
            return;
        }

        try {
            AdjustmentInput input = adjustmentInput.get();
            Instant requestedClockIn = input.workDate()
                    .atTime(input.clockIn())
                    .atZone(ZoneId.systemDefault())
                    .toInstant();

            timeAdjustmentRequestService.createFromWhatsApp(
                    conversation.getWorker().getId(),
                    input.workDate(),
                    requestedClockIn,
                    TimeEntryWorkSite.WORKSHOP,
                    ADJUSTMENT_REASON
            );

            conversation.setState(WhatsAppClockInConversationState.COMPLETED);
            conversation.setCompletedAt(Instant.now());
            conversationRepository.save(conversation);
            whatsAppCloudService.sendTextMessage(
                    conversation.getPhoneNumber(),
                    "Tu solicitud de ajuste se ha enviado correctamente. La revisaremos cuanto antes. Que tengas un buen dia."
            );
        } catch (IllegalArgumentException | EntityNotFoundException exception) {
            log.warn("No se pudo crear el ajuste de fichaje por WhatsApp. conversationId={}", conversation.getId(), exception);
            conversationRepository.save(conversation);
            whatsAppCloudService.sendTextMessage(
                    conversation.getPhoneNumber(),
                    "No he podido crear el ajuste. Revisa el formato y prueba de nuevo con fecha y hora."
            );
        }
    }

    private void processLocation(WhatsAppClockInConversation conversation, double latitude, double longitude) {
        conversation.setLastInboundAt(Instant.now());
        try {
            timeTrackingService.attachClockInLocation(conversation.getTimeEntry().getId(), latitude, longitude);
            conversation.setCompletedAt(Instant.now());
            conversation.setState(WhatsAppClockInConversationState.COMPLETED);
            conversationRepository.save(conversation);

            whatsAppCloudService.sendTextMessage(
                    conversation.getPhoneNumber(),
                    "Todo se ha procesado correctamente. Que tengas un buen dia."
            );
        } catch (IllegalArgumentException | EntityNotFoundException exception) {
            log.warn("No se pudo asociar la ubicacion al fichaje por WhatsApp. conversationId={}", conversation.getId(), exception);
            conversationRepository.save(conversation);
            whatsAppCloudService.sendTextMessage(
                    conversation.getPhoneNumber(),
                    "He guardado la hora, pero no he podido procesar la ubicacion. Intentalo de nuevo compartiendola."
            );
        }
    }

    @Transactional
    private void openActionMenu(Worker worker, String phoneNumber) {
        LocalDate today = LocalDate.now(ZoneId.systemDefault());
        expireStaleConversations(worker, today);
        startConversation(worker, phoneNumber, today, WhatsAppClockInConversationState.AWAITING_ACTION);
        sendActionMenu(worker, phoneNumber);
    }

    private void sendActionMenu(Worker worker, String phoneNumber) {
        whatsAppCloudService.sendQuickReplyButtonsMessage(
                phoneNumber,
                "Hola " + resolveWorkerFirstName(worker) + ", dime que deseas hacer:",
                List.of(
                        new WhatsAppCloudService.QuickReplyButton(ACTION_CLOCK_IN_NOW, "Fichar"),
                        new WhatsAppCloudService.QuickReplyButton(ACTION_TIME_ADJUSTMENT, "Ajuste")
                )
        );
    }

    private TimeEntry requireTimeEntryReference(Long entryId) {
        if (entryId == null) {
            throw new IllegalStateException("El fichaje de WhatsApp debe devolver un id");
        }
        return timeTrackingService.requireEntry(entryId);
    }

    private Optional<WhatsAppClockInConversation> findActiveConversation(String phoneNumber) {
        return conversationRepository.findFirstByPhoneNumberAndStateInOrderByRequestedAtDesc(phoneNumber, ACTIVE_STATES);
    }

    private void expireStaleConversations(Worker worker, LocalDate today) {
        List<WhatsAppClockInConversation> staleConversations = conversationRepository
                .findByWorkerIdAndStateInOrderByRequestedAtDesc(worker.getId(), ACTIVE_STATES);

        boolean changed = false;
        for (WhatsAppClockInConversation conversation : staleConversations) {
            if (today.equals(conversation.getReminderDate())) {
                continue;
            }
            conversation.setState(WhatsAppClockInConversationState.EXPIRED);
            conversation.setCompletedAt(Instant.now());
            changed = true;
        }
        if (changed) {
            conversationRepository.saveAll(staleConversations);
        }
    }

    private WhatsAppClockInConversation startConversation(Worker worker,
                                                          String phoneNumber,
                                                          LocalDate workDate,
                                                          WhatsAppClockInConversationState state) {
        WhatsAppClockInConversation conversation = conversationRepository
                .findFirstByWorkerIdAndReminderDateOrderByRequestedAtDesc(worker.getId(), workDate)
                .orElseGet(WhatsAppClockInConversation::new);

        conversation.setWorker(worker);
        conversation.setReminderDate(workDate);
        conversation.setPhoneNumber(phoneNumber);
        conversation.setState(state);
        conversation.setTimeEntry(null);
        conversation.setRequestedAt(Instant.now());
        conversation.setClockInRecordedAt(null);
        conversation.setLocationRequestedAt(null);
        conversation.setCompletedAt(null);
        conversation.setLastInboundAt(null);
        conversation.setRawClockInText(null);
        return conversationRepository.save(conversation);
    }

    private Optional<Worker> findWorkerByPhone(String normalizedPhone) {
        return workerRepository.findByRoleInAndActiveTrueOrderByFullNameAsc(WHATSAPP_WORKER_ROLES).stream()
                .filter(worker -> normalizeWorkerPhone(worker)
                        .map(normalizedPhone::equals)
                        .orElse(false))
                .findFirst();
    }

    private Optional<String> normalizeWorkerPhone(Worker worker) {
        String prefix = worker.getPhonePrefix();
        String phone = worker.getPhone();
        if (!hasText(prefix) || !hasText(phone)) {
            return Optional.empty();
        }
        String normalized = normalizePhoneDigits(prefix + phone);
        return hasText(normalized) ? Optional.of(normalized) : Optional.empty();
    }

    private Optional<LocalTime> parseHour(String rawText) {
        if (!hasText(rawText)) {
            return Optional.empty();
        }

        Matcher matcher = HOUR_PATTERN.matcher(rawText.trim());
        if (!matcher.matches()) {
            return Optional.empty();
        }

        int hour = Integer.parseInt(matcher.group(1));
        int minute = matcher.group(2) == null ? 0 : Integer.parseInt(matcher.group(2));
        if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
            return Optional.empty();
        }
        return Optional.of(LocalTime.of(hour, minute));
    }

    private Optional<AdjustmentInput> parseAdjustmentInput(String rawText) {
        if (!hasText(rawText)) {
            return Optional.empty();
        }

        String trimmed = rawText.trim();
        Matcher matcher = DATE_TIME_PATTERN.matcher(trimmed);
        if (matcher.matches()) {
            int day = Integer.parseInt(matcher.group(1));
            int month = Integer.parseInt(matcher.group(2));
            int year = matcher.group(3) == null
                    ? LocalDate.now(ZoneId.systemDefault()).getYear()
                    : Integer.parseInt(matcher.group(3));
            int hour = Integer.parseInt(matcher.group(4));
            int minute = matcher.group(5) == null ? 0 : Integer.parseInt(matcher.group(5));
            try {
                return Optional.of(new AdjustmentInput(
                        LocalDate.of(year, month, day),
                        LocalTime.of(hour, minute)
                ));
            } catch (RuntimeException exception) {
                return Optional.empty();
            }
        }

        return parseHour(trimmed)
                .map(localTime -> new AdjustmentInput(LocalDate.now(ZoneId.systemDefault()), localTime));
    }

    private String resolveWorkerFirstName(Worker worker) {
        if (worker == null || !hasText(worker.getFullName())) {
            return "compa";
        }

        String[] parts = worker.getFullName().trim().split("\\s+");
        return parts.length == 0 ? "compa" : parts[0];
    }

    private String formatHour(LocalTime time) {
        return String.format(Locale.ROOT, "%02d:%02d", time.getHour(), time.getMinute());
    }

    private String normalizePhoneDigits(String value) {
        if (!hasText(value)) {
            return null;
        }
        String normalized = value.replaceAll("\\D", "");
        return normalized.isBlank() ? null : normalized;
    }

    private String normalizeKeyword(String value) {
        if (!hasText(value)) {
            return "";
        }
        return Normalizer.normalize(value, Normalizer.Form.NFD)
                .replaceAll("\\p{M}+", "")
                .trim()
                .toLowerCase(Locale.ROOT);
    }

    private boolean hasText(String value) {
        return value != null && !value.isBlank();
    }

    private record AdjustmentInput(LocalDate workDate, LocalTime clockIn) {
    }
}

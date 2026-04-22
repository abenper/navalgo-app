package com.navalgo.backend.workorder;

import com.navalgo.backend.common.InputSanitizer;
import jakarta.persistence.EntityNotFoundException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.LinkedHashSet;
import java.util.List;

@Service
@Transactional(readOnly = true)
public class MaterialChecklistTemplateService {

    private final MaterialChecklistTemplateRepository templateRepository;
    private final MaterialRevisionRequestRepository revisionRequestRepository;
    private final InputSanitizer inputSanitizer;

    public MaterialChecklistTemplateService(MaterialChecklistTemplateRepository templateRepository,
                                           MaterialRevisionRequestRepository revisionRequestRepository,
                                           InputSanitizer inputSanitizer) {
        this.templateRepository = templateRepository;
        this.revisionRequestRepository = revisionRequestRepository;
        this.inputSanitizer = inputSanitizer;
    }

    public List<MaterialChecklistTemplateDto> findAll() {
        return templateRepository.findAllByOrderByUpdatedAtDesc()
                .stream()
                .map(this::toDto)
                .toList();
    }

    @Transactional
    public MaterialChecklistTemplateDto create(CreateMaterialChecklistTemplateRequest request) {
        MaterialChecklistTemplate template = new MaterialChecklistTemplate();
        applyRequest(template, request);
        return toDto(templateRepository.save(template));
    }

    @Transactional
    public MaterialChecklistTemplateDto update(Long id, CreateMaterialChecklistTemplateRequest request) {
        MaterialChecklistTemplate template = templateRepository.findById(id)
                .orElseThrow(() -> new EntityNotFoundException("Plantilla no encontrada"));
        applyRequest(template, request);
        return toDto(templateRepository.save(template));
    }

    private void applyRequest(MaterialChecklistTemplate template, CreateMaterialChecklistTemplateRequest request) {
        template.setName(inputSanitizer.requiredText(request.name(), "El nombre de la plantilla", 255));
        template.setDescription(inputSanitizer.optionalText(request.description(), 1000));

        template.getItems().clear();
        int index = 0;
        for (MaterialChecklistTemplateItemRequest itemRequest : request.items()) {
            MaterialChecklistTemplateItem item = new MaterialChecklistTemplateItem();
            item.setTemplate(template);
            item.setArticleName(inputSanitizer.requiredText(itemRequest.articleName(), "El articulo", 255));
            item.setReference(inputSanitizer.requiredText(itemRequest.reference(), "La referencia", 255));
            item.setSortOrder(itemRequest.sortOrder() == null ? index : itemRequest.sortOrder());
            template.getItems().add(item);
            index += 1;
        }
    }

    private MaterialChecklistTemplateDto toDto(MaterialChecklistTemplate template) {
        List<MaterialChecklistTemplateItemDto> items = template.getItems().stream()
                .map(item -> new MaterialChecklistTemplateItemDto(
                        item.getId(),
                        item.getArticleName(),
                        item.getReference(),
                        item.getSortOrder()
                ))
                .toList();

        MaterialTemplateIncidentAlertDto latestIncident = revisionRequestRepository
                .findTopBySourceTemplateIdOrderByCreatedAtDesc(template.getId())
                .map(this::toIncidentAlert)
                .orElse(null);

        return new MaterialChecklistTemplateDto(
                template.getId(),
                template.getName(),
                template.getDescription(),
                template.getCreatedAt(),
                template.getUpdatedAt(),
                items,
                latestIncident
        );
    }

    private MaterialTemplateIncidentAlertDto toIncidentAlert(MaterialRevisionRequest request) {
        return new MaterialTemplateIncidentAlertDto(
                request.getId(),
                request.getArticleName(),
                request.getReference(),
                request.getObservations(),
                request.getStatus(),
                request.getCreatedAt(),
                request.getRequestedByWorker() != null ? request.getRequestedByWorker().getFullName() : null
        );
    }
}
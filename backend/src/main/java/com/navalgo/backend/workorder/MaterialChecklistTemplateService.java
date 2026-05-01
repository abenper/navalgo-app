package com.navalgo.backend.workorder;

import com.navalgo.backend.common.InputSanitizer;
import jakarta.persistence.EntityNotFoundException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.*;

@Service
@Transactional(readOnly = true)
public class MaterialChecklistTemplateService {

    private final MaterialChecklistTemplateRepository templateRepository;
    private final MaterialRevisionRequestRepository revisionRequestRepository;
    private final MaterialProductRepository productRepository;
    private final InputSanitizer inputSanitizer;

    public MaterialChecklistTemplateService(MaterialChecklistTemplateRepository templateRepository,
                                           MaterialRevisionRequestRepository revisionRequestRepository,
                                           MaterialProductRepository productRepository,
                                           InputSanitizer inputSanitizer) {
        this.templateRepository = templateRepository;
        this.revisionRequestRepository = revisionRequestRepository;
        this.productRepository = productRepository;
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
        MaterialChecklistTemplateType templateType = request.templateType() == null
                ? MaterialChecklistTemplateType.BASIC
                : request.templateType();
        template.setTemplateType(templateType);

        if (templateType == MaterialChecklistTemplateType.COMPLETE) {
            if (request.baseTemplateId() == null) {
                throw new IllegalArgumentException("Una revision completa debe estar ligada a una plantilla basica");
            }
            MaterialChecklistTemplate baseTemplate = templateRepository.findById(request.baseTemplateId())
                    .orElseThrow(() -> new EntityNotFoundException("Plantilla basica no encontrada"));
            if (baseTemplate.getTemplateType() != MaterialChecklistTemplateType.BASIC) {
                throw new IllegalArgumentException("La plantilla vinculada debe ser de tipo basica");
            }
            if (template.getId() != null && template.getId().equals(baseTemplate.getId())) {
                throw new IllegalArgumentException("Una plantilla no puede vincularse a si misma");
            }
            template.setBaseTemplate(baseTemplate);
        } else {
            template.setBaseTemplate(null);
        }

        List<MaterialChecklistTemplateItemRequest> itemRequests = request.items() == null
                ? List.of()
                : request.items();
        if (templateType == MaterialChecklistTemplateType.BASIC && itemRequests.isEmpty()) {
            throw new IllegalArgumentException("Una plantilla basica debe tener al menos un material");
        }

        template.getItems().clear();
        int index = 0;
        for (MaterialChecklistTemplateItemRequest itemRequest : itemRequests) {
            String articleName = inputSanitizer.requiredText(itemRequest.articleName(), "El articulo", 255);
            String reference = inputSanitizer.requiredText(itemRequest.reference(), "La referencia", 255);
            MaterialProduct product = resolveProduct(articleName, reference);
            MaterialChecklistTemplateItem item = new MaterialChecklistTemplateItem();
            item.setTemplate(template);
            item.setProduct(product);
            item.setArticleName(product.getArticleName());
            item.setReference(product.getReference());
            item.setSortOrder(itemRequest.sortOrder() == null ? index : itemRequest.sortOrder());
            template.getItems().add(item);
            index += 1;
        }
    }

    private MaterialChecklistTemplateDto toDto(MaterialChecklistTemplate template) {
        List<Long> visibleProductIds = resolveVisibleProductIds(template, new HashSet<>());
        List<MaterialChecklistTemplateItemDto> items = template.getItems().stream()
                .map(item -> new MaterialChecklistTemplateItemDto(
                        item.getId(),
                        item.getProduct() != null ? item.getProduct().getId() : null,
                        item.getArticleName(),
                        item.getReference(),
                        item.getSortOrder()
                ))
                .toList();

        MaterialTemplateIncidentAlertDto latestIncident = visibleProductIds.isEmpty()
                ? null
                : revisionRequestRepository
                .findFirstByProductIdInOrderByCreatedAtDesc(visibleProductIds)
                .map(this::toIncidentAlert)
                .orElse(null);

        return new MaterialChecklistTemplateDto(
                template.getId(),
                template.getName(),
                template.getDescription(),
                template.getTemplateType(),
                template.getBaseTemplate() != null ? template.getBaseTemplate().getId() : null,
                template.getBaseTemplate() != null ? template.getBaseTemplate().getName() : null,
                template.getCreatedAt(),
                template.getUpdatedAt(),
                items,
                visibleProductIds.size(),
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

    private MaterialProduct resolveProduct(String articleName, String reference) {
        MaterialProduct product = productRepository.findFirstByReferenceIgnoreCase(reference)
                .orElseGet(MaterialProduct::new);
        product.setArticleName(articleName);
        product.setReference(reference);
        return productRepository.save(product);
    }

    private List<Long> resolveVisibleProductIds(MaterialChecklistTemplate template, Set<Long> visitedTemplateIds) {
        if (template.getId() != null && !visitedTemplateIds.add(template.getId())) {
            return List.of();
        }

        LinkedHashSet<Long> productIds = new LinkedHashSet<>();
        if (template.getTemplateType() == MaterialChecklistTemplateType.COMPLETE && template.getBaseTemplate() != null) {
            productIds.addAll(resolveVisibleProductIds(template.getBaseTemplate(), visitedTemplateIds));
        }
        template.getItems().stream()
                .map(MaterialChecklistTemplateItem::getProduct)
                .filter(Objects::nonNull)
                .map(MaterialProduct::getId)
                .filter(Objects::nonNull)
                .forEach(productIds::add);
        return List.copyOf(productIds);
    }
}

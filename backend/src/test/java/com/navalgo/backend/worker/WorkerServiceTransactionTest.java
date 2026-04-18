package com.navalgo.backend.worker;

import org.junit.jupiter.api.Test;
import org.springframework.transaction.annotation.AnnotationTransactionAttributeSource;
import org.springframework.transaction.interceptor.TransactionAttribute;

import static org.assertj.core.api.Assertions.assertThat;

class WorkerServiceTransactionTest {

    @Test
    void createUsesWritableTransaction() throws NoSuchMethodException {
        AnnotationTransactionAttributeSource transactionSource = new AnnotationTransactionAttributeSource();
        TransactionAttribute transactionAttribute = transactionSource.getTransactionAttribute(
                WorkerService.class.getMethod("create", CreateWorkerRequest.class),
                WorkerService.class
        );

        assertThat(transactionAttribute).isNotNull();
        assertThat(transactionAttribute.isReadOnly()).isFalse();
    }
}
package com.navalgo.backend.auth;

import org.junit.jupiter.api.Test;
import org.springframework.transaction.annotation.AnnotationTransactionAttributeSource;
import org.springframework.transaction.interceptor.TransactionAttribute;

import static org.assertj.core.api.Assertions.assertThat;

class AuthServiceTransactionTest {

    @Test
    void changePasswordUsesWritableTransaction() throws NoSuchMethodException {
        AnnotationTransactionAttributeSource transactionSource = new AnnotationTransactionAttributeSource();
        TransactionAttribute transactionAttribute = transactionSource.getTransactionAttribute(
                AuthService.class.getMethod("changePassword", String.class, ChangePasswordRequest.class),
                AuthService.class
        );

        assertThat(transactionAttribute).isNotNull();
        assertThat(transactionAttribute.isReadOnly()).isFalse();
    }
}
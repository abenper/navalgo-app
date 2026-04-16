package com.navalgo.backend.auth;

public class InvalidCredentialsException extends RuntimeException {

    public InvalidCredentialsException() {
        super("Credenciales invalidas");
    }

    public InvalidCredentialsException(String message) {
        super(message);
    }
}
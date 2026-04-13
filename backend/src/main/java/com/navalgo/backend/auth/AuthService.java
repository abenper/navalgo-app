package com.navalgo.backend.auth;

import com.navalgo.backend.security.JwtService;
import com.navalgo.backend.worker.Worker;
import com.navalgo.backend.worker.WorkerRepository;
import com.navalgo.backend.worker.WorkerService;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;

import java.util.Map;

@Service
public class AuthService {

    private final WorkerRepository workerRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtService jwtService;
    private final WorkerService workerService;

    public AuthService(WorkerRepository workerRepository,
                       PasswordEncoder passwordEncoder,
                       JwtService jwtService,
                       WorkerService workerService) {
        this.workerRepository = workerRepository;
        this.passwordEncoder = passwordEncoder;
        this.jwtService = jwtService;
        this.workerService = workerService;
    }

    public LoginResponse login(LoginRequest request) {
        Worker worker = workerRepository.findByEmailIgnoreCase(request.email())
                .orElseThrow(() -> new IllegalArgumentException("Credenciales invalidas"));

        if (!worker.isActive()) {
            throw new IllegalArgumentException("Usuario inactivo");
        }

        if (!passwordEncoder.matches(request.password(), worker.getPasswordHash())) {
            throw new IllegalArgumentException("Credenciales invalidas");
        }

        String token = jwtService.generateToken(worker.getEmail(), Map.of(
                "role", worker.getRole().name(),
                "userId", worker.getId()
        ));

        AuthUserDto userDto = new AuthUserDto(
                worker.getId(),
                worker.getFullName(),
                worker.getEmail(),
                worker.getRole(),
                worker.isMustChangePassword(),
                worker.isCanEditWorkOrders()
        );
        return new LoginResponse(userDto, token);
    }

    public void changePassword(String email, ChangePasswordRequest request) {
        workerService.changeOwnPassword(email, request.currentPassword(), request.newPassword());
    }
}

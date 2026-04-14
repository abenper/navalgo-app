package com.navalgo.backend.common;

import com.navalgo.backend.company.Company;
import com.navalgo.backend.company.CompanyRepository;
import com.navalgo.backend.fleet.*;
import com.navalgo.backend.worker.Worker;
import com.navalgo.backend.worker.WorkerRepository;
import org.springframework.boot.CommandLineRunner;
import org.springframework.context.annotation.Profile;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;

import java.security.SecureRandom;

@Component
@Profile("dev")
public class DataInitializer implements CommandLineRunner {

    private final WorkerRepository workerRepository;
    private final CompanyRepository companyRepository;
    private final OwnerRepository ownerRepository;
    private final VesselRepository vesselRepository;
    private final PasswordEncoder passwordEncoder;
    private final SecureRandom secureRandom = new SecureRandom();
    private static final String PASSWORD_CHARS = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789@#$%";

    public DataInitializer(WorkerRepository workerRepository,
                           CompanyRepository companyRepository,
                           OwnerRepository ownerRepository,
                           VesselRepository vesselRepository,
                           PasswordEncoder passwordEncoder) {
        this.workerRepository = workerRepository;
        this.companyRepository = companyRepository;
        this.ownerRepository = ownerRepository;
        this.vesselRepository = vesselRepository;
        this.passwordEncoder = passwordEncoder;
    }

    @Override
    public void run(String... args) {
        if (workerRepository.count() > 0) {
            return;
        }

        Worker admin = new Worker();
        admin.setFullName("Admin Navalgo");
        admin.setEmail("admin@navalgo.com");
        admin.setPasswordHash(passwordEncoder.encode(generateTemporaryPassword(16)));
        admin.setSpeciality("Gestion");
        admin.setRole(Role.ADMIN);
        admin.setActive(true);
        admin.setMustChangePassword(true);
        admin.setCanEditWorkOrders(true);
        workerRepository.save(admin);

        Worker worker = new Worker();
        worker.setFullName("Juan Perez");
        worker.setEmail("worker@navalgo.com");
        worker.setPasswordHash(passwordEncoder.encode(generateTemporaryPassword(16)));
        worker.setSpeciality("Motores Diesel");
        worker.setRole(Role.WORKER);
        worker.setActive(true);
        worker.setMustChangePassword(true);
        worker.setCanEditWorkOrders(false);
        workerRepository.save(worker);

        Company company = new Company();
        company.setName("Naviera Sur S.A.");
        company.setTaxId("A12345678");
        company.setPhone("600000000");
        company.setEmail("info@navierasur.com");
        company.setAddress("Puerto de Malaga");
        company = companyRepository.save(company);

        Owner owner = new Owner();
        owner.setType(OwnerType.COMPANY);
        owner.setDisplayName("Naviera Sur S.A.");
        owner.setDocumentId("A12345678");
        owner.setPhone("600000000");
        owner.setEmail("info@navierasur.com");
        owner.setCompany(company);
        owner = ownerRepository.save(owner);

        Vessel vessel = new Vessel();
        vessel.setName("Sea Runner");
        vessel.setRegistrationNumber("ES-MLG-0001");
        vessel.setModel("Yamaha 35");
        vessel.setEngineCount(2);
        vessel.setLengthMeters(11.2);
        vessel.setOwner(owner);
        vesselRepository.save(vessel);
    }

    private String generateTemporaryPassword(int length) {
        StringBuilder password = new StringBuilder(length);
        for (int i = 0; i < length; i++) {
            int index = secureRandom.nextInt(PASSWORD_CHARS.length());
            password.append(PASSWORD_CHARS.charAt(index));
        }
        return password.toString();
    }
}

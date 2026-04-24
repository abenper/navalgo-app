package com.navalgo.backend;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableScheduling;

@SpringBootApplication
@EnableScheduling
public class NavalgoBackendApplication {

    public static void main(String[] args) {
        SpringApplication.run(NavalgoBackendApplication.class, args);
    }
}

package com.example.demo;

import com.example.demo.controller.HelloController;
import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;

import static org.assertj.core.api.Assertions.assertThat;

@SpringBootTest
class DemoApplicationTests {

    @Test
    void contextLoads() {
        // Verifies the Spring application context starts successfully
    }

    @Test
    void homeEndpointReturnsExpectedMessage() {
        HelloController controller = new HelloController();
        assertThat(controller.home()).isEqualTo("CI/CD Pipeline Demo App is running!");
    }

    @Test
    void healthEndpointReturnsOk() {
        HelloController controller = new HelloController();
        assertThat(controller.health()).isEqualTo("OK");
    }
}

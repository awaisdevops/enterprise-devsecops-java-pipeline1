package com.example;

import org.junit.Test;
import org.junit.runner.RunWith;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.client.TestRestTemplate;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.test.context.ContextConfiguration;
import org.springframework.test.context.junit4.SpringRunner;

import static org.junit.Assert.*;

/**
 * Integration tests for the Application
 * Maven Failsafe plugin will automatically run any test class that:
 * - Matches *IT.java or *ITCase.java pattern
 * - Is in src/test/java directory
 */
@RunWith(SpringRunner.class)
@ContextConfiguration(classes = Application.class)
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
public class MyServiceIT {

    @Autowired
    private TestRestTemplate restTemplate;

    @Test
    public void testApplicationContextLoads() {
        // Test that the Spring application context loads successfully
        assertNotNull("RestTemplate should be autowired", restTemplate);
    }

    @Test
    public void testIndexPageLoads() {
        // TestRestTemplate automatically uses the correct port and base URL
        ResponseEntity<String> response = restTemplate.getForEntity("/", String.class);
        
        assertEquals("HTTP status should be OK", HttpStatus.OK, response.getStatusCode());
        assertNotNull("Response body should not be null", response.getBody());
        assertTrue("Response should contain content", response.getBody().length() > 0);
    }

    @Test
    public void testApplicationGetStatus() {
        // Test the Application getStatus method
        Application app = new Application();
        String status = app.getStatus();
        assertEquals("Status should be OK", "OK", status);
    }
    
    @Test
    public void testActuatorHealth() {
        // Test that actuator health endpoint is accessible
        ResponseEntity<String> response = restTemplate.getForEntity("/actuator/health", String.class);
        assertEquals("Health endpoint should be OK", HttpStatus.OK, response.getStatusCode());
    }
} 

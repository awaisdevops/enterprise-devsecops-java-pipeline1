package com.example;

import org.junit.Test;
import org.junit.runner.RunWith;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.client.TestRestTemplate;
import org.springframework.boot.web.server.LocalServerPort;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.test.context.junit4.SpringRunner;

import static org.junit.Assert.*;

/**
 * Integration tests for the Application
 * Maven Failsafe plugin will automatically run any test class that:
 * - Matches *IT.java or *ITCase.java pattern
 * - Is in src/test/java directory
 */
@RunWith(SpringRunner.class)
@SpringBootTest(classes = Application.class, webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
public class MyServiceIT {

    @LocalServerPort
    private int port;

    @Autowired
    private TestRestTemplate restTemplate;

    @Test
    public void testApplicationContextLoads() {
        // Test that the Spring application context loads successfully
        assertNotNull("RestTemplate should be autowired", restTemplate);
        assertTrue("Port should be greater than 0", port > 0);
    }

    @Test
    public void testIndexPageLoads() {
        // Test that the index page is accessible
        String url = "http://localhost:" + port + "/";
        ResponseEntity<String> response = restTemplate.getForEntity(url, String.class);
        
        assertEquals("HTTP status should be OK", HttpStatus.OK, response.getStatusCode());
        assertNotNull("Response body should not be null", response.getBody());
    }

    @Test
    public void testApplicationGetStatus() {
        // Test the Application getStatus method in integration context
        Application app = new Application();
        String status = app.getStatus();
        assertEquals("Status should be OK", "OK", status);
    }
} 

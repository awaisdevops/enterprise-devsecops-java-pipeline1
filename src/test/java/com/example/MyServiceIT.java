package com.example;

import org.junit.Test;
import static org.junit.Assert.*;

/**
 * Simple integration tests for the Application
 * Maven Failsafe plugin will automatically run any test class that:
 * - Matches *IT.java or *ITCase.java pattern
 * - Is in src/test/java directory
 */
public class MyServiceIT {

    @Test
    public void testApplicationExists() {
        // Simple test to verify Application class exists
        Application app = new Application();
        assertNotNull("Application should not be null", app);
    }

    @Test
    public void testApplicationGetStatus() {
        // Test the Application getStatus method
        Application app = new Application();
        String status = app.getStatus();
        assertEquals("Status should be OK", "OK", status);
    }
    
    @Test
    public void testSimpleAddition() {
        // Simple math test to verify tests are running
        int result = 2 + 2;
        assertEquals("2 + 2 should equal 4", 4, result);
    }
    
    @Test
    public void testStringConcatenation() {
        // Simple string test
        String result = "Hello" + " " + "World";
        assertEquals("String concatenation should work", "Hello World", result);
    }
} 

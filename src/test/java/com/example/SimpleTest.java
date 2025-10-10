package com.example;

import org.junit.Test;
import static org.junit.Assert.*;

/**
 * Unit tests for the Application class
 * Maven Surefire plugin will automatically run any test class that:
 * - Matches *Test.java pattern
 * - Is in src/test/java directory
 */
public class SimpleTest {

    @Test
    public void testApplicationGetStatus() {
        // Test the getStatus method
        Application app = new Application();
        String status = app.getStatus();
        assertNotNull("Status should not be null", status);
        assertEquals("Status should be OK", "OK", status);
    }

    @Test
    public void testBasicAssertion() {
        // A basic passing test to ensure reports are generated
        assertTrue("This should always pass", true);
    }
    
    @Test
    public void testStringComparison() {
        String expected = "Hello";
        String actual = "Hello";
        assertEquals("Strings should match", expected, actual);
    }
    
    @Test
    public void testNotNull() {
        Object obj = new Object();
        assertNotNull("Object should not be null", obj);
    }
    
    @Test
    public void testApplicationNotNull() {
        Application app = new Application();
        assertNotNull("Application instance should not be null", app);
    }
}

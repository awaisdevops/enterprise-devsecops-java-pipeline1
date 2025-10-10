package com.example;

import org.junit.Test;
import static org.junit.Assert.*;

/**
 * Simple integration tests - dummy tests for pipeline testing purposes
 * Maven Failsafe plugin will automatically run any test class that:
 * - Matches *IT.java or *ITCase.java pattern
 * - Is in src/test/java directory
 */
public class MyServiceIT {

    @Test
    public void testAlwaysPass1() {
        // Simple test that always passes
        assertTrue("This test always passes", true);
    }

    @Test
    public void testAlwaysPass2() {
        // Another simple test that always passes
        assertEquals("1 should equal 1", 1, 1);
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

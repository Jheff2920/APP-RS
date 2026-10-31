package com.example.hello_world_app.printservice

import org.junit.Assert.*
import org.junit.Test
import java.util.Collections
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

class PrinterJobCoordinatorTest {
    @Test fun jobsCannotInterleaveAndFailureReleasesTheConnection() {
        val events = Collections.synchronizedList(mutableListOf<String>())
        val started = CountDownLatch(1)
        val finishFirst = CountDownLatch(1)
        val pool = Executors.newFixedThreadPool(2)
        try {
            val first = pool.submit {
                try {
                    PrinterJobCoordinator.runJob {
                        events.add("receipt:open")
                        started.countDown()
                        check(finishFirst.await(5, TimeUnit.SECONDS))
                        events.add("receipt:close")
                        throw IllegalStateException("printer offline")
                    }
                } catch (_: IllegalStateException) { }
            }
            assertTrue(started.await(5, TimeUnit.SECONDS))
            val second = pool.submit {
                PrinterJobCoordinator.runJob {
                    events.add("label:open")
                    events.add("label:close")
                }
            }
            finishFirst.countDown()
            first.get(5, TimeUnit.SECONDS)
            second.get(5, TimeUnit.SECONDS)
            assertEquals(listOf("receipt:open", "receipt:close", "label:open", "label:close"), events)
        } finally { finishFirst.countDown(); pool.shutdownNow() }
    }

    @Test fun staleReleaseCannotUnlockAnotherJob() {
        val token = PrinterJobCoordinator.acquire()
        PrinterJobCoordinator.release("stale-token")
        PrinterJobCoordinator.release(token)
        val next = PrinterJobCoordinator.acquire()
        assertNotEquals(token, next)
        PrinterJobCoordinator.release(token)
        PrinterJobCoordinator.release(next)
    }
}

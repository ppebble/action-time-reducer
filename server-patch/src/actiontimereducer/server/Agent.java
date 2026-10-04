package actiontimereducer.server;

import java.io.InputStream;
import java.lang.instrument.Instrumentation;
import java.nio.charset.StandardCharsets;

/** Installs an in-memory, version-pinned hook; never replaces game files. */
public final class Agent {
    private Agent() {}

    public static void premain(String arguments, Instrumentation instrumentation) throws Exception {
        for (Class<?> loaded : instrumentation.getAllLoadedClasses()) {
            if (loaded.getName().equals("zombie.core.Transaction")) {
                throw new IllegalStateException("Safe Action Time must load before Transaction; restart with -javaagent.");
            }
        }
        String fingerprint;
        try (InputStream input = Agent.class.getResourceAsStream("/supported-class.sha256")) {
            if (input == null) throw new IllegalStateException("Missing supported Transaction fingerprint.");
            fingerprint = new String(input.readAllBytes(), StandardCharsets.US_ASCII).trim();
        }
        instrumentation.addTransformer(new TransactionTransformer(fingerprint), false);
        System.err.println("[ActionTimeReducer] Server inventory hook armed; waiting for the supported Transaction class.");
    }
}

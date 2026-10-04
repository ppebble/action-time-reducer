package actiontimereducer.server;

import java.nio.file.Files;
import java.nio.file.Path;
import java.security.MessageDigest;
import java.util.HexFormat;
import java.util.jar.JarFile;

/** Runs the production transformer on the shipped Java25 JVM for the JDK21 bytecode audit. */
public final class EmitTransformedAudit {
    public static void main(String[] args) throws Exception {
        if (args.length != 2) throw new IllegalArgumentException("Pass game jar and audit output class path");
        byte[] original;
        try (JarFile jar = new JarFile(args[0])) {
            original = jar.getInputStream(jar.getJarEntry("zombie/core/Transaction.class")).readAllBytes();
        }
        String hash = HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(original));
        byte[] patched = new TransactionTransformer(hash).transformBytes(original);
        Files.write(Path.of(args[1]), patched);
        System.out.println("PASS shipped JVM production transform emitted for offline audit");
    }
}

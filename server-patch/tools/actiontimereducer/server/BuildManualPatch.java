package actiontimereducer.server;

import java.nio.file.Files;
import java.nio.file.Path;
import java.util.List;
import java.util.jar.JarFile;

/** Build-time tool only. Distribute only the transformed class and duration helpers. */
public final class BuildManualPatch {
    private static final String SUPPORTED = "107B0A554CC46D1015398FF283A2E48FAF02EFBC44ADF12854F66394EE2487B6";

    public static void main(String[] args) throws Exception {
        if (args.length != 2) throw new IllegalArgumentException("Expected installed game jar and output class");
        byte[] original;
        try (JarFile jar = new JarFile(args[0])) {
            var entry = jar.getJarEntry("zombie/core/Transaction.class");
            if (entry == null) throw new IllegalArgumentException("Transaction.class missing");
            try (var stream = jar.getInputStream(entry)) { original = stream.readAllBytes(); }
        }
        byte[] patched = new TransactionTransformer(SUPPORTED).transformBytes(original);
        Class<?> api = Class.forName("java.lang.classfile.ClassFile");
        Object parser = api.getMethod("of").invoke(null);
        List<?> problems = (List<?>) api.getMethod("verify", byte[].class).invoke(parser, (Object) patched);
        if (!problems.isEmpty()) throw new IllegalStateException("Patched class verification failed: " + problems);
        Path output = Path.of(args[1]);
        Files.createDirectories(output.getParent());
        Files.write(output, patched);
        System.out.println("PASS manual Transaction.class generated for pinned B42.21; class-file verification clean");
    }
}

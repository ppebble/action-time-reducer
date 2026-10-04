package actiontimereducer.server;

import java.lang.management.ManagementFactory;
import java.nio.file.Path;

/** Fresh native JVM probe. It deliberately does not initialize game/server state. */
public final class ManualClassLoadSmoke {
    public static void main(String[] args) throws Exception {
        if (args.length < 2) throw new IllegalArgumentException("Pass expected Transaction origin and overlay|vanilla mode");
        if (ManagementFactory.getRuntimeMXBean().getInputArguments().stream()
                .anyMatch(argument -> argument.startsWith("-javaagent"))) {
            throw new AssertionError("Manual-copy probe must run without an agent");
        }
        ClassLoader loader = ManualClassLoadSmoke.class.getClassLoader();
        Class<?> transaction = Class.forName("zombie.core.Transaction", false, loader);
        Path actual = Path.of(transaction.getProtectionDomain().getCodeSource().getLocation().toURI()).toRealPath();
        Path expected = Path.of(args[0]).toRealPath();
        if (!actual.equals(expected)) throw new AssertionError("Wrong Transaction origin: " + actual + "; expected " + expected);
        if (args[1].equals("overlay")) {
            Class<?> helper = Class.forName("actiontimereducer.server.TransferDuration", false, loader);
            Path helperOrigin = Path.of(helper.getProtectionDomain().getCodeSource().getLocation().toURI()).toRealPath();
            if (!helperOrigin.equals(expected)) throw new AssertionError("Helper is not loaded from manual-copy folder");
            if (helper.getMethod("scale", float.class).getReturnType() != float.class) throw new AssertionError("Wrong helper signature");
        } else if (!args[1].equals("vanilla")) {
            throw new IllegalArgumentException("Unknown probe mode");
        }
        System.out.println("PASS no-agent " + args[1] + " Transaction class loading: " + actual);
        if (args.length == 3 && args[2].equals("--child")) {
            String executable = Path.of(System.getProperty("java.home"), "bin", "java.exe").toString();
            Process child = new ProcessBuilder(executable, "-Xverify:all", "-cp",
                    System.getProperty("java.class.path"), ManualClassLoadSmoke.class.getName(), args[0], args[1])
                    .inheritIO().start();
            if (child.waitFor() != 0) throw new AssertionError("Child JVM classpath probe failed");
            System.out.println("PASS child Java process reuses the overlay classpath without an agent");
        }
        System.out.println("LIMITATION: class loading only; no server initialization, actual game host or gameplay clients.");
    }
}

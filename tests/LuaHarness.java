import java.nio.file.Files;
import java.nio.file.Path;
import java.lang.reflect.Method;
import java.util.Arrays;

/** Executes tests with the installed game's Kahlua VM, not a different Lua runtime. */
public final class LuaHarness {
    public static void main(String[] args) throws Exception {
        Class<?> table = Class.forName("se.krka.kahlua.vm.KahluaTable");
        Class<?> platformType = Class.forName("se.krka.kahlua.vm.Platform");
        Class<?> platformClass = Class.forName("se.krka.kahlua.j2se.J2SEPlatform");
        Object platform = platformClass.getMethod("getInstance").invoke(null);
        Object environment = platformClass.getMethod("newEnvironment").invoke(platform);
        table.getMethod("rawset", Object.class, Object.class).invoke(environment, "TEST_MODE", args[0]);
        Class<?> threadType = Class.forName("se.krka.kahlua.vm.KahluaThread");
        Object thread = threadType.getConstructor(platformType, table).newInstance(platform, environment);
        threadType.getField("debugOwnerThread").set(thread, Thread.currentThread());
        Method compile = Class.forName("se.krka.kahlua.luaj.compiler.LuaCompiler")
            .getMethod("loadstring", String.class, String.class, table);
        Method run = threadType.getMethod("pcall", Object.class, Object[].class);
        for (int i = 1; i < args.length; i++) {
            Object chunk = compile.invoke(null, Files.readString(Path.of(args[i])), args[i], environment);
            Object[] result = (Object[])run.invoke(thread, chunk, new Object[0]);
            if (!Boolean.TRUE.equals(result[0])) throw new AssertionError(args[i] + ": " + Arrays.toString(result));
        }
        Object checks = table.getMethod("rawget", Object.class).invoke(environment, "checks");
        System.out.println("PASS Kahlua " + args[0] + " checks=" + checks);
    }
}

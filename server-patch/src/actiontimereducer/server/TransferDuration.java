package actiontimereducer.server;

import java.lang.reflect.Field;
import java.lang.reflect.Method;

/** Reads server-owned sandbox settings after vanilla duration and trait calculations. */
public final class TransferDuration {
    private TransferDuration() {}

    public static float scale(float vanillaMilliseconds) {
        if (!Float.isFinite(vanillaMilliseconds) || vanillaMilliseconds <= 0) return vanillaMilliseconds;
        try {
            if (!Access.SERVER.getBoolean(null)) return vanillaMilliseconds;
            Object environment = Access.ENVIRONMENT.get(null);
            if (environment == null) return vanillaMilliseconds;
            Object mod = rawget(environment, "ActionTimeReducer");
            if (!Boolean.TRUE.equals(rawget(mod, "installed"))) return vanillaMilliseconds;
            if (!Boolean.FALSE.equals(rawget(mod, "conflictBlocked"))) return vanillaMilliseconds;
            Object sandbox = rawget(environment, "SandboxVars");
            Object settings = rawget(sandbox, "ActionTimeReducer");
            Object configured = rawget(settings, "InventoryTransfer");
            if (!(configured instanceof Number)) return vanillaMilliseconds;
            double reduction = ((Number) configured).doubleValue();
            if (!Double.isFinite(reduction) || reduction <= 0 || reduction > 95) return vanillaMilliseconds;
            return Math.max(1.0f, (float) (vanillaMilliseconds * (1.0 - reduction / 100.0)));
        } catch (ReflectiveOperationException | RuntimeException | LinkageError unavailable) {
            // Startup, absent Lua mod, or an incompatible environment keeps vanilla authority.
            return vanillaMilliseconds;
        }
    }

    private static Object rawget(Object table, String key) throws ReflectiveOperationException {
        return Access.TABLE.isInstance(table) ? Access.RAWGET.invoke(table, key) : null;
    }

    /** Public API references resolve on the first game transaction, never in premain. */
    private static final class Access {
        static final Field SERVER;
        static final Field ENVIRONMENT;
        static final Class<?> TABLE;
        static final Method RAWGET;

        static {
            try {
                ClassLoader loader = TransferDuration.class.getClassLoader();
                SERVER = Class.forName("zombie.network.GameServer", false, loader).getField("server");
                ENVIRONMENT = Class.forName("zombie.Lua.LuaManager", false, loader).getField("env");
                TABLE = Class.forName("se.krka.kahlua.vm.KahluaTable", false, loader);
                RAWGET = TABLE.getMethod("rawget", Object.class);
            } catch (ReflectiveOperationException failure) {
                throw new ExceptionInInitializerError(failure);
            }
        }
    }
}

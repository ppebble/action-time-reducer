package actiontimereducer.server;

import java.io.InputStream;
import java.lang.reflect.Method;
import java.nio.file.Files;
import java.nio.file.Path;
import java.security.MessageDigest;
import java.util.Arrays;
import java.util.HashMap;
import java.util.HexFormat;
import java.util.Map;
import java.util.jar.JarFile;
import jdk.internal.org.objectweb.asm.*;

/** Offline bytecode and isolated setting tests. Does not initialize the game. */
public final class PatchAudit {
    private static int assertions;

    public static void main(String[] args) throws Exception {
        if (args.length == 1 && args[0].equals("--settings-only")) {
            settingsFixtures();
            System.out.println("PASS " + assertions + " isolated settings assertions");
            return;
        }
        if (args.length != 2) throw new IllegalArgumentException("Pass installed projectzomboid.jar and transformed audit class");
        byte[] original;
        byte[] packet;
        try (JarFile jar = new JarFile(args[0])) {
            original = jar.getInputStream(jar.getJarEntry("zombie/core/Transaction.class")).readAllBytes();
            packet = jar.getInputStream(jar.getJarEntry("zombie/network/packets/ItemTransactionPacket.class")).readAllBytes();
        }
        String hash = HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(original));
        TransactionTransformer transformer = new TransactionTransformer(hash);
        byte[] patched = Files.readAllBytes(Path.of(args[1]));
        check(!Arrays.equals(original, patched), "Transaction is changed");
        check(Arrays.equals(Arrays.copyOf(original, 8), Arrays.copyOf(patched, 8)), "Class magic and version preserved");
        check(Arrays.equals(canonical(original, true, false), canonical(patched, true, false)),
                "All fields, class metadata, signatures and methods except getDuration are unchanged");
        check(Arrays.equals(canonical(original, false, false), canonical(patched, false, true)),
                "Removing only the helper call restores original instructions and debug metadata (frames may be rebuilt)");
        check(countHelperCalls(patched) == 1, "Exactly one helper invocation");
        check(transformer.transform(null, "zombie/network/packets/ItemTransactionPacket", null, null, packet) == null,
                "Packet class is untouched");
        check(transformer.transform(null, "other/Class", null, null, original) == null, "Unrelated classes untouched");
        TransactionTransformer mismatched = new TransactionTransformer("0".repeat(64));
        check(mismatched.transform(null, "zombie/core/Transaction", null, null, original) == null,
                "Fingerprint mismatch leaves vanilla class untouched");
        check(transformer.transform(null, "zombie/core/Transaction", null, null, patched) == null,
                "An already modified class cannot be patched again");
        settingsFixtures();
        System.out.println("PASS " + assertions + " server-patch audit assertions; installed Transaction SHA-256 " + hash);
        System.out.println("LIMITATION: isolated globals are fixtures; this is not a running dedicated server or connected-client test.");
    }

    private static byte[] canonical(byte[] bytes, boolean omitDuration, boolean removeHelper) {
        ClassWriter writer = new ClassWriter(0);
        reader(bytes).accept(new ClassVisitor(Opcodes.ASM8, writer) {
            @Override public MethodVisitor visitMethod(int access, String name, String descriptor,
                                                       String signature, String[] exceptions) {
                if (omitDuration && name.equals("getDuration") && descriptor.equals("()F")) return null;
                MethodVisitor target = super.visitMethod(access, name, descriptor, signature, exceptions);
                return new MethodVisitor(Opcodes.ASM8, target) {
                    @Override public void visitMethodInsn(int opcode, String owner, String method,
                                                          String descriptor, boolean isInterface) {
                        if (removeHelper && owner.equals("actiontimereducer/server/TransferDuration") &&
                                method.equals("scale") && descriptor.equals("(F)F")) return;
                        super.visitMethodInsn(opcode, owner, method, descriptor, isInterface);
                    }
                };
            }
        }, omitDuration ? 0 : ClassReader.SKIP_FRAMES);
        return writer.toByteArray();
    }

    private static int countHelperCalls(byte[] bytes) {
        int[] calls = {0};
        reader(bytes).accept(new ClassVisitor(Opcodes.ASM8) {
            @Override public MethodVisitor visitMethod(int access, String name, String descriptor,
                                                       String signature, String[] exceptions) {
                return new MethodVisitor(Opcodes.ASM8) {
                    @Override public void visitMethodInsn(int opcode, String owner, String method,
                                                          String descriptor, boolean isInterface) {
                        if (owner.equals("actiontimereducer/server/TransferDuration")) {
                            check(name.equals("getDuration") && descriptor.equals("(F)F") &&
                                    method.equals("scale") && opcode == Opcodes.INVOKESTATIC,
                                    "Helper call is exclusively the getDuration float-return hook");
                            calls[0]++;
                        }
                    }
                };
            }
        }, 0);
        return calls[0];
    }

    private static ClassReader reader(byte[] bytes) {
        // The shipped game uses class version 69. The audit's JDK21 ASM can read its
        // instruction format after normalizing ONLY the parser copy's version to 65.
        // Original and transformed headers are separately compared above. These
        // normalized copies are never loaded, saved or distributed as game classes.
        byte[] parserCopy = bytes.clone();
        parserCopy[6] = 0; parserCopy[7] = 65;
        return new ClassReader(parserCopy);
    }

    private static void settingsFixtures() throws Exception {
        FixtureLoader loader = new FixtureLoader();
        Class<?> server = loader.loadClass("zombie.network.GameServer");
        Class<?> lua = loader.loadClass("zombie.Lua.LuaManager");
        Method scale = loader.loadClass("actiontimereducer.server.TransferDuration").getMethod("scale", float.class);
        Class<?> table = loader.loadClass("fixtures.Table");
        Map<Object,Object> environment = makeTable(table), sandbox = makeTable(table), settings = makeTable(table), mod = makeTable(table);
        environment.put("SandboxVars", sandbox); sandbox.put("ActionTimeReducer", settings);
        environment.put("ActionTimeReducer", mod); mod.put("installed", true); mod.put("conflictBlocked", false);
        lua.getField("env").set(null, environment); server.getField("server").setBoolean(null, true);
        for (double percentage : new double[]{0, 10, 30, 50, 95}) {
            settings.put("InventoryTransfer", percentage);
            near((Float) scale.invoke(null, 1000f), (float) (1000 * (1-percentage/100)), "Configured " + percentage);
            near((Float) scale.invoke(null, 500f), (float) (500 * (1-percentage/100)), "Vanilla Dextrous result composes " + percentage);
        }
        for (Object invalid : new Object[]{-1d, 96d, Double.NaN, Double.POSITIVE_INFINITY, "30", true}) {
            settings.put("InventoryTransfer", invalid);
            near((Float) scale.invoke(null, 1000f), 1000f, "Invalid setting fails closed: " + invalid);
        }
        settings.put("InventoryTransfer", 30d);
        server.getField("server").setBoolean(null, false);
        near((Float) scale.invoke(null, 1000f), 1000f, "Client/singleplayer unaffected");
        server.getField("server").setBoolean(null, true);
        mod.put("installed", false);
        near((Float) scale.invoke(null, 1000f), 1000f, "Inactive Lua mod unaffected");
        mod.put("installed", true);
        mod.put("conflictBlocked", true);
        near((Float) scale.invoke(null, 1000f), 1000f, "Conflict blocked mod unaffected");
        mod.put("conflictBlocked", false);
        near((Float) scale.invoke(null, .1f), 1f, "Positive duration never falls below one millisecond");
        lua.getField("env").set(null, null);
        near((Float) scale.invoke(null, 1000f), 1000f, "Startup env unavailable");
        lua.getField("env").set(null, environment);
        environment.remove("ActionTimeReducer");
        near((Float) scale.invoke(null, 1000f), 1000f, "Missing Lua mod fails closed");
        environment.put("ActionTimeReducer", mod);
        settings.remove("InventoryTransfer");
        near((Float) scale.invoke(null, 1000f), 1000f, "Missing setting fails closed");
        settings.put("InventoryTransfer", 30d);
        environment.put("SandboxVars", "bad table");
        near((Float) scale.invoke(null, 1000f), 1000f, "Invalid sandbox table fails closed");
        environment.put("SandboxVars", sandbox);
        sandbox.put("ActionTimeReducer", 30d);
        near((Float) scale.invoke(null, 1000f), 1000f, "Invalid settings table fails closed");
        near((Float) scale.invoke(null, -1f), -1f, "Negative duration preserved");
        near((Float) scale.invoke(null, 0f), 0f, "Zero duration preserved");
        check(Float.isNaN((Float) scale.invoke(null, Float.NaN)), "NaN duration preserved");
        check((Float) scale.invoke(null, Float.POSITIVE_INFINITY) == Float.POSITIVE_INFINITY, "Infinity duration preserved");
    }

    @SuppressWarnings("unchecked") private static Map<Object,Object> makeTable(Class<?> table) throws Exception {
        return (Map<Object,Object>) table.getConstructor().newInstance();
    }
    private static void near(float actual, float expected, String message) {
        check(Math.abs(actual - expected) < .001f, message + ": " + actual + " vs " + expected);
    }
    private static void check(boolean condition, String message) {
        assertions++;
        if (!condition) throw new AssertionError(message);
    }

    /** Minimal in-memory game API stubs, never written into the production agent jar. */
    private static final class FixtureLoader extends ClassLoader {
        private FixtureLoader() { super(PatchAudit.class.getClassLoader()); }
        @Override protected Class<?> loadClass(String name, boolean resolve) throws ClassNotFoundException {
            if (!name.startsWith("actiontimereducer.server.TransferDuration") && !name.startsWith("zombie.") &&
                    !name.startsWith("se.krka.") && !name.equals("fixtures.Table")) return super.loadClass(name, resolve);
            Class<?> loaded = findLoadedClass(name);
            if (loaded == null) {
                try {
                    byte[] bytes;
                    if (name.startsWith("actiontimereducer.server.TransferDuration")) {
                        try (InputStream input = getParent().getResourceAsStream(name.replace('.', '/') + ".class")) {
                            bytes = input.readAllBytes();
                        }
                    } else bytes = fixture(name);
                    loaded = defineClass(name, bytes, 0, bytes.length);
                } catch (Exception failure) { throw new ClassNotFoundException(name, failure); }
            }
            if (resolve) resolveClass(loaded);
            return loaded;
        }
        private static byte[] fixture(String name) {
            String internal = name.replace('.', '/');
            ClassWriter writer = new ClassWriter(0);
            if (name.equals("se.krka.kahlua.vm.KahluaTable")) {
                writer.visit(Opcodes.V17, Opcodes.ACC_PUBLIC | Opcodes.ACC_INTERFACE | Opcodes.ACC_ABSTRACT,
                        internal, null, "java/lang/Object", null);
                writer.visitMethod(Opcodes.ACC_PUBLIC | Opcodes.ACC_ABSTRACT, "rawget",
                        "(Ljava/lang/Object;)Ljava/lang/Object;", null, null).visitEnd();
            } else if (name.equals("fixtures.Table")) {
                writer.visit(Opcodes.V17, Opcodes.ACC_PUBLIC, internal, null, "java/util/HashMap",
                        new String[]{"se/krka/kahlua/vm/KahluaTable"});
                MethodVisitor init = writer.visitMethod(Opcodes.ACC_PUBLIC, "<init>", "()V", null, null);
                init.visitCode(); init.visitVarInsn(Opcodes.ALOAD,0);
                init.visitMethodInsn(Opcodes.INVOKESPECIAL,"java/util/HashMap","<init>","()V",false);
                init.visitInsn(Opcodes.RETURN); init.visitMaxs(1,1); init.visitEnd();
                MethodVisitor get = writer.visitMethod(Opcodes.ACC_PUBLIC,"rawget","(Ljava/lang/Object;)Ljava/lang/Object;",null,null);
                get.visitCode(); get.visitVarInsn(Opcodes.ALOAD,0); get.visitVarInsn(Opcodes.ALOAD,1);
                get.visitMethodInsn(Opcodes.INVOKEVIRTUAL,"java/util/HashMap","get","(Ljava/lang/Object;)Ljava/lang/Object;",false);
                get.visitInsn(Opcodes.ARETURN); get.visitMaxs(2,2); get.visitEnd();
            } else {
                writer.visit(Opcodes.V17, Opcodes.ACC_PUBLIC,internal,null,"java/lang/Object",null);
                writer.visitField(Opcodes.ACC_PUBLIC | Opcodes.ACC_STATIC,
                        name.equals("zombie.network.GameServer") ? "server" : "env",
                        name.equals("zombie.network.GameServer") ? "Z" : "Lse/krka/kahlua/vm/KahluaTable;",null,null).visitEnd();
            }
            writer.visitEnd(); return writer.toByteArray();
        }
    }
}

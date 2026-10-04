package actiontimereducer.server;

import java.lang.constant.ClassDesc;
import java.lang.constant.MethodTypeDesc;
import java.lang.instrument.ClassFileTransformer;
import java.lang.reflect.Method;
import java.lang.reflect.Proxy;
import java.security.MessageDigest;
import java.security.ProtectionDomain;
import java.util.HexFormat;
import java.util.List;
import java.util.function.Predicate;

/** Fingerprint-pinned Java 25 standard Class-File API adapter, compiled without game dependencies. */
public final class TransactionTransformer implements ClassFileTransformer {
    private static final String TARGET = "zombie/core/Transaction";
    private final String expectedSha256;

    public TransactionTransformer(String expectedSha256) {
        if (expectedSha256 == null || !expectedSha256.matches("[0-9a-fA-F]{64}")) {
            throw new IllegalArgumentException("Expected a SHA-256 fingerprint for Transaction.class.");
        }
        this.expectedSha256 = expectedSha256;
    }

    @Override
    public byte[] transform(ClassLoader loader, String className, Class<?> redefined,
                            ProtectionDomain domain, byte[] original) {
        if (!TARGET.equals(className)) return null;
        try {
            byte[] transformed = transformBytes(original);
            System.setProperty("actiontimereducer.inventoryHook.active", "true");
            System.err.println("[ActionTimeReducer] Supported server inventory duration hook installed.");
            return transformed;
        } catch (Exception | LinkageError failure) {
            System.err.println("[ActionTimeReducer] Inventory hook DISABLED; vanilla durations retained: " + failure);
            return null;
        }
    }

    /** Offline audit seam. Unknown bytes are rejected before parsing or modification. */
    public byte[] transformBytes(byte[] original) throws Exception {
        String actual = HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(original));
        if (!expectedSha256.equalsIgnoreCase(actual)) {
            throw new IllegalArgumentException("Unsupported Transaction.class SHA-256: " + actual);
        }
        Class<?> classFile = Class.forName("java.lang.classfile.ClassFile");
        Class<?> classModel = Class.forName("java.lang.classfile.ClassModel");
        Class<?> methodModel = Class.forName("java.lang.classfile.MethodModel");
        Class<?> classEntry = Class.forName("java.lang.classfile.constantpool.ClassEntry");
        Class<?> utf8 = Class.forName("java.lang.classfile.constantpool.Utf8Entry");
        Class<?> accessFlags = Class.forName("java.lang.classfile.AccessFlags");
        Class<?> classTransform = Class.forName("java.lang.classfile.ClassTransform");
        Class<?> codeTransform = Class.forName("java.lang.classfile.CodeTransform");
        Class<?> codeBuilder = Class.forName("java.lang.classfile.CodeBuilder");
        Class<?> classFileBuilder = Class.forName("java.lang.classfile.ClassFileBuilder");
        Class<?> element = Class.forName("java.lang.classfile.ClassFileElement");
        Class<?> instruction = Class.forName("java.lang.classfile.Instruction");
        Object api = classFile.getMethod("of").invoke(null);
        Object model = classFile.getMethod("parse", byte[].class).invoke(api, (Object) original);
        Object identity = classModel.getMethod("thisClass").invoke(model);
        if (!TARGET.equals(classEntry.getMethod("asInternalName").invoke(identity))) {
            throw new IllegalArgumentException("Fingerprint resource must identify zombie/core/Transaction.");
        }
        Method methodName = methodModel.getMethod("methodName");
        Method methodType = methodModel.getMethod("methodType");
        Method stringValue = utf8.getMethod("stringValue");
        Predicate<Object> selected = method -> {
            try {
                return "getDuration".equals(stringValue.invoke(methodName.invoke(method))) &&
                        "()F".equals(stringValue.invoke(methodType.invoke(method)));
            } catch (ReflectiveOperationException failure) {
                throw new IllegalStateException("Cannot inspect method contract.", failure);
            }
        };
        List<?> methods = (List<?>) classModel.getMethod("methods").invoke(model);
        int matches = 0;
        for (Object method : methods) {
            if (!selected.test(method)) continue;
            matches++;
            Object flags = methodModel.getMethod("flags").invoke(method);
            int mask = (int) accessFlags.getMethod("flagsMask").invoke(flags);
            if ((mask & (0x0008 | 0x0400 | 0x0100)) != 0) {
                throw new IllegalArgumentException("Unsupported getDuration method access.");
            }
        }
        if (matches != 1) throw new IllegalArgumentException("Expected exactly one getDuration()F.");
        Method opcode = instruction.getMethod("opcode");
        Method addCall = codeBuilder.getMethod("invokestatic", ClassDesc.class, String.class, MethodTypeDesc.class);
        Method preserve = classFileBuilder.getMethod("with", element);
        int[] returns = {0};
        Object code = Proxy.newProxyInstance(TransactionTransformer.class.getClassLoader(),
                new Class<?>[]{codeTransform}, (proxy, method, args) -> {
                    if (method.getName().equals("accept")) {
                        Object builder = args[0];
                        Object next = args[1];
                        if (instruction.isInstance(next) && "FRETURN".equals(opcode.invoke(next).toString())) {
                            returns[0]++;
                            addCall.invoke(builder, ClassDesc.of("actiontimereducer.server.TransferDuration"),
                                    "scale", MethodTypeDesc.ofDescriptor("(F)F"));
                        }
                        preserve.invoke(builder, next);
                        return null;
                    }
                    if (method.getName().equals("toString")) return "ActionTimeReducer inventory duration transform";
                    if (method.getName().equals("hashCode")) return System.identityHashCode(proxy);
                    if (method.getName().equals("equals")) return proxy == args[0];
                    if (method.getName().equals("atStart") || method.getName().equals("atEnd")) return null;
                    throw new UnsupportedOperationException(method.toString());
                });
        Object transform = classTransform.getMethod("transformingMethodBodies", Predicate.class, codeTransform)
                .invoke(null, selected, code);
        byte[] result = (byte[]) classFile.getMethod("transformClass", classModel, classTransform)
                .invoke(api, model, transform);
        if (returns[0] != 1) throw new IllegalArgumentException("Expected one getDuration float return.");
        return result;
    }
}

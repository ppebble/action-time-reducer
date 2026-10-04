package actiontimereducer.server;

/** Run in a fresh JVM with -javaagent and the installed game's jar. */
public final class AgentLoadSmoke {
    public static void main(String[] args) throws Exception {
        Class<?> transaction = Class.forName("zombie.core.Transaction", false,
                AgentLoadSmoke.class.getClassLoader());
        if (!transaction.getName().equals("zombie.core.Transaction")) throw new AssertionError("Wrong class");
        if (!Boolean.getBoolean("actiontimereducer.inventoryHook.active")) {
            throw new AssertionError("Production agent did not successfully transform Transaction");
        }
        System.out.println("PASS actual JVM agent load of installed Transaction.class without game initialization");
        System.out.println("LIMITATION: verifies agent/class loading only; no gameplay, server startup or network clients.");
    }
}

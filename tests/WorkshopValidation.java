/** Runs the installed game's upload validation without creating or submitting an item. */
public final class WorkshopValidation {
    public static void main(String[] args) throws Exception {
        Class<?> filesystem = Class.forName("zombie.ZomboidFileSystem");
        filesystem.getMethod("init").invoke(filesystem.getField("instance").get(null));
        Class<?> type = Class.forName("zombie.core.znet.SteamWorkshopItem");
        Object item = type.getConstructor(String.class).newInstance(args[0]);
        if (!Boolean.TRUE.equals(type.getMethod("readWorkshopTxt").invoke(item)))
            throw new AssertionError("Cannot read Workshop metadata");
        Object error = type.getMethod("validateContents").invoke(item);
        if (args.length == 2 && args[1].equals("--inspect")) {
            System.out.println("Native Workshop validation: " + error);
            return;
        }
        if (error != null) throw new AssertionError("Native Workshop validation failed: " + error);
        System.out.println("PASS installed B42.21 Workshop content and preview validation; no upload performed");
    }
}

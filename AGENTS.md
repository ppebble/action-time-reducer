# Action Time Reducer

- Independent B42.21 Lua mod. Keep changes inside this repository.
- Upstream game and Workshop files are read-only. User-authorized exception: distribute the version-pinned modified Transaction.class for manual server installation, together with its own helper classes; do not redistribute other upstream files.
- Preserve original completion, cancellation, material, XP and server authority paths.
- Only exact allowlisted action classes may be accelerated. Unknown actions fail closed.
- Do not wrap concrete action constructors: the network inspects their Lua parameter names. The shared base allocator hook is permitted.
- Only the user-authorized Transaction.class override may replace a Java class at load time. Do not add other Java replacements, global time acceleration, weight/trait tricks or forced completion.
- Separate Kahlua unit tests, local install hashes, and live two-client dedicated-server proof.
- Do not publish or activate on a live server without explicit authorization.

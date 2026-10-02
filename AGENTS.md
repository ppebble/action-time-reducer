# Safe Action Time

- Independent B42.21 Lua mod. Keep changes inside this repository.
- Upstream game and Workshop files are read-only; do not redistribute them.
- Preserve original completion, cancellation, material, XP and server authority paths.
- Only exact allowlisted action classes may be accelerated. Unknown actions fail closed.
- Do not wrap concrete action constructors: the network inspects their Lua parameter names. The shared base allocator hook is permitted.
- Do not add Java replacements, global time acceleration, weight/trait tricks or forced completion.
- Separate Kahlua unit tests, local install hashes, and live two-client dedicated-server proof.
- Do not publish or activate on a live server without explicit authorization.

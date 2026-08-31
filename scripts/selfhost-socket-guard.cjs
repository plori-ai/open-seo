// Keeps the self-host server alive when a peer resets a socket mid-response.
//
// `vite preview` serves the self-host container, and parts of that stack pipe a
// stream to the response socket without attaching an 'error' handler. When a
// client goes away while a large body is still being written, Node's default
// behaviour for the resulting unhandled 'error' event is to throw, which takes
// the whole process down and makes every route unavailable until the container
// restarts. Resets are normal on a network — a server has to tolerate them.
//
// Loaded via NODE_OPTIONS=--require from docker-entrypoint.sh, so the CLI
// invocation stays exactly as upstream ships it.

const SUPPRESSED_CODES = new Set(["ECONNRESET", "EPIPE", "ECONNABORTED"]);
const SUPPRESSED_SYSCALLS = new Set(["read", "write"]);

const isSocketReset = (error) =>
  Boolean(error) &&
  SUPPRESSED_CODES.has(error.code) &&
  SUPPRESSED_SYSCALLS.has(error.syscall);

process.on("uncaughtException", (error) => {
  if (isSocketReset(error)) {
    // The stack rides along because which pipe leaves its socket unguarded is
    // still unidentified — that is the fix this guard is standing in for. Once
    // the producer is known and repaired upstream, drop to the summary line.
    console.warn(
      `[socket-guard] suppressed ${error.code} (${error.syscall}) — a peer reset the connection`,
      error.stack,
    );
    return;
  }

  // Everything else keeps crashing the process exactly as it did before this
  // guard existed. Narrowing to socket resets is the point; a broad
  // uncaughtException handler would hide real faults behind a running server.
  console.error(error);
  process.exit(1);
});

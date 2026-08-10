namespace Vamposer {
    public class CommandRunner : Object {
        public virtual void run (string[] argv, string label) throws Error {
            run_stdout (argv, label);
        }

        public virtual string run_stdout (string[] argv, string label) throws Error {
            string? std_out;
            string? std_err;
            int status = 0;

            try {
                Process.spawn_sync (null, argv, null, SpawnFlags.SEARCH_PATH, null, out std_out, out std_err, out status);
            } catch (SpawnError e) {
                throw new IOError.FAILED ("Unable to execute command '%s': %s".printf (label, e.message));
            }

            if (status != 0) {
                var err = std_err != null ? std_err.strip () : "";
                if (err == "") {
                    err = "command returned a non-zero exit code";
                }

                throw new IOError.FAILED ("%s failed: %s".printf (label, err));
            }

            return std_out != null ? std_out.strip () : "";
        }

        public virtual bool command_exists (string name) {
            string? std_out;
            string? std_err;
            int status = 0;

            try {
#if WINDOWS
                Process.spawn_sync (null, new string[] {"cmd", "/c", "where", name}, null, SpawnFlags.SEARCH_PATH, null, out std_out, out std_err, out status);
#else
                Process.spawn_sync (null, new string[] {"which", name}, null, SpawnFlags.SEARCH_PATH, null, out std_out, out std_err, out status);
#endif
            } catch (SpawnError e) {
                return false;
            }

            return status == 0;
        }
    }
}

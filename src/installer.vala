using Gee;
using Vamposer.InstallerOperations;

namespace Vamposer {
    public class ResolvedDependency : Object {
        public string source_id { get; construct; }
        public string revision { get; construct; }
        public string repository_url { get; construct; }
        public string project_name { get; construct; }
        public string local_directory { get; construct; }

        public ResolvedDependency (string source_id, string revision, string repository_url, string project_name, string local_directory) {
            Object (
                source_id: source_id,
                revision: revision,
                repository_url: repository_url,
                project_name: project_name,
                local_directory: local_directory
            );
        }
    }

    public class Installer : Object {
        public static bool logs_enabled { get; set; default = true; }
        internal const string RELEASE_DOWNLOAD_BASE = "https://github.com/ValaTux/vamposer/releases/latest/download";
        internal CommandRunner command_runner;

        private InitOperation init_operation;
        private InstallOperation install_operation;
        private SelfUpgradeOperation self_upgrade_operation;
        private RequireOperation require_operation;
        private RemoveOperation remove_operation;
        private UpdateOperation update_operation;

        public Installer () {
            command_runner = new CommandRunner ();
            init_operation = new InitOperation ();
            install_operation = new InstallOperation ();
            self_upgrade_operation = new SelfUpgradeOperation ();
            require_operation = new RequireOperation ();
            remove_operation = new RemoveOperation ();
            update_operation = new UpdateOperation ();
        }

        protected void set_command_runner (CommandRunner runner) {
            command_runner = runner;
        }

        public void init_config (string config_path) throws Error {
            init_operation.execute (this, config_path);
        }

        public void install (string config_path, bool include_dev = false) throws Error {
            install_operation.execute (this, config_path, include_dev);
        }

        public void self_upgrade (string executable_name) throws Error {
            self_upgrade_operation.execute (this, executable_name);
        }

        public void require_dependency (string config_path, string source_id, string revision = "*", bool include_dev = false) throws Error {
            require_operation.execute (this, config_path, source_id, revision, include_dev);
        }

        public void remove_dependency (string config_path, string source_id, bool remove_dev = false) throws Error {
            remove_operation.execute (this, config_path, source_id, remove_dev);
        }

        public void update (string config_path, string? source_id = null, bool include_dev = false) throws Error {
            update_operation.execute (this, config_path, source_id, include_dev);
        }

        internal void run_install (string config_path, string? only_source_id, bool force_reclone, bool include_dev) throws Error {
            log ("[Vamposer] Loading config %s\n", config_path);
            var config = PackageConfig.load (config_path);
            DependencyResolver.configure_alias_overrides (config.alias_sources, config.aliases);
            var project_dependencies = build_resolved_dependencies_for_map (config);
            var dev_dependencies = include_dev
                ? build_resolved_dependencies_for_map (config, true)
                : build_installed_resolved_dependencies_for_map (config, true);
            var all_dependencies = collect_all_dependencies (config, include_dev);

            ensure_subprojects_directory ();
            check_system_dependencies (config.system_dependencies);

            if (only_source_id != null && !all_dependencies.has_key (only_source_id)) {
                throw new IOError.NOT_FOUND ("Dependency not found: %s".printf (only_source_id));
            }

            var resolved_dependencies = new ArrayList<ResolvedDependency> ();
            foreach (var entry in all_dependencies.entries) {
                var resolved = DependencyResolver.resolve (entry.key, entry.value);
                var should_force = force_reclone && (only_source_id == null || only_source_id == entry.key);
                sync_dependency (resolved, should_force);
                write_wrap_file (resolved);
                resolved_dependencies.add (resolved);
            }

            write_vamposer_build (project_dependencies, dev_dependencies);
            log ("[Vamposer] Done. Git dependencies: %u\n", resolved_dependencies.size);
        }

        internal PackageConfig load_or_create_config (string config_path) throws Error {
            if (FileUtils.test (config_path, FileTest.EXISTS)) {
                return PackageConfig.load (config_path);
            }

            var config = PackageConfig.create_empty ();
            config.save (config_path);
            return config;
        }

        internal ArrayList<ResolvedDependency> build_resolved_dependencies_for_map (PackageConfig config, bool dev_dependencies = false) {
            DependencyResolver.configure_alias_overrides (config.alias_sources, config.aliases);
            var resolved_dependencies = new ArrayList<ResolvedDependency> ();
            var dependency_map = dev_dependencies ? config.dev_dependencies : config.dependencies;
            foreach (var entry in dependency_map.entries) {
                resolved_dependencies.add (DependencyResolver.resolve (entry.key, entry.value));
            }

            return resolved_dependencies;
        }

        internal ArrayList<ResolvedDependency> build_installed_resolved_dependencies_for_map (PackageConfig config, bool dev_dependencies = false) {
            var resolved_dependencies = build_resolved_dependencies_for_map (config, dev_dependencies);
            var installed_dependencies = new ArrayList<ResolvedDependency> ();
            foreach (var dependency in resolved_dependencies) {
                if (FileUtils.test (dependency.local_directory, FileTest.IS_DIR)) {
                    installed_dependencies.add (dependency);
                }
            }

            return installed_dependencies;
        }

        internal HashMap<string, string> collect_all_dependencies (PackageConfig config, bool include_dev) {
            var all_dependencies = new HashMap<string, string> ();

            foreach (var entry in config.dependencies.entries) {
                all_dependencies.set (entry.key, entry.value);
            }

            if (include_dev) {
                foreach (var entry in config.dev_dependencies.entries) {
                    if (!all_dependencies.has_key (entry.key)) {
                        all_dependencies.set (entry.key, entry.value);
                    }
                }
            }

            return all_dependencies;
        }

        internal string get_release_binary_name () {
#if WINDOWS
            return "vamposer.exe";
#else
            return "vamposer-linux";
#endif
        }

        internal string resolve_executable_path (string executable_name) throws Error {
            var trimmed = executable_name.strip ();
            if (trimmed == "") {
                throw new IOError.INVALID_ARGUMENT ("Executable name must not be empty");
            }

            if (trimmed.contains ("/") || Path.is_absolute (trimmed)) {
                return trimmed;
            }

            string resolved;
            try {
#if WINDOWS
                resolved = command_runner.run_stdout (new string[] {"where", trimmed}, "resolve executable path");
#else
                resolved = command_runner.run_stdout (new string[] {"which", trimmed}, "resolve executable path");
#endif
            } catch (Error e) {
                throw new IOError.NOT_FOUND ("Unable to locate executable in PATH: %s".printf (trimmed));
            }

            if (resolved == "") {
                throw new IOError.NOT_FOUND ("Unable to locate executable in PATH: %s".printf (trimmed));
            }

            return resolved.split ("\n")[0].strip ();
        }

#if WINDOWS
        internal void schedule_windows_replacement (string downloaded_path, string target_path, string temp_dir) throws Error {
            var script_path = Path.build_filename (temp_dir, "replace-vamposer.ps1");
            var quoted_downloaded = powershell_quote (downloaded_path);
            var quoted_target = powershell_quote (target_path);
            var quoted_temp_dir = powershell_quote (temp_dir);
            var script_contents = "Start-Sleep -Seconds 2\n"
                + "Copy-Item -Force '%s' '%s'\n".printf (quoted_downloaded, quoted_target)
                + "Remove-Item -Force '%s'\n".printf (quoted_downloaded)
                + "Remove-Item -Recurse -Force '%s'\n".printf (quoted_temp_dir);

            FileUtils.set_contents (script_path, script_contents);
            command_runner.run (
                new string[] {
                    "cmd",
                    "/c",
                    "start",
                    "",
                    "powershell",
                    "-NoProfile",
                    "-ExecutionPolicy",
                    "Bypass",
                    "-File",
                    script_path,
                },
                "schedule Windows self-upgrade"
            );
        }

        private string powershell_quote (string value) {
            return value.replace ("'", "''");
        }
#endif

        internal void ensure_subprojects_directory () throws Error {
            DirUtils.create_with_parents ("subprojects", 0755);

            var gitignore_path = Path.build_filename ("subprojects", ".gitignore");
            if (!FileUtils.test (gitignore_path, FileTest.EXISTS)) {
                var gitignore_contents = "/*\n!/.gitignore\n!/*.wrap\n!/vamposer.build\n!/vamposer\n";
                FileUtils.set_contents (gitignore_path, gitignore_contents);
                log ("[Vamposer] Generated file: %s\n", gitignore_path);
            }
        }

        private void check_system_dependencies (HashMap<string, string> system_dependencies) throws Error {
            if (system_dependencies.size == 0) {
                log ("[Vamposer] system_dependencies is empty, skipping checks\n");
                return;
            }

            log ("[Vamposer] Checking system dependencies\n");
            var missing = new ArrayList<string> ();
            var missing_dependencies = new HashMap<string, string> ();

            foreach (var entry in system_dependencies.entries) {
                var pkg_name = entry.key;
                var version_constraint = entry.value.strip ();
                var query = build_pkg_config_query (pkg_name, version_constraint);
                if (!check_pkg_config_exists (query)) {
                    missing.add (query);
                    missing_dependencies.set (pkg_name, version_constraint);
                }
            }

            if (missing.size > 0) {
                var system_dependency_installer = new SystemDependencyInstaller ();
                system_dependency_installer.logs_enabled = logs_enabled;
                system_dependency_installer.install_missing (missing_dependencies);

                missing.clear ();
                foreach (var entry in system_dependencies.entries) {
                    var query = build_pkg_config_query (entry.key, entry.value.strip ());
                    if (!check_pkg_config_exists (query)) {
                        missing.add (query);
                    }
                }
            }

            if (missing.size > 0) {
                var joined_builder = new StringBuilder ();
                foreach (var item in missing) {
                    if (joined_builder.len > 0) {
                        joined_builder.append ("\n");
                    }
                    joined_builder.append (item);
                }

                log (
                    "[Vamposer] Warning: unresolved system dependencies remain:\n%s\n[Vamposer] Continuing dependency download and file generation anyway.\n",
                    joined_builder.str
                );
                return;
            }

            log ("[Vamposer] System dependencies are satisfied\n");
        }

        private string build_pkg_config_query (string pkg_name, string version_constraint) {
            if (version_constraint == "" || version_constraint == "*") {
                return pkg_name;
            }
            return "%s %s".printf (pkg_name, version_constraint);
        }

        private bool check_pkg_config_exists (string query) throws Error {
            string? std_out;
            string? std_err;
            int status = 0;
            var argv = new string[] {"pkg-config", "--exists", query};

            try {
                Process.spawn_sync (null, argv, null, SpawnFlags.SEARCH_PATH, null, out std_out, out std_err, out status);
            } catch (SpawnError e) {
                throw new IOError.FAILED ("Unable to execute pkg-config: %s".printf (e.message));
            }

            return status == 0;
        }

        private void sync_dependency (ResolvedDependency dependency, bool force_reclone) throws Error {
            var directory_exists = FileUtils.test (dependency.local_directory, FileTest.IS_DIR);
            if (directory_exists && force_reclone) {
                remove_path_if_exists (dependency.local_directory);
                directory_exists = false;
            }

            if (directory_exists) {
                log ("[Vamposer] Skipping clone, directory already exists: %s\n", dependency.local_directory);
                return;
            }

            var cleaned_revision = dependency.revision.strip ();
            if (cleaned_revision != "" && cleaned_revision != "*") {
                var argv = new string[] {
                    "git",
                    "clone",
                    "--depth",
                    "1",
                    "--branch",
                    cleaned_revision,
                    dependency.repository_url,
                    dependency.local_directory,
                };

                command_runner.run (argv, "git clone for %s".printf (dependency.source_id));
            } else {
                var argv = new string[] {
                    "git",
                    "clone",
                    "--depth",
                    "1",
                    dependency.repository_url,
                    dependency.local_directory,
                };

                command_runner.run (argv, "git clone for %s".printf (dependency.source_id));
            }

            log ("[Vamposer] Downloaded %s -> %s\n", dependency.source_id, dependency.local_directory);
        }

        internal void remove_path_if_exists (string path) throws Error {
            if (!FileUtils.test (path, FileTest.EXISTS)) {
                return;
            }

            if (FileUtils.test (path, FileTest.IS_DIR)) {
                command_runner.run (new string[] {"rm", "-rf", path}, "remove directory");
            } else {
                FileUtils.remove (path);
            }
        }

        internal string read_checksum_value (string checksum_path) throws Error {
            string contents;
            try {
                FileUtils.get_contents (checksum_path, out contents);
            } catch (FileError e) {
                throw new IOError.FAILED ("Unable to read checksum file: %s".printf (e.message));
            }

            foreach (var line in contents.split ("\n")) {
                var trimmed = line.strip ();
                if (trimmed == "") {
                    continue;
                }

                foreach (var field in trimmed.split (" ")) {
                    var token = field.strip ();
                    if (token != "") {
                        return token;
                    }
                }
            }

            throw new IOError.FAILED ("Checksum file is empty or invalid");
        }

        internal string calculate_sha256 (string file_path) throws Error {
#if WINDOWS
            var output = command_runner.run_stdout (
                new string[] {
                    "powershell",
                    "-NoProfile",
                    "-Command",
                    "(Get-FileHash -Algorithm SHA256 -LiteralPath '%s').Hash".printf (powershell_quote (file_path)),
                },
                "calculate sha256 checksum"
            );
            return output.down ();
#else
            var output = command_runner.run_stdout (new string[] {"sha256sum", file_path}, "calculate sha256 checksum");
            foreach (var field in output.split (" ")) {
                var token = field.strip ();
                if (token != "") {
                    return token;
                }
            }

            throw new IOError.FAILED ("Unable to parse sha256sum output");
#endif
        }

        private void write_wrap_file (ResolvedDependency dependency) throws Error {
            var wrap_path = Path.build_filename ("subprojects", "%s.wrap".printf (dependency.project_name));
            string provide_name;
            string dep_symbol;
            detect_provide_binding (dependency, out provide_name, out dep_symbol);

            if (has_wrap_for_directory (dependency.project_name, wrap_path)) {
                log (
                    "[Vamposer] Skipping wrap generation for %s, an existing wrap already targets directory '%s'\n",
                    dependency.project_name,
                    dependency.project_name
                );
                return;
            }

            if (has_wrap_for_provide_name (provide_name, wrap_path)) {
                if (FileUtils.test (wrap_path, FileTest.EXISTS)) {
                    remove_path_if_exists (wrap_path);
                    log ("[Vamposer] Removed conflicting wrap file: %s\n", wrap_path);
                }

                log (
                    "[Vamposer] Skipping wrap generation for %s, an existing wrap already provides '%s'\n",
                    dependency.project_name,
                    provide_name
                );
                return;
            }

            var wrap_contents = """
[wrap-file]
directory = %s

[provide]
%s = %s
""".printf (dependency.project_name, provide_name, dep_symbol);

            FileUtils.set_contents (wrap_path, wrap_contents);
            log ("[Vamposer] Generated wrap file: %s\n", wrap_path);
        }

        private bool has_wrap_for_directory (string directory_name, string current_wrap_path) {
            Dir? subprojects_dir = null;
            try {
                subprojects_dir = Dir.open ("subprojects");
            } catch (FileError e) {
                return false;
            }

            string? entry_name;
            while ((entry_name = subprojects_dir.read_name ()) != null) {
                if (!entry_name.has_suffix (".wrap")) {
                    continue;
                }

                var candidate_path = Path.build_filename ("subprojects", entry_name);
                if (candidate_path == current_wrap_path) {
                    continue;
                }

                string contents;
                try {
                    FileUtils.get_contents (candidate_path, out contents);
                } catch (FileError e) {
                    continue;
                }

                foreach (var line in contents.split ("\n")) {
                    var trimmed = line.strip ();
                    if (trimmed.has_prefix ("directory")) {
                        var parts = trimmed.split ("=");
                        if (parts.length >= 2 && parts[1].strip () == directory_name) {
                            return true;
                        }
                    }
                }
            }

            return false;
        }

        private bool has_wrap_for_provide_name (string provide_name, string current_wrap_path) {
            if (provide_name.strip () == "") {
                return false;
            }

            Dir? subprojects_dir = null;
            try {
                subprojects_dir = Dir.open ("subprojects");
            } catch (FileError e) {
                return false;
            }

            string? entry_name;
            while ((entry_name = subprojects_dir.read_name ()) != null) {
                if (!entry_name.has_suffix (".wrap")) {
                    continue;
                }

                var candidate_path = Path.build_filename ("subprojects", entry_name);
                if (candidate_path == current_wrap_path) {
                    continue;
                }

                if (wrap_provides_name (candidate_path, provide_name)) {
                    return true;
                }
            }

            return false;
        }

        private bool wrap_provides_name (string wrap_path, string provide_name) {
            string contents;
            try {
                FileUtils.get_contents (wrap_path, out contents);
            } catch (FileError e) {
                return false;
            }

            foreach (var line in contents.split ("\n")) {
                var trimmed = line.strip ();
                if (!trimmed.has_prefix ("filename")) {
                    continue;
                }

                var parts = trimmed.split ("=");
                if (parts.length < 2) {
                    continue;
                }

                var redirect_rel = parts[1].strip ();
                if (redirect_rel == "") {
                    continue;
                }

                var redirected_wrap_path = Path.build_filename ("subprojects", redirect_rel);
                if (redirected_wrap_path != wrap_path && FileUtils.test (redirected_wrap_path, FileTest.EXISTS)) {
                    return wrap_provides_name (redirected_wrap_path, provide_name);
                }
            }

            var in_provide_section = false;
            foreach (var line in contents.split ("\n")) {
                var trimmed = line.strip ();
                if (trimmed == "") {
                    continue;
                }

                if (trimmed.has_prefix ("[") && trimmed.has_suffix ("]")) {
                    in_provide_section = (trimmed == "[provide]");
                    continue;
                }

                if (!in_provide_section || !trimmed.contains ("=")) {
                    continue;
                }

                var parts = trimmed.split ("=");
                if (parts.length < 2) {
                    continue;
                }

                var provided_key = parts[0].strip ();
                if (provided_key == provide_name) {
                    return true;
                }
            }

            return false;
        }

        internal void write_vamposer_build (ArrayList<ResolvedDependency> dependencies, ArrayList<ResolvedDependency>? dev_dependencies = null) throws Error {
            var builder = new StringBuilder ();
            var dev_dependency_list = dev_dependencies ?? new ArrayList<ResolvedDependency> ();
            var all_dependency_list = new ArrayList<ResolvedDependency> ();
            foreach (var dependency in dependencies) {
                all_dependency_list.add (dependency);
            }
            foreach (var dependency in dev_dependency_list) {
                all_dependency_list.add (dependency);
            }

            builder.append ("# THIS FILE IS AUTO-GENERATED BY VAMPOSER. DO NOT EDIT.\n");
            builder.append (build_vamposer_dependency_block ("vamposer_deps", dependencies));
            builder.append ("\n");
            builder.append (build_vamposer_dependency_block ("vamposer_dev_deps", dev_dependency_list));
            builder.append ("\n");
            builder.append (build_vamposer_dependency_block ("vamposer_all_deps", all_dependency_list));


            var root_helper_path = "vamposer.build";
            FileUtils.set_contents (root_helper_path, builder.str);
            log ("[Vamposer] Generated file: %s\n", root_helper_path);

            var helper_path = Path.build_filename ("subprojects", "vamposer.build");
            FileUtils.set_contents (helper_path, builder.str);
            log ("[Vamposer] Generated file: %s\n", helper_path);

            var root_vamposer_dir = "vamposer";
            DirUtils.create_with_parents (root_vamposer_dir, 0755);

            var root_meson_path = Path.build_filename (root_vamposer_dir, "meson.build");
            var root_meson_builder = new StringBuilder ();
            root_meson_builder.append ("# This file is generated by Vamposer.\n");
            root_meson_builder.append ("# It exposes `vamposer_deps`, `vamposer_dev_deps`, and `vamposer_all_deps` for `subdir('vamposer')`.\n");
            root_meson_builder.append (builder.str);
            FileUtils.set_contents (root_meson_path, root_meson_builder.str);
            log ("[Vamposer] Generated file: %s\n", root_meson_path);

            var vamposer_subdir = Path.build_filename ("subprojects", "vamposer");
            DirUtils.create_with_parents (vamposer_subdir, 0755);

            var meson_path = Path.build_filename (vamposer_subdir, "meson.build");
            var meson_builder = new StringBuilder ();
            meson_builder.append ("# This file is generated by Vamposer.\n");
            meson_builder.append ("# It exposes `vamposer_deps`, `vamposer_dev_deps`, and `vamposer_all_deps` for `subdir('subprojects/vamposer')`.\n");
            meson_builder.append (builder.str);
            FileUtils.set_contents (meson_path, meson_builder.str);
            log ("[Vamposer] Generated file: %s\n", meson_path);
        }

        private string build_vamposer_dependency_block (string variable_name, ArrayList<ResolvedDependency> dependencies) {
            var builder = new StringBuilder ();
            builder.append ("%s = [\n".printf (variable_name));

            foreach (var dependency in dependencies) {
                string provide_name;
                string dep_symbol;
                detect_provide_binding (dependency, out provide_name, out dep_symbol);
                builder.append ("  dependency('%s', fallback: ['%s', '%s']),\n".printf (
                    provide_name,
                    dependency.project_name,
                    dep_symbol
                ));
            }

            builder.append ("]\n");

            return builder.str;
        }

        internal void log (string format, ...) {
            if (!logs_enabled) {
                return;
            }

            var args = va_list ();
            var line = format.vprintf (args);
            Logger.log_line (line);
        }

        private string sanitize_symbol (string name) {
            return name.replace ("-", "_").replace (".", "_");
        }

        private void detect_provide_binding (ResolvedDependency dependency, out string provide_name, out string dep_symbol) {
            provide_name = dependency.project_name;
            dep_symbol = "%s_dep".printf (sanitize_symbol (dependency.project_name));

            var meson_build_path = Path.build_filename (dependency.local_directory, "meson.build");
            if (!FileUtils.test (meson_build_path, FileTest.EXISTS)) {
                return;
            }

            string contents;
            try {
                FileUtils.get_contents (meson_build_path, out contents);
            } catch (Error e) {
                return;
            }

            foreach (var line in contents.split ("\n")) {
                var trimmed = line.strip ();
                if (!trimmed.contains ("meson.override_dependency")) {
                    continue;
                }

                var open_idx = trimmed.index_of_char ('(');
                var close_idx = trimmed.last_index_of_char (')');
                if (open_idx < 0 || close_idx <= open_idx) {
                    continue;
                }

                var args = trimmed.substring (open_idx + 1, close_idx - open_idx - 1);
                var comma_idx = args.index_of_char (',');
                if (comma_idx < 0) {
                    continue;
                }

                var name_part = args.substring (0, comma_idx).strip ();
                var symbol_part = args.substring (comma_idx + 1).strip ();

                var parsed_name = unquote_string_literal (name_part);
                if (parsed_name == "") {
                    continue;
                }

                if (symbol_part.contains ("#")) {
                    symbol_part = symbol_part.split ("#")[0].strip ();
                }

                if (symbol_part == "") {
                    continue;
                }

                provide_name = parsed_name;
                dep_symbol = symbol_part;
                return;
            }
        }

        private string unquote_string_literal (string value) {
            var trimmed = value.strip ();
            if (trimmed.length < 2) {
                return "";
            }

            if ((trimmed[0] == '\'' && trimmed[trimmed.length - 1] == '\'')
                || (trimmed[0] == '"' && trimmed[trimmed.length - 1] == '"')) {
                return trimmed.substring (1, trimmed.length - 2).strip ();
            }

            return "";
        }
    }
}

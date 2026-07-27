using Gee;

namespace Vamposer {
    public class DependencyResolver : Object {
        private const string REMOTE_ALIAS_URL = "https://raw.githubusercontent.com/ValaTux/vamposer/master/vamposer.aliases.json";
        private static HashMap<string, string>? cached_aliases = null;
        private static ArrayList<string>? configured_alias_sources = null;
        private static HashMap<string, string>? configured_aliases = null;

        public static ResolvedDependency resolve (string source_id, string revision) {
            var canonical_source_id = canonicalize_source_id (source_id);
            var repository_url = normalize_repository_url (canonical_source_id);
            var project_name = extract_project_name (canonical_source_id);
            var local_directory = Path.build_filename ("subprojects", project_name);

            return new ResolvedDependency (source_id, revision, repository_url, project_name, local_directory);
        }

        public static string canonicalize_source_id (string source_id) {
            var cleaned = source_id.strip ();
            var expanded = apply_alias (cleaned);

            if (expanded != cleaned) {
                // Alias target is authoritative; do not rewrite it with GitHub fallback.
                return expanded;
            }

            return expand_hostless_repository_ref (cleaned);
        }

        public static string normalize_repository_url (string source_id) {
            var repository_url = canonicalize_source_id (source_id);

            if (repository_url.has_prefix ("git+https://")) {
                repository_url = "https://%s".printf (repository_url.substring (12));
            }

            if (!has_transport_prefix (repository_url)) {
                repository_url = "https://%s".printf (repository_url);
            }

            if (!repository_url.has_suffix (".git")) {
                repository_url += ".git";
            }

            return repository_url;
        }

        public static void configure_alias_overrides (ArrayList<string> alias_sources, HashMap<string, string> aliases) {
            ensure_alias_override_state ();
            configured_alias_sources = new ArrayList<string> ();
            foreach (var source in alias_sources) {
                var cleaned_source = source.strip ();
                if (cleaned_source != "") {
                    configured_alias_sources.add (cleaned_source);
                }
            }

            configured_aliases = new HashMap<string, string> ();
            foreach (var entry in aliases.entries) {
                var alias_key = entry.key.strip ();
                var alias_target = entry.value.strip ();
                if (alias_key != "" && alias_target != "") {
                    configured_aliases.set (alias_key, alias_target);
                }
            }

            cached_aliases = null;
        }

        public static string extract_project_name (string source_id) {
            var cleaned = source_id.strip ();
            if (cleaned.has_suffix ("/")) {
                cleaned = cleaned.substring (0, cleaned.length - 1);
            }

            var slash_idx = cleaned.last_index_of_char ('/');
            if (slash_idx >= 0 && slash_idx + 1 < cleaned.length) {
                cleaned = cleaned.substring (slash_idx + 1);
            }

            if (cleaned.has_suffix (".git")) {
                cleaned = cleaned.substring (0, cleaned.length - 4);
            }

            return cleaned;
        }

        private static bool has_transport_prefix (string value) {
            return value.has_prefix ("https://")
                || value.has_prefix ("http://")
                || value.has_prefix ("ssh://")
                || value.has_prefix ("git://")
                || value.has_prefix ("git+https://")
                || value.has_prefix ("git@");
        }

        private static string apply_alias (string source_id) {
            var cleaned = source_id.strip ();

            var aliases = get_aliases ();
            if (aliases.has_key (cleaned)) {
                var expanded = aliases.get (cleaned);
                if (expanded != null) {
                    return expanded;
                }
            }

            return cleaned;
        }

        private static string expand_hostless_repository_ref (string source_id) {
            var cleaned = source_id.strip ();
            if (cleaned == "" || has_transport_prefix (cleaned) || cleaned.contains ("://")) {
                return cleaned;
            }

            if (cleaned.has_prefix ("github.com/") || cleaned.has_prefix ("gitlab.com/") || cleaned.has_prefix ("bitbucket.org/")) {
                return cleaned;
            }

            var parts = cleaned.split ("/");
            if (parts.length == 2 && parts[0].strip () != "" && parts[1].strip () != "" && !parts[0].contains (".")) {
                return "github.com/%s".printf (cleaned);
            }

            return cleaned;
        }

        private static HashMap<string, string> get_aliases () {
            ensure_alias_override_state ();

            if (cached_aliases != null) {
                return cached_aliases;
            }

            var aliases = new HashMap<string, string> ();

            try {
                merge_aliases_from_url (REMOTE_ALIAS_URL, aliases);
            } catch (Error e) {
                // Best-effort load: remote alias source is optional.
            }

            foreach (var source in configured_alias_sources) {
                try {
                    merge_aliases_from_url (source, aliases);
                } catch (Error e) {
                    // Best-effort load: invalid or unreachable configured source should not block install.
                }
            }

            foreach (var entry in configured_aliases.entries) {
                aliases.set (entry.key, entry.value);
            }

            cached_aliases = aliases;
            return aliases;
        }

        private static void ensure_alias_override_state () {
            if (configured_alias_sources == null) {
                configured_alias_sources = new ArrayList<string> ();
            }

            if (configured_aliases == null) {
                configured_aliases = new HashMap<string, string> ();
            }
        }

        private static void merge_aliases_from_url (string alias_url, HashMap<string, string> aliases) throws Error {
            string? std_out;
            string? std_err;
            int status = 0;

            var argv = new string[] {
                "curl",
                "-fsSL",
                "--connect-timeout",
                "2",
                "--max-time",
                "5",
                alias_url,
            };

            try {
                Process.spawn_sync (null, argv, null, SpawnFlags.SEARCH_PATH, null, out std_out, out std_err, out status);
            } catch (SpawnError e) {
                throw new IOError.FAILED ("Unable to execute curl: %s".printf (e.message));
            }

            if (status != 0 || std_out == null || std_out.strip () == "") {
                throw new IOError.FAILED ("Unable to download alias file from %s".printf (alias_url));
            }

            merge_aliases_from_json (std_out, aliases);
        }

        private static void merge_aliases_from_json (string json_data, HashMap<string, string> aliases) throws Error {
            var parser = new Json.Parser ();
            parser.load_from_data (json_data, json_data.length);

            var root = parser.get_root ();
            if (root == null || root.get_node_type () != Json.NodeType.OBJECT) {
                throw new FileError.INVAL ("Alias data must contain a JSON object");
            }

            var root_object = root.get_object ();
            Json.Object alias_object;

            if (root_object.has_member ("aliases")) {
                var aliases_node = root_object.get_member ("aliases");
                if (aliases_node == null || aliases_node.get_node_type () != Json.NodeType.OBJECT) {
                    throw new FileError.INVAL ("Field 'aliases' must be a JSON object");
                }

                alias_object = root_object.get_object_member ("aliases");
            } else {
                alias_object = root_object;
            }

            foreach (var key in alias_object.get_members ()) {
                var value_node = alias_object.get_member (key);
                if (value_node == null || value_node.get_node_type () != Json.NodeType.VALUE || !value_node.get_value ().holds (typeof (string))) {
                    continue;
                }

                var alias_key = key.strip ();
                var alias_target = alias_object.get_string_member (key).strip ();
                if (alias_key != "" && alias_target != "") {
                    aliases.set (alias_key, alias_target);
                }
            }
        }
    }
}

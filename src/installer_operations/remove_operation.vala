namespace Vamposer.InstallerOperations {
    public class RemoveOperation : Object {
        public void execute (Installer installer, string config_path, string source_id, bool remove_dev = false) throws Error {
            installer.ensure_subprojects_directory ();

            var config = PackageConfig.load (config_path);
            string? revision = null;
            if (remove_dev) {
                if (config.dev_dependencies.has_key (source_id)) {
                    revision = config.dev_dependencies.get (source_id);
                    config.dev_dependencies.unset (source_id);
                }
            } else {
                if (config.dependencies.has_key (source_id)) {
                    revision = config.dependencies.get (source_id);
                    config.dependencies.unset (source_id);
                }
            }

            if (revision == null) {
                throw new IOError.NOT_FOUND ("Dependency not found: %s".printf (source_id));
            }

            var resolved = DependencyResolver.resolve (source_id, revision);
            config.save (config_path);

            installer.remove_path_if_exists (Path.build_filename ("subprojects", "%s.wrap".printf (resolved.project_name)));
            installer.remove_path_if_exists (resolved.local_directory);

            installer.write_vamposer_build (
                installer.build_resolved_dependencies_for_map (config),
                remove_dev ? installer.build_resolved_dependencies_for_map (config, true) : new Gee.ArrayList<ResolvedDependency> ()
            );
            installer.log ("[Vamposer] Removed dependency: %s\n", source_id);
        }
    }
}

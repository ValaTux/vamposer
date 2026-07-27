namespace AppTests {
    using Gee;
    using ValaTux.Testcases;
    using Vamposer;
    using Vamposer.PackageManagers;

    public class SystemDependencyInstallerTest : BaseTest {
        construct {
            add_test ("rpm_candidates_prefer_pkgconfig_provider_with_version", test_rpm_candidates_prefer_pkgconfig_provider_with_version);
            add_test ("apt_candidates_include_glib_dev_and_aliases", test_apt_candidates_include_glib_dev_and_aliases);
            add_test ("build_install_command_uses_manager_specific_flags", test_build_install_command_uses_manager_specific_flags);
            add_test ("flatpak_and_windows_build_install_commands", test_flatpak_and_windows_build_install_commands);
            add_test ("package_manager_alias_list_includes_mapped_and_pkgconfig_names", test_package_manager_alias_list_includes_mapped_and_pkgconfig_names);
            add_test ("package_manager_alias_list_includes_generic_fallback_variants", test_package_manager_alias_list_includes_generic_fallback_variants);
            add_test ("dnf_fallback_prefers_devel_before_dev", test_dnf_fallback_prefers_devel_before_dev);
        }

        public void test_rpm_candidates_prefer_pkgconfig_provider_with_version () {
            var installer = new SystemDependencyInstaller ();
            var candidates = installer.get_system_package_candidates ("libadwaita-1", ">=1.6", "dnf");

            assert (candidates.size > 0);
            assert (candidates[0] == "pkgconfig(libadwaita-1) >=1.6");
            assert (candidates.contains ("libadwaita-devel"));
            assert (candidates.contains ("libadwaita-1"));
        }

        public void test_apt_candidates_include_glib_dev_and_aliases () {
            var installer = new SystemDependencyInstaller ();
            var candidates = installer.get_system_package_candidates ("glib-2.0", "*", "apt-get");

            assert (candidates.size > 0);
            assert (candidates[0] == "libglib2.0-dev");
            assert (candidates.contains ("glib-2.0"));
            assert (candidates.contains ("glib2"));
        }

        public void test_build_install_command_uses_manager_specific_flags () {
            var installer = new SystemDependencyInstaller ();

            var apt_command = installer.build_install_command ("apt-get", "libglib2.0-dev");
            assert (apt_command != null);
            assert (apt_command[0] == "apt-get");
            assert (apt_command[1] == "install");
            assert (apt_command[2] == "-y");
            assert (apt_command[3] == "libglib2.0-dev");

            var pacman_command = installer.build_install_command ("pacman", "glib2");
            assert (pacman_command != null);
            assert (pacman_command[0] == "pacman");
            assert (pacman_command[1] == "-S");
            assert (pacman_command[2] == "--needed");
            assert (pacman_command[3] == "--noconfirm");
            assert (pacman_command[4] == "glib2");
        }

        public void test_flatpak_and_windows_build_install_commands () {
            var installer = new SystemDependencyInstaller ();

            var flatpak_command = installer.build_install_command ("flatpak", "org.gnome.Sdk");
            assert (flatpak_command != null);
            assert (flatpak_command[0] == "flatpak");
            assert (flatpak_command[1] == "install");
            assert (flatpak_command[2] == "-y");
            assert (flatpak_command[3] == "flathub");
            assert (flatpak_command[4] == "org.gnome.Sdk");

            var windows_command = installer.build_install_command ("winget", "GtkRuntime.Gtk4");
            assert (windows_command != null);
            assert (windows_command[0] == "winget");
            assert (windows_command[1] == "install");
            assert (windows_command[2] == "--silent");
            assert (windows_command[3] == "--accept-source-agreements");
            assert (windows_command[4] == "--accept-package-agreements");
            assert (windows_command[5] == "GtkRuntime.Gtk4");
        }

        public void test_package_manager_alias_list_includes_mapped_and_pkgconfig_names () {
            var apt_manager = new AptPackageManager ();
            var aliases = apt_manager.get_aliases ("glib-2.0");

            assert (aliases.size > 0);
            assert (aliases[0] == "libglib2.0-dev");
            assert (aliases.contains ("glib-2.0"));
            assert (aliases.contains ("glib2"));
        }

        public void test_package_manager_alias_list_includes_generic_fallback_variants () {
            var apt_manager = new AptPackageManager ();
            var aliases = apt_manager.get_aliases ("libsoup-3.0");

            assert (aliases.size > 0);
            assert (aliases.contains ("libsoup-3.0"));
            assert (aliases.contains ("libsoup-3.0-dev"));
            assert (aliases.contains ("libsoup-3.0-devel"));
            assert (aliases.contains ("libsoup"));
            assert (aliases.contains ("libsoup-dev"));
            assert (aliases.contains ("libsoup-devel"));
        }

        public void test_dnf_fallback_prefers_devel_before_dev () {
            var dnf_manager = new DnfPackageManager ();
            var aliases = dnf_manager.get_aliases ("libsoup-3.0");

            var devel_index = aliases.index_of ("libsoup-devel");
            var dev_index = aliases.index_of ("libsoup-dev");

            assert (devel_index >= 0);
            assert (dev_index >= 0);
            assert (devel_index < dev_index);
        }
    }
}

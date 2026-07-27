namespace AppTests {
    using GLib;
    using ValaTux.Testcases;
    using Vamposer;

    public class InstallerErrorTest : BaseTest {
        construct {
            add_test ("init_fails_when_config_exists", test_init_fails_when_config_exists);
            add_test ("install_fails_when_config_is_missing", test_install_fails_when_config_is_missing);
            add_test ("update_fails_when_config_is_missing", test_update_fails_when_config_is_missing);
            add_test ("remove_fails_when_dependency_is_missing", test_remove_fails_when_dependency_is_missing);
            add_test ("update_named_dependency_ignores_dev_scope_without_flag", test_update_named_dependency_ignores_dev_scope_without_flag);
        }

        public void test_init_fails_when_config_exists () {
            var old_cwd = Environment.get_current_dir ();
            string project_dir;
            try {
                project_dir = DirUtils.make_tmp ("vamposer-test-XXXXXX");
            } catch (Error e) {
                assert_not_reached ();
            }

            Environment.set_current_dir (project_dir);
            try {
                var config_path = Path.build_filename (project_dir, "vamposer.json");
                try {
                    FileUtils.set_contents (config_path, "{}\n");
                } catch (Error e) {
                    assert_not_reached ();
                }

                var failed = false;
                try {
                    Installer.logs_enabled = false;
                    var installer = new Installer ();
                    installer.init_config (config_path);
                } catch (Error e) {
                    failed = true;
                    assert (e.message.contains ("Config file already exists"));
                } finally {
                    Installer.logs_enabled = true;
                }

                assert (failed);
            } finally {
                Environment.set_current_dir (old_cwd);
            }
        }

        public void test_install_fails_when_config_is_missing () {
            var old_cwd = Environment.get_current_dir ();
            string project_dir;
            try {
                project_dir = DirUtils.make_tmp ("vamposer-test-XXXXXX");
            } catch (Error e) {
                assert_not_reached ();
            }

            Environment.set_current_dir (project_dir);
            try {
                var missing_config_path = Path.build_filename (project_dir, "missing.json");

                var failed = false;
                try {
                    Installer.logs_enabled = false;
                    var installer = new Installer ();
                    installer.install (missing_config_path);
                } catch (Error e) {
                    failed = true;
                    assert (e.message.contains ("Config file not found"));
                } finally {
                    Installer.logs_enabled = true;
                }

                assert (failed);
            } finally {
                Environment.set_current_dir (old_cwd);
            }
        }

        public void test_update_fails_when_config_is_missing () {
            var old_cwd = Environment.get_current_dir ();
            string project_dir;
            try {
                project_dir = DirUtils.make_tmp ("vamposer-test-XXXXXX");
            } catch (Error e) {
                assert_not_reached ();
            }

            Environment.set_current_dir (project_dir);
            try {
                var missing_config_path = Path.build_filename (project_dir, "missing.json");

                var failed = false;
                try {
                    Installer.logs_enabled = false;
                    var installer = new Installer ();
                    installer.update (missing_config_path);
                } catch (Error e) {
                    failed = true;
                    assert (e.message.contains ("Config file not found"));
                } finally {
                    Installer.logs_enabled = true;
                }

                assert (failed);
            } finally {
                Environment.set_current_dir (old_cwd);
            }
        }

        public void test_remove_fails_when_dependency_is_missing () {
            var old_cwd = Environment.get_current_dir ();
            string project_dir;
            try {
                project_dir = DirUtils.make_tmp ("vamposer-test-XXXXXX");
            } catch (Error e) {
                assert_not_reached ();
            }

            Environment.set_current_dir (project_dir);
            try {
                var config_path = Path.build_filename (project_dir, "vamposer.json");
                try {
                    FileUtils.set_contents (config_path, """
{
  "dependencies": {},
  "dependencies-dev": {},
  "system_dependencies": {
    "glib-2.0": "*"
  }
}
""");
                } catch (Error e) {
                    assert_not_reached ();
                }

                var failed = false;
                try {
                    Installer.logs_enabled = false;
                    var installer = new Installer ();
                    installer.remove_dependency (config_path, "github.com/ValaTux/testcases");
                } catch (Error e) {
                    failed = true;
                    assert (e.message.contains ("Dependency not found"));
                } finally {
                    Installer.logs_enabled = true;
                }

                assert (failed);
            } finally {
                Environment.set_current_dir (old_cwd);
            }
        }

        public void test_update_named_dependency_ignores_dev_scope_without_flag () {
            var old_cwd = Environment.get_current_dir ();
            string project_dir;
            try {
                project_dir = DirUtils.make_tmp ("vamposer-test-XXXXXX");
            } catch (Error e) {
                assert_not_reached ();
            }

            Environment.set_current_dir (project_dir);
            try {
                var config_path = Path.build_filename (project_dir, "vamposer.json");
                try {
                    FileUtils.set_contents (config_path, """
{
  "dependencies": {},
  "dependencies-dev": {
    "github.com/ValaTux/testcases": "master"
  },
  "system_dependencies": {
    "glib-2.0": "*"
  }
}
""");
                } catch (Error e) {
                    assert_not_reached ();
                }

                var failed = false;
                try {
                    Installer.logs_enabled = false;
                    var installer = new Installer ();
                    installer.update (config_path, "github.com/ValaTux/testcases", false);
                } catch (Error e) {
                    failed = true;
                    assert (e.message.contains ("Dependency not found"));
                } finally {
                    Installer.logs_enabled = true;
                }

                assert (failed);
            } finally {
                Environment.set_current_dir (old_cwd);
            }
        }
    }
}

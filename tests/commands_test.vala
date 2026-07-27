namespace AppTests {
    using GLib;
    using ValaTux.Testcases;
    using Vamposer;
    using Vamposer.Commands;

    public class CommandsTest : BaseTest {
        construct {
            add_test ("help_command_invokes_usage", test_help_command_invokes_usage);
            add_test ("completion_command_help_invokes_usage", test_completion_command_help_invokes_usage);
            add_test ("completion_command_rejects_unknown_action", test_completion_command_rejects_unknown_action);
            add_test ("init_command_help_invokes_usage", test_init_command_help_invokes_usage);
            add_test ("init_command_creates_custom_config", test_init_command_creates_custom_config);
            add_test ("install_command_help_invokes_usage", test_install_command_help_invokes_usage);
            add_test ("install_command_uses_custom_config", test_install_command_uses_custom_config);
            add_test ("install_command_uses_default_config_path", test_install_command_uses_default_config_path);
            add_test ("install_command_accepts_dev_flag", test_install_command_accepts_dev_flag);
            add_test ("install_command_rejects_unknown_option", test_install_command_rejects_unknown_option);
            add_test ("install_command_rejects_multiple_config_paths", test_install_command_rejects_multiple_config_paths);
            add_test ("version_command_succeeds_without_arguments", test_version_command_succeeds_without_arguments);
            add_test ("version_command_rejects_extra_arguments", test_version_command_rejects_extra_arguments);
            add_test ("require_command_missing_dependency_returns_error", test_require_command_missing_dependency_returns_error);
            add_test ("require_command_help_invokes_usage", test_require_command_help_invokes_usage);
            add_test ("require_command_rejects_unknown_option", test_require_command_rejects_unknown_option);
            add_test ("require_command_rejects_too_many_positionals", test_require_command_rejects_too_many_positionals);
            add_test ("require_command_uses_default_revision_and_default_config_path", test_require_command_uses_default_revision_and_default_config_path);
            add_test ("require_command_writes_dependency", test_require_command_writes_dependency);
            add_test ("require_command_dev_writes_dev_dependency", test_require_command_dev_writes_dev_dependency);
            add_test ("remove_command_missing_dependency_returns_error", test_remove_command_missing_dependency_returns_error);
            add_test ("remove_command_help_invokes_usage", test_remove_command_help_invokes_usage);
            add_test ("remove_command_rejects_too_many_positionals", test_remove_command_rejects_too_many_positionals);
            add_test ("remove_command_dev_removes_dev_dependency", test_remove_command_dev_removes_dev_dependency);
            add_test ("update_command_missing_named_dependency_returns_error", test_update_command_missing_named_dependency_returns_error);
            add_test ("update_command_help_invokes_usage", test_update_command_help_invokes_usage);
            add_test ("update_command_rejects_unknown_option", test_update_command_rejects_unknown_option);
            add_test ("update_command_rejects_too_many_positionals", test_update_command_rejects_too_many_positionals);
            add_test ("update_command_without_positionals_uses_default_config_path", test_update_command_without_positionals_uses_default_config_path);
            add_test ("update_command_accepts_dev_flag", test_update_command_accepts_dev_flag);
            add_test ("self_upgrade_command_unknown_executable_returns_error", test_self_upgrade_command_unknown_executable_returns_error);
        }

        public void test_help_command_invokes_usage () {
            var command = new HelpCommand ();
            var usage_called = false;
            var exit_code = command.execute (new string[] {"vamposer", "help"}, () => {
                usage_called = true;
            });

            assert (exit_code == 0);
            assert (usage_called);
        }

        public void test_completion_command_help_invokes_usage () {
            var command = new CompletionCommand ();
            var usage_called = false;
            var exit_code = command.execute (new string[] {"vamposer", "completion", "--help"}, () => {
                usage_called = true;
            });

            assert (exit_code == 0);
            assert (usage_called);
        }

        public void test_completion_command_rejects_unknown_action () {
            var command = new CompletionCommand ();
            var usage_called = false;
            var exit_code = command.execute (new string[] {"vamposer", "completion", "status"}, () => {
                usage_called = true;
            });

            assert (exit_code == 1);
            assert (usage_called);
        }

        public void test_init_command_creates_custom_config () {
            var old_cwd = Environment.get_current_dir ();
            string project_dir;
            try {
                project_dir = DirUtils.make_tmp ("vamposer-test-XXXXXX");
            } catch (Error e) {
                assert_not_reached ();
            }

            Environment.set_current_dir (project_dir);
            try {
                var command = new InitCommand ();
                var usage_called = false;
                var config_path = Path.build_filename (project_dir, "custom-vamposer.json");
                var exit_code = command.execute (new string[] {"vamposer", "init", config_path}, () => {
                    usage_called = true;
                });

                assert (exit_code == 0);
                assert (!usage_called);
                assert (FileUtils.test (config_path, FileTest.EXISTS));
            } finally {
                Environment.set_current_dir (old_cwd);
            }
        }

        public void test_init_command_help_invokes_usage () {
            var command = new InitCommand ();
            var usage_called = false;
            var exit_code = command.execute (new string[] {"vamposer", "init", "--help"}, () => {
                usage_called = true;
            });

            assert (exit_code == 0);
            assert (usage_called);
        }

        public void test_install_command_help_invokes_usage () {
            var command = new InstallCommand ();
            var usage_called = false;
            var exit_code = command.execute (new string[] {"vamposer", "install", "--help"}, () => {
                usage_called = true;
            });

            assert (exit_code == 0);
            assert (usage_called);
        }

        public void test_install_command_uses_custom_config () {
            var old_cwd = Environment.get_current_dir ();
            string project_dir;
            try {
                project_dir = DirUtils.make_tmp ("vamposer-test-XXXXXX");
            } catch (Error e) {
                assert_not_reached ();
            }

            Environment.set_current_dir (project_dir);
            try {
                var config_path = Path.build_filename (project_dir, "custom-vamposer.json");
                try {
                    FileUtils.set_contents (config_path, """
{
  "name": "com.example.app",
  "version": "0.0.1",
  "dependencies": {},
  "system_dependencies": {
    "glib-2.0": "*"
  }
}
""");
                } catch (Error e) {
                    assert_not_reached ();
                }

                var command = new InstallCommand ();
                var usage_called = false;
                var exit_code = command.execute (new string[] {"vamposer", "install", config_path}, () => {
                    usage_called = true;
                });

                assert (exit_code == 0);
                assert (!usage_called);
                assert (FileUtils.test (Path.build_filename (project_dir, "subprojects", "vamposer.build"), FileTest.EXISTS));
            } finally {
                Environment.set_current_dir (old_cwd);
            }
        }

        public void test_install_command_uses_default_config_path () {
            var old_cwd = Environment.get_current_dir ();
            string project_dir;
            try {
                project_dir = DirUtils.make_tmp ("vamposer-test-XXXXXX");
            } catch (Error e) {
                assert_not_reached ();
            }

            Environment.set_current_dir (project_dir);
            try {
                try {
                    FileUtils.set_contents ("vamposer.json", """
{
  "name": "com.example.app",
  "version": "0.0.1",
  "dependencies": {},
  "system_dependencies": {
    "glib-2.0": "*"
  }
}
""");
                } catch (Error e) {
                    assert_not_reached ();
                }

                var command = new InstallCommand ();
                var usage_called = false;
                var exit_code = command.execute (new string[] {"vamposer", "install"}, () => {
                    usage_called = true;
                });

                assert (exit_code == 0);
                assert (!usage_called);
                assert (FileUtils.test (Path.build_filename (project_dir, "subprojects", "vamposer.build"), FileTest.EXISTS));
            } finally {
                Environment.set_current_dir (old_cwd);
            }
        }

        public void test_install_command_accepts_dev_flag () {
            var old_cwd = Environment.get_current_dir ();
            string project_dir;
            try {
                project_dir = DirUtils.make_tmp ("vamposer-test-XXXXXX");
            } catch (Error e) {
                assert_not_reached ();
            }

            Environment.set_current_dir (project_dir);
            try {
                var config_path = Path.build_filename (project_dir, "custom-vamposer.json");
                try {
                    FileUtils.set_contents (config_path, """
{
  "name": "com.example.app",
  "version": "0.0.1",
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

                var command = new InstallCommand ();
                var usage_called = false;
                var exit_code = command.execute (new string[] {"vamposer", "install", "--dev", config_path}, () => {
                    usage_called = true;
                });

                assert (exit_code == 0);
                assert (!usage_called);
                assert (FileUtils.test (Path.build_filename (project_dir, "subprojects", "vamposer.build"), FileTest.EXISTS));
            } finally {
                Environment.set_current_dir (old_cwd);
            }
        }

        public void test_install_command_rejects_unknown_option () {
            var command = new InstallCommand ();
            var usage_called = false;
            var exit_code = command.execute (new string[] {"vamposer", "install", "--nope"}, () => {
                usage_called = true;
            });

            assert (exit_code == 1);
            assert (usage_called);
        }

        public void test_install_command_rejects_multiple_config_paths () {
            var command = new InstallCommand ();
            var usage_called = false;
            var exit_code = command.execute (new string[] {"vamposer", "install", "first.json", "second.json"}, () => {
                usage_called = true;
            });

            assert (exit_code == 1);
            assert (usage_called);
        }

        public void test_version_command_succeeds_without_arguments () {
            var command = new VersionCommand ();
            var usage_called = false;
            var exit_code = command.execute (new string[] {"vamposer", "version"}, () => {
                usage_called = true;
            });

            assert (exit_code == 0);
            assert (!usage_called);
        }

        public void test_version_command_rejects_extra_arguments () {
            var command = new VersionCommand ();
            var usage_called = false;
            var exit_code = command.execute (new string[] {"vamposer", "version", "unexpected"}, () => {
                usage_called = true;
            });

            assert (exit_code == 1);
            assert (usage_called);
        }

        public void test_require_command_missing_dependency_returns_error () {
            var command = new RequireCommand ();
            var usage_called = false;
            var exit_code = command.execute (new string[] {"vamposer", "require"}, () => {
                usage_called = true;
            });

            assert (exit_code == 1);
            assert (usage_called);
        }

        public void test_require_command_help_invokes_usage () {
            var command = new RequireCommand ();
            var usage_called = false;
            var exit_code = command.execute (new string[] {"vamposer", "require", "--help"}, () => {
                usage_called = true;
            });

            assert (exit_code == 0);
            assert (usage_called);
        }

        public void test_require_command_rejects_unknown_option () {
            var command = new RequireCommand ();
            var usage_called = false;
            var exit_code = command.execute (new string[] {"vamposer", "require", "--nope"}, () => {
                usage_called = true;
            });

            assert (exit_code == 1);
            assert (usage_called);
        }

        public void test_require_command_rejects_too_many_positionals () {
            var command = new RequireCommand ();
            var usage_called = false;
            var exit_code = command.execute (
                new string[] {"vamposer", "require", "dep", "rev", "path.json", "extra"},
                () => { usage_called = true; }
            );

            assert (exit_code == 1);
            assert (usage_called);
        }

        public void test_require_command_uses_default_revision_and_default_config_path () {
            var old_cwd = Environment.get_current_dir ();
            string project_dir;
            try {
                project_dir = DirUtils.make_tmp ("vamposer-test-XXXXXX");
            } catch (Error e) {
                assert_not_reached ();
            }

            Environment.set_current_dir (project_dir);
            try {
                var command = new RequireCommand ();
                var usage_called = false;
                var exit_code = command.execute (
                    new string[] {"vamposer", "require", "github.com/ValaTux/testcases"},
                    () => { usage_called = true; }
                );

                assert (exit_code == 0);
                assert (!usage_called);
                assert (FileUtils.test (Path.build_filename (project_dir, "vamposer.json"), FileTest.EXISTS));

                try {
                    var config = PackageConfig.load (Path.build_filename (project_dir, "vamposer.json"));
                    assert (config.dependencies.get ("github.com/ValaTux/testcases") == "*");
                } catch (Error e) {
                    assert_not_reached ();
                }
            } finally {
                Environment.set_current_dir (old_cwd);
            }
        }

        public void test_require_command_writes_dependency () {
            var old_cwd = Environment.get_current_dir ();
            string project_dir;
            try {
                project_dir = DirUtils.make_tmp ("vamposer-test-XXXXXX");
            } catch (Error e) {
                assert_not_reached ();
            }

            Environment.set_current_dir (project_dir);
            try {
                var config_path = Path.build_filename (project_dir, "custom-vamposer.json");
                var command = new RequireCommand ();
                var usage_called = false;
                var exit_code = command.execute (
                    new string[] {"vamposer", "require", "github.com/ValaTux/testcases", "master", config_path},
                    () => { usage_called = true; }
                );

                assert (exit_code == 0);
                assert (!usage_called);

                try {
                    var config = PackageConfig.load (config_path);
                    assert (config.dependencies.get ("github.com/ValaTux/testcases") == "master");
                } catch (Error e) {
                    assert_not_reached ();
                }
            } finally {
                Environment.set_current_dir (old_cwd);
            }
        }

        public void test_require_command_dev_writes_dev_dependency () {
            var old_cwd = Environment.get_current_dir ();
            string project_dir;
            try {
                project_dir = DirUtils.make_tmp ("vamposer-test-XXXXXX");
            } catch (Error e) {
                assert_not_reached ();
            }

            Environment.set_current_dir (project_dir);
            try {
                var config_path = Path.build_filename (project_dir, "custom-vamposer.json");
                var command = new RequireCommand ();
                var usage_called = false;
                var exit_code = command.execute (
                    new string[] {"vamposer", "require", "--dev", "github.com/ValaTux/testcases", "master", config_path},
                    () => { usage_called = true; }
                );

                assert (exit_code == 0);
                assert (!usage_called);

                try {
                    var config = PackageConfig.load (config_path);
                    assert (config.dev_dependencies.get ("github.com/ValaTux/testcases") == "master");
                    assert (!config.dependencies.has_key ("github.com/ValaTux/testcases"));
                } catch (Error e) {
                    assert_not_reached ();
                }
            } finally {
                Environment.set_current_dir (old_cwd);
            }
        }

        public void test_remove_command_missing_dependency_returns_error () {
            var command = new RemoveCommand ();
            var usage_called = false;
            var exit_code = command.execute (new string[] {"vamposer", "remove"}, () => {
                usage_called = true;
            });

            assert (exit_code == 1);
            assert (usage_called);
        }

        public void test_remove_command_help_invokes_usage () {
            var command = new RemoveCommand ();
            var usage_called = false;
            var exit_code = command.execute (new string[] {"vamposer", "remove", "--help"}, () => {
                usage_called = true;
            });

            assert (exit_code == 0);
            assert (usage_called);
        }

        public void test_remove_command_rejects_too_many_positionals () {
            var command = new RemoveCommand ();
            var usage_called = false;
            var exit_code = command.execute (
                new string[] {"vamposer", "remove", "dep", "path.json", "extra"},
                () => { usage_called = true; }
            );

            assert (exit_code == 1);
            assert (usage_called);
        }

        public void test_remove_command_dev_removes_dev_dependency () {
            var old_cwd = Environment.get_current_dir ();
            string project_dir;
            try {
                project_dir = DirUtils.make_tmp ("vamposer-test-XXXXXX");
            } catch (Error e) {
                assert_not_reached ();
            }

            Environment.set_current_dir (project_dir);
            try {
                var config_path = Path.build_filename (project_dir, "custom-vamposer.json");
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

                var command = new RemoveCommand ();
                var usage_called = false;
                var exit_code = command.execute (
                    new string[] {"vamposer", "remove", "--dev", "github.com/ValaTux/testcases", config_path},
                    () => { usage_called = true; }
                );

                assert (exit_code == 0);
                assert (!usage_called);

                try {
                    var config = PackageConfig.load (config_path);
                    assert (!config.dev_dependencies.has_key ("github.com/ValaTux/testcases"));
                } catch (Error e) {
                    assert_not_reached ();
                }
            } finally {
                Environment.set_current_dir (old_cwd);
            }
        }

        public void test_update_command_missing_named_dependency_returns_error () {
            var old_cwd = Environment.get_current_dir ();
            string project_dir;
            try {
                project_dir = DirUtils.make_tmp ("vamposer-test-XXXXXX");
            } catch (Error e) {
                assert_not_reached ();
            }

            Environment.set_current_dir (project_dir);
            try {
                var config_path = Path.build_filename (project_dir, "custom-vamposer.json");
                try {
                    FileUtils.set_contents (config_path, """
{
  "dependencies": {},
  "system_dependencies": {
    "glib-2.0": "*"
  }
}
""");
                } catch (Error e) {
                    assert_not_reached ();
                }

                var command = new UpdateCommand ();
                var usage_called = false;
                var exit_code = command.execute (
                    new string[] {"vamposer", "update", "github.com/ValaTux/testcases", config_path},
                    () => { usage_called = true; }
                );

                assert (exit_code == 1);
                assert (!usage_called);
            } finally {
                Environment.set_current_dir (old_cwd);
            }
        }

        public void test_update_command_help_invokes_usage () {
            var command = new UpdateCommand ();
            var usage_called = false;
            var exit_code = command.execute (new string[] {"vamposer", "update", "--help"}, () => {
                usage_called = true;
            });

            assert (exit_code == 0);
            assert (usage_called);
        }

        public void test_update_command_rejects_unknown_option () {
            var command = new UpdateCommand ();
            var usage_called = false;
            var exit_code = command.execute (
                new string[] {"vamposer", "update", "--nope"},
                () => { usage_called = true; }
            );

            assert (exit_code == 1);
            assert (usage_called);
        }

        public void test_update_command_rejects_too_many_positionals () {
            var command = new UpdateCommand ();
            var usage_called = false;
            var exit_code = command.execute (
                new string[] {"vamposer", "update", "dep", "path.json", "extra"},
                () => { usage_called = true; }
            );

            assert (exit_code == 1);
            assert (usage_called);
        }

        public void test_update_command_without_positionals_uses_default_config_path () {
            var old_cwd = Environment.get_current_dir ();
            string project_dir;
            try {
                project_dir = DirUtils.make_tmp ("vamposer-test-XXXXXX");
            } catch (Error e) {
                assert_not_reached ();
            }

            Environment.set_current_dir (project_dir);
            try {
                try {
                    FileUtils.set_contents ("vamposer.json", """
{
  "dependencies": {},
  "system_dependencies": {
    "glib-2.0": "*"
  }
}
""");
                } catch (Error e) {
                    assert_not_reached ();
                }

                var command = new UpdateCommand ();
                var usage_called = false;
                var exit_code = command.execute (
                    new string[] {"vamposer", "update"},
                    () => { usage_called = true; }
                );

                assert (exit_code == 0);
                assert (!usage_called);
                assert (FileUtils.test (Path.build_filename (project_dir, "subprojects", "vamposer.build"), FileTest.EXISTS));
            } finally {
                Environment.set_current_dir (old_cwd);
            }
        }

        public void test_update_command_accepts_dev_flag () {
            var old_cwd = Environment.get_current_dir ();
            string project_dir;
            try {
                project_dir = DirUtils.make_tmp ("vamposer-test-XXXXXX");
            } catch (Error e) {
                assert_not_reached ();
            }

            Environment.set_current_dir (project_dir);
            try {
                var config_path = Path.build_filename (project_dir, "custom-vamposer.json");
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

                var command = new UpdateCommand ();
                var usage_called = false;
                var exit_code = command.execute (
                    new string[] {"vamposer", "update", "--dev", "github.com/ValaTux/testcases", config_path},
                    () => { usage_called = true; }
                );

                assert (exit_code == 1);
                assert (!usage_called);
            } finally {
                Environment.set_current_dir (old_cwd);
            }
        }

        public void test_self_upgrade_command_unknown_executable_returns_error () {
            var command = new SelfUpgradeCommand ();
            var usage_called = false;
            var exit_code = command.execute (
                new string[] {"vamposer-this-command-should-not-exist", "self-upgrade"},
                () => { usage_called = true; }
            );

            assert (exit_code == 1);
            assert (!usage_called);
        }
    }
}

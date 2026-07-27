namespace AppTests {
    using GLib;
    using ValaTux.Testcases;
    using Vamposer;

    public class ConfigTest : BaseTest {
        construct {
            add_test ("config_loads_valid_json", test_config_loads_valid_json);
            add_test ("config_fails_on_non_object_dependencies", test_config_fails_on_non_object_dependencies);
            add_test ("config_fails_when_root_is_not_object", test_config_fails_when_root_is_not_object);
            add_test ("config_fails_when_alias_sources_is_not_array", test_config_fails_when_alias_sources_is_not_array);
            add_test ("config_fails_when_alias_sources_contains_non_string", test_config_fails_when_alias_sources_contains_non_string);
            add_test ("config_loads_aliases_and_alias_sources", test_config_loads_aliases_and_alias_sources);
            add_test ("config_trims_and_skips_empty_alias_sources", test_config_trims_and_skips_empty_alias_sources);
            add_test ("config_save_roundtrip_persists_all_sections", test_config_save_roundtrip_persists_all_sections);
            add_test ("config_load_missing_file_fails", test_config_load_missing_file_fails);
        }

        public void test_config_loads_valid_json () {
            string path;
            try {
                path = write_temp_json ("""
{
  "name": "com.example.app",
  "version": "1.2.3",
  "description": "A test app",
  "dependencies": {
    "github.com/ValaTux/testcases": "master"
  },
  "dependencies-dev": {
    "github.com/ValaTux/downloader-lib": "master"
  },
  "system_dependencies": {
    "glib-2.0": "*"
  }
}
""");
        } catch (Error e) {
          assert_not_reached ();
        }

        PackageConfig? config = null;
        try {
          config = PackageConfig.load (path);
        } catch (Error e) {
          assert_not_reached ();
        }

            assert (config.name == "com.example.app");
            assert (config.version == "1.2.3");
            assert (config.description == "A test app");
            assert (config.dependencies.size == 1);
            assert (config.dependencies.get ("github.com/ValaTux/testcases") == "master");
            assert (config.dev_dependencies.size == 1);
            assert (config.dev_dependencies.get ("github.com/ValaTux/downloader-lib") == "master");
            assert (config.system_dependencies.get ("glib-2.0") == "*");
        }

        public void test_config_fails_on_non_object_dependencies () {
            string path;
            try {
                path = write_temp_json ("""
{
  "dependencies": ["github.com/ValaTux/testcases"]
}
""");
            } catch (Error e) {
                assert_not_reached ();
            }

            bool failed = false;
            try {
                PackageConfig.load (path);
            } catch (Error e) {
                failed = true;
                assert (e.message.contains ("dependencies"));
            }

            assert (failed);
        }

          public void test_config_fails_when_root_is_not_object () {
            string path;
            try {
              path = write_temp_json ("[]\n");
            } catch (Error e) {
              assert_not_reached ();
            }

            var failed = false;
            try {
              PackageConfig.load (path);
            } catch (Error e) {
              failed = true;
              assert (e.message.contains ("root level"));
            }

            assert (failed);
          }

          public void test_config_fails_when_alias_sources_is_not_array () {
            string path;
            try {
              path = write_temp_json ("""
      {
        "alias_sources": {
        "bad": "shape"
        }
      }
      """);
            } catch (Error e) {
              assert_not_reached ();
            }

            var failed = false;
            try {
              PackageConfig.load (path);
            } catch (Error e) {
              failed = true;
              assert (e.message.contains ("alias_sources"));
            }

            assert (failed);
          }

          public void test_config_fails_when_alias_sources_contains_non_string () {
            string path;
            try {
              path = write_temp_json ("""
      {
        "alias_sources": [
        "https://example.com/aliases.json",
        42
        ]
      }
      """);
            } catch (Error e) {
              assert_not_reached ();
            }

            var failed = false;
            try {
              PackageConfig.load (path);
            } catch (Error e) {
              failed = true;
              assert (e.message.contains ("alias_sources[1]"));
            }

            assert (failed);
          }

        public void test_config_loads_aliases_and_alias_sources () {
            string path;
            try {
                path = write_temp_json ("""
{
  "aliases": {
    "my-lib": "github.com/MyOrg/my-lib"
  },
  "alias_sources": [
    "https://example.com/vamposer.aliases.json",
    "https://example.org/aliases.json"
  ]
}
""");
            } catch (Error e) {
                assert_not_reached ();
            }

            PackageConfig? config = null;
            try {
                config = PackageConfig.load (path);
            } catch (Error e) {
                assert_not_reached ();
            }

            assert (config.aliases.get ("my-lib") == "github.com/MyOrg/my-lib");
            assert (config.alias_sources.size == 2);
            assert (config.alias_sources.get (0) == "https://example.com/vamposer.aliases.json");
            assert (config.alias_sources.get (1) == "https://example.org/aliases.json");
        }

          public void test_config_trims_and_skips_empty_alias_sources () {
            string path;
            try {
              path = write_temp_json ("""
      {
        "alias_sources": [
        "  https://example.com/aliases.json  ",
        "",
        "   "
        ]
      }
      """);
            } catch (Error e) {
              assert_not_reached ();
            }

            PackageConfig? config = null;
            try {
              config = PackageConfig.load (path);
            } catch (Error e) {
              assert_not_reached ();
            }

            assert (config.alias_sources.size == 1);
            assert (config.alias_sources.get (0) == "https://example.com/aliases.json");
          }

          public void test_config_save_roundtrip_persists_all_sections () {
            string path = "%s/vamposer-config-roundtrip-%s.json".printf (Environment.get_tmp_dir (), Uuid.string_random ());

            var original = PackageConfig.create_empty ();
            original.dependencies.set ("github.com/ValaTux/testcases", "master");
            original.dev_dependencies.set ("github.com/ValaTux/downloader-lib", "main");
            original.system_dependencies.set ("glib-2.0", "*");
            original.aliases.set ("testcases", "github.com/ValaTux/testcases");
            original.alias_sources.add ("https://example.com/vamposer.aliases.json");

            try {
              original.save (path);
            } catch (Error e) {
              assert_not_reached ();
            }

            PackageConfig? loaded = null;
            try {
              loaded = PackageConfig.load (path);
            } catch (Error e) {
              assert_not_reached ();
            }

            assert (loaded.dependencies.get ("github.com/ValaTux/testcases") == "master");
            assert (loaded.dev_dependencies.get ("github.com/ValaTux/downloader-lib") == "main");
            assert (loaded.system_dependencies.get ("glib-2.0") == "*");
            assert (loaded.aliases.get ("testcases") == "github.com/ValaTux/testcases");
            assert (loaded.alias_sources.size == 1);
            assert (loaded.alias_sources.get (0) == "https://example.com/vamposer.aliases.json");
          }

          public void test_config_load_missing_file_fails () {
            var path = "%s/vamposer-missing-%s.json".printf (Environment.get_tmp_dir (), Uuid.string_random ());
            var failed = false;
            try {
              PackageConfig.load (path);
            } catch (Error e) {
              failed = true;
              assert (e.message.contains ("Config file not found"));
            }

            assert (failed);
          }

        private string write_temp_json (string content) throws Error {
            string path = "%s/vamposer-config-%s.json".printf (Environment.get_tmp_dir (), Uuid.string_random ());
            FileUtils.set_contents (path, content);
            return path;
        }
    }
}

namespace AppTests {
    using GLib;
    using Gee;
    using ValaTux.Testcases;
    using Vamposer;

    public class DependencyResolverTest : BaseTest {
        construct {
            add_test ("resolver_short_form_to_https_git", test_short_form_to_https_git);
            add_test ("resolver_keeps_https_and_appends_git", test_https_normalization);
            add_test ("resolver_supports_gitlab_ssh_form", test_gitlab_ssh_form);
            add_test ("resolver_supports_owner_repo_shortcut", test_owner_repo_shortcut);
            add_test ("resolver_supports_config_alias_overrides", test_config_alias_overrides);
            add_test ("resolver_extracts_project_name", test_extract_project_name);
        }

        public void test_short_form_to_https_git () {
            var url = DependencyResolver.normalize_repository_url ("github.com/ValaTux/testcases");
            assert (url == "https://github.com/ValaTux/testcases.git");
        }

        public void test_https_normalization () {
            var url = DependencyResolver.normalize_repository_url ("https://github.com/ValaTux/downloader-lib");
            assert (url == "https://github.com/ValaTux/downloader-lib.git");
        }

        public void test_gitlab_ssh_form () {
            var url = DependencyResolver.normalize_repository_url ("git@gitlab.com:group/project");
            assert (url == "git@gitlab.com:group/project.git");
        }

        public void test_owner_repo_shortcut () {
            var url = DependencyResolver.normalize_repository_url ("ValaTux/testcases");
            assert (url == "https://github.com/ValaTux/testcases.git");
        }

        public void test_config_alias_overrides () {
            var alias_sources = new ArrayList<string> ();
            var aliases = new HashMap<string, string> ();

            string file_path;
            try {
                file_path = Path.build_filename (Environment.get_tmp_dir (), "vamposer-aliases-%s.json".printf (Uuid.string_random ()));
                FileUtils.set_contents (file_path, """
{
  "ValaTux/testcases": "gitlab.com/MyOrg/forked-testcases"
}
""");
            } catch (Error e) {
                assert_not_reached ();
            }

            alias_sources.add ("file://%s".printf (file_path));
            aliases.set ("myalias", "github.com/ValaTux/downloader-lib");

            try {
                DependencyResolver.configure_alias_overrides (alias_sources, aliases);

                var url_from_source = DependencyResolver.normalize_repository_url ("ValaTux/testcases");
                assert (url_from_source == "https://gitlab.com/MyOrg/forked-testcases.git");

                var url_from_inline_alias = DependencyResolver.normalize_repository_url ("myalias");
                assert (url_from_inline_alias == "https://github.com/ValaTux/downloader-lib.git");
            } finally {
                DependencyResolver.configure_alias_overrides (new ArrayList<string> (), new HashMap<string, string> ());
            }
        }

        public void test_extract_project_name () {
            assert (DependencyResolver.extract_project_name ("git@gitlab.com:group/project.git") == "project");
            assert (DependencyResolver.extract_project_name ("https://gitlab.com/group/custom-lib/") == "custom-lib");

            var resolved = DependencyResolver.resolve ("github.com/ValaTux/testcases", "master");
            assert (resolved.project_name == "testcases");
            assert (resolved.local_directory == Path.build_filename ("subprojects", "testcases"));
        }
    }
}

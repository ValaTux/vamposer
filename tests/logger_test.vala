namespace AppTests {
    using GLib;
    using ValaTux.Testcases;
    using Vamposer;

    public class LoggerTest : BaseTest {
        construct {
            add_test ("style_log_line_plain_with_no_color", test_style_log_line_plain_with_no_color);
            add_test ("style_log_line_warn_with_color_force_contains_ansi", test_style_log_line_warn_with_color_force_contains_ansi);
            add_test ("style_log_line_success_with_color_force_contains_ansi", test_style_log_line_success_with_color_force_contains_ansi);
            add_test ("stdout_line_writes_to_stdout", test_stdout_line_writes_to_stdout);
            add_test ("stderr_line_writes_to_stderr", test_stderr_line_writes_to_stderr);
            add_test ("error_writes_prefixed_message_to_stderr", test_error_writes_prefixed_message_to_stderr);
        }

        private void disable_colors () {
            Environment.set_variable ("NO_COLOR", "1", true);
            Environment.unset_variable ("CLICOLOR_FORCE");
            ConsoleStyle.reset_color_cache ();
        }

        private void force_colors () {
            Environment.unset_variable ("NO_COLOR");
            Environment.set_variable ("CLICOLOR_FORCE", "1", true);
            Environment.set_variable ("TERM", "xterm-256color", true);
            ConsoleStyle.reset_color_cache ();
        }

        public void test_style_log_line_plain_with_no_color () {
            disable_colors ();

            var message = "[Vamposer] Attempting to auto-install missing system dependencies via apt-get\n";
            var styled = Logger.style_log_line (message);

            assert (styled == message);
        }

        public void test_style_log_line_warn_with_color_force_contains_ansi () {
            force_colors ();

            var message = "[Vamposer] Warning: check this\n";
            var styled = Logger.style_log_line (message);

            assert (styled.contains ("\x1b["));
            assert (styled.contains ("Warning:"));
            assert (styled.has_suffix ("\n"));
        }

        public void test_style_log_line_success_with_color_force_contains_ansi () {
            force_colors ();

            var message = "[Vamposer] Done. Git dependencies: 0\n";
            var styled = Logger.style_log_line (message);

            assert (styled.contains ("\x1b["));
            assert (styled.contains ("Done."));
            assert (styled.has_suffix ("\n"));
        }

        public void test_stdout_line_writes_to_stdout () {
            var token = "logger-stdout-token";
            if (Test.subprocess ()) {
                Logger.stdout_line (token);
                return;
            }

            Test.trap_subprocess ("/AppTestsLoggerTest/stdout_line_writes_to_stdout", 0, TestSubprocessFlags.DEFAULT);
            Test.trap_assert_passed ();
            Test.trap_assert_stdout ("*%s*".printf (token));
        }

        public void test_stderr_line_writes_to_stderr () {
            var token = "logger-stderr-token";
            if (Test.subprocess ()) {
                Logger.stderr_line (token);
                return;
            }

            Test.trap_subprocess ("/AppTestsLoggerTest/stderr_line_writes_to_stderr", 0, TestSubprocessFlags.DEFAULT);
            Test.trap_assert_passed ();
            Test.trap_assert_stderr ("*%s*".printf (token));
        }

        public void test_error_writes_prefixed_message_to_stderr () {
            var token = "integration-error-token";
            if (Test.subprocess ()) {
                disable_colors ();
                Logger.error (token);
                return;
            }

            Test.trap_subprocess ("/AppTestsLoggerTest/error_writes_prefixed_message_to_stderr", 0, TestSubprocessFlags.DEFAULT);
            Test.trap_assert_passed ();
            Test.trap_assert_stderr ("*[Vamposer] Error: %s*".printf (token));
        }
    }
}

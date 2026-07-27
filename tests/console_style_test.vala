namespace AppTests {
    using GLib;
    using ValaTux.Testcases;
    using Vamposer;

    public class ConsoleStyleTest : BaseTest {
        construct {
            add_test ("style_log_line_warning_returns_message", test_style_log_line_warning_returns_message);
            add_test ("style_log_line_success_returns_message", test_style_log_line_success_returns_message);
            add_test ("style_usage_entry_returns_plain_text_with_no_color", test_style_usage_entry_returns_plain_text_with_no_color);
            add_test ("style_usage_entry_formats_vamposer_command_when_color_forced", test_style_usage_entry_formats_vamposer_command_when_color_forced);
            add_test ("style_usage_entry_formats_generic_entry_when_color_forced", test_style_usage_entry_formats_generic_entry_when_color_forced);
            add_test ("style_usage_title_and_section_apply_color_when_forced", test_style_usage_title_and_section_apply_color_when_forced);
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

        public void test_style_log_line_warning_returns_message () {
            disable_colors ();

            var message = "[Vamposer] Warning: check this";
            var styled = ConsoleStyle.style_log_line (message);

            assert (styled == message);
        }

        public void test_style_log_line_success_returns_message () {
            disable_colors ();

            var message = "[Vamposer] Done. Git dependencies: 0";
            var styled = ConsoleStyle.style_log_line (message);

            assert (styled == message);
        }

        public void test_style_usage_entry_returns_plain_text_with_no_color () {
            disable_colors ();

            var entry = "  vamposer install --dev";
            var styled = ConsoleStyle.style_usage_entry (entry);

            assert (styled == entry);
        }

        public void test_style_usage_entry_formats_vamposer_command_when_color_forced () {
            force_colors ();

            var entry = "  vamposer install --dev";
            var styled = ConsoleStyle.style_usage_entry (entry);

            assert (styled.contains ("\x1b["));
            assert (styled.contains ("vamposer"));
            assert (styled.contains ("install --dev"));
        }

        public void test_style_usage_entry_formats_generic_entry_when_color_forced () {
            force_colors ();

            var entry = "  --dev   Include dev dependencies";
            var styled = ConsoleStyle.style_usage_entry (entry);

            assert (styled.contains ("\x1b["));
            assert (styled.contains ("--dev   Include dev dependencies"));
        }

        public void test_style_usage_title_and_section_apply_color_when_forced () {
            force_colors ();

            var title = ConsoleStyle.style_usage_title ("Usage");
            var section = ConsoleStyle.style_usage_section ("Commands");

            assert (title.contains ("\x1b["));
            assert (title.contains ("Usage"));
            assert (section.contains ("\x1b["));
            assert (section.contains ("Commands"));
        }
    }
}

using GLib;
using Gee;

int main (string[] args) {

    ValaTux.Testcases.BaseTest.saved_commands = new Gee.ArrayList<ValaTux.Testcases.TestCommand> ();
    Test.init (ref args);

    ValaTux.Testcases.register_test_suite<AppTests.ConfigTest> ();
    ValaTux.Testcases.register_test_suite<AppTests.ConsoleStyleTest> ();
    ValaTux.Testcases.register_test_suite<AppTests.LoggerTest> ();
    ValaTux.Testcases.register_test_suite<AppTests.DependencyResolverTest> ();
    ValaTux.Testcases.register_test_suite<AppTests.InstallerTest> ();
    ValaTux.Testcases.register_test_suite<AppTests.InstallerErrorTest> ();
    ValaTux.Testcases.register_test_suite<AppTests.CommandsTest> ();
    ValaTux.Testcases.register_test_suite<AppTests.SystemDependencyInstallerTest> ();


    return Test.run ();
}

####    use ExtUtils::MakeMaker;
####    # See lib/ExtUtils/MakeMaker.pm for details of how to influence
####    # the contents of the Makefile that is written.
####    WriteMakefile(
####        'NAME'	=> 'Device::SerialPort',
####        'VERSION_FROM' => 'SerialPort.pm', # finds $VERSION
####    );

#### Makefile.PL currently adapted from Win32::SeriaPort distribution

print "\n\n                 Device::SerialPort VERSION 0.04\n";
print "    No 'Makefile' will be created so skip customary 'make' step\n\n";
print "            Test with nothing connected to /dev/ttyS0\n";
print "          or for different port: perl makefile.PL PORT\n\n";
print "       You must have permission to open the specified PORT\n";
print "         Create a lock file in advance if one is required\n\n";
print "             The test suite will run automatically\n";
print "         Timeout tests can take up to 30 seconds per test\n\n";

my $file = "/dev/ttyS0";
if (@ARGV) {
    $file = shift @ARGV;
}
$ENV{Makefile_Test_Port} = $file;

use Test::Harness;
runtests ("t/test1.t", "t/test3.t");

print "\nRun 'perl Install.PL' to install into proper locations.\n\n";
print "To run individual tests, type:\n";
print "    prompt]$ perl t/test1.t Page_Pause_Time (0..5) [ /dev/ttySx ]\n";
## print "Continue with 'perl t/test2.t' through 'perl t/test7.t'\n";
print "See README and other documentation for additional information.\n\n";

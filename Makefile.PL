use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'	=> 'Device::SerialPort',
    'VERSION_FROM' => 'SerialPort.pm', # finds $VERSION
    'SKIP'	=> [qw(tool_autosplit)],
    'clean'	=> {FILES => "t/DefaultPort.pm *.cfg t/*.cfg"},
);

my $file = "/dev/ttyS0";
if (@ARGV) {
    $file = shift @ARGV;
}

my $dfile = "t/DefaultPort.pm";
open (DEFAULT, "> $dfile") or die "Can't create $dfile: $!\n";
print DEFAULT <<EOF;
package SerialJunk;
# Created by Makefile.PL

\$Makefile_Test_Port = "$file";
EOF

close DEFAULT;

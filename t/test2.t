#!/usr/bin/perl -w

use lib '.','./t','./blib/lib','../blib/lib';
# can run from here or distribution base

# Before installation is performed this script should be runnable with
# `perl test2.t time' which pauses `time' seconds (1..5) between pages

######################### We start with some black magic to print on failure.

BEGIN { $| = 1; print "1..39\n"; }
END {print "not ok 1\n" unless $loaded;}
use Device::SerialPort 0.06;
require "DefaultPort.pm";
$loaded = 1;
print "ok 1\n";

######################### End of black magic.

# Insert your test code below (better if it prints "ok 13"
# (correspondingly "not ok 13") depending on the success of chunk 13
# of the test code):

# tests start using file created by test1.t

use strict;

my $file = "/dev/ttyS0";
if ($SerialJunk::Makefile_Test_Port) {
    $file = $SerialJunk::Makefile_Test_Port;
}
if (exists $ENV{Makefile_Test_Port}) {
    $file = $ENV{Makefile_Test_Port};
}

my $naptime = 0;	# pause between output pages
if (@ARGV) {
    $naptime = shift @ARGV;
    unless ($naptime =~ /^[0-5]$/) {
	die "Usage: perl test?.t [ page_delay (0..5) ] [ /dev/ttyxx ]";
    }
}
if (@ARGV) {
    $file = shift @ARGV;
}

my $cfgfile = $file."_test.cfg";
$cfgfile =~ s/.*\///;

my $fault = 0;
my $tc = 2;		# next test number
my $ob;
my $pass;
my $fail;
my $in;
my $in2;
my @opts;
my $out;
my $blk;
my $err;
my $e;
my $tick;
my $tock;
my @necessary_param = Device::SerialPort->set_test_mode_active(1);

sub is_ok {
    my $result = shift;
    printf (($result ? "" : "not ")."ok %d\n",$tc++);
    return $result;
}

sub is_zero {
    my $result = shift;
    if (defined $result) {
        return is_ok ($result == 0);
    }
    else {
        printf ("not ok %d\n",$tc++);
    }
}

sub is_bad {
    my $result = shift;
    printf (($result ? "not " : "")."ok %d\n",$tc++);
    return (not $result);
}

# 2: Constructor

unless (is_ok ($ob = Device::SerialPort->start ($cfgfile))) {
    printf "could not open port from $cfgfile\n";
    exit 1;
    # next test would die at runtime without $ob
}

#### 3 - 11: Check Port Capabilities Match Save

is_ok ($ob->baudrate == 9600);			# 3
is_ok ($ob->parity eq "none");			# 4
is_ok ($ob->databits == 8);			# 5
is_ok ($ob->stopbits == 1);			# 6
is_ok ($ob->handshake eq "none");		# 7
is_ok ($ob->read_const_time == 0);		# 8
is_ok ($ob->read_char_time == 0);		# 9
is_ok ($ob->alias eq "TestPort");		# 10
is_ok ($ob->parity_enable == 0);		# 11

# 12 - 14: "Instant" return for read_xx_time=0

$tick=$ob->get_tick_count;
($in, $in2) = $ob->read(10);
$tock=$ob->get_tick_count;

is_zero ($in);					# 12
is_bad ($in2);					# 13
$out=$tock - $tick;
is_ok ($out < 150);				# 14
print "<0> elapsed time=$out\n";

print "Beginning Timed Tests at 2-5 Seconds per Set\n";

# 15 - 18: 2 Second Constant Timeout

is_ok (2000 == $ob->read_const_time(2000));	# 15
$tick=$ob->get_tick_count;
($in, $in2) = $ob->read(10);
$tock=$ob->get_tick_count;

is_zero ($in);					# 16
is_bad ($in2);					# 17
$out=$tock - $tick;
is_bad (($out < 1800) or ($out > 2400));	# 18
print "<2000> elapsed time=$out\n";

if ($naptime) {
    print "++++ page break\n";
    sleep $naptime;
}

# 19 - 22: 4 Second Timeout Constant+Character

is_ok (100 == $ob->read_char_time(100));	# 19

$tick=$ob->get_tick_count;
($in, $in2) = $ob->read(20);
$tock=$ob->get_tick_count;

is_zero ($in);					# 20
is_bad ($in2);					# 21
$out=$tock - $tick;
is_bad (($out < 3800) or ($out > 4400));	# 22
print "<4000> elapsed time=$out\n";


# 23 - 26: 3 Second Character Timeout

is_zero ($ob->read_const_time(0));		# 23

$tick=$ob->get_tick_count;
($in, $in2) = $ob->read(30);
$tock=$ob->get_tick_count;

is_zero ($in);					# 24
is_bad ($in2);					# 25
$out=$tock - $tick;
is_bad (($out < 2800) or ($out > 3400));	# 26
print "<3000> elapsed time=$out\n";

is_zero ($ob->read_char_time(0));		# 27

is_ok ("rts" eq $ob->handshake("rts"));		# 28
is_ok ($ob->purge_rx);				# 29 
is_ok ($ob->purge_all);				# 30 
is_ok ($ob->purge_tx);				# 31 

is_ok(1 == $ob->user_msg);			# 32
is_zero(scalar $ob->user_msg(0));		# 33
is_ok(1 == $ob->user_msg(1));			# 34
is_ok(1 == $ob->error_msg);			# 35
is_zero(scalar $ob->error_msg(0));		# 36
is_ok(1 == $ob->error_msg(1));			# 37

undef $ob;

# 38 - 39: Reopen tests (unconfirmed) $ob->close via undef

sleep 1;
unless (is_ok ($ob = Device::SerialPort->start ($cfgfile))) {
    printf "could not reopen port from $cfgfile\n";
    exit 1;
    # next test would die at runtime without $ob
}
is_ok(1 == $ob->close);				# 39
undef $ob;

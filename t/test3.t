#!/usr/bin/perl -w

use lib '.','..','./t'; # can run from here or distribution base

# Before installation is performed this script should be runnable with
# `perl test1.t time' which pauses `time' seconds (1..5) between pages

######################### We start with some black magic to print on failure.

# Change 1..1 below to 1..last_test_to_print .
# (It may become useful if the test is moved to ./t subdirectory.)

BEGIN { $| = 1; print "1..125\n"; }
END {print "not ok 1\n" unless $loaded;}
use AltPort qw( :PARAM 0.05 );		# check inheritance & export
$loaded = 1;
print "ok 1\n";

######################### End of black magic.

# Insert your test code below (better if it prints "ok 13"
# (correspondingly "not ok 13") depending on the success of chunk 13
# of the test code):

use strict;

## verifies the (0, 1) list returned by binary functions
sub test_bin_list {
    return undef unless (@_ == 2);
    return undef unless (0 == shift);
    return undef unless (1 == shift);
    return 1;
}

my $tc = 2;		# next test number

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

# assume a "vanilla" port on "/dev/ttyS0"

my $file = "/dev/ttyS0";
if (exists $ENV{Makefile_Test_Port}) {
    $file = $ENV{Makefile_Test_Port};
}

## my $cfgfile = "ttyS0_test.cfg";

my $naptime = 0;	# pause between output pages
if (@ARGV) {
    $naptime = shift @ARGV;
    unless ($naptime =~ /^[0-5]$/) {
	die "Usage: perl test?.t [ page_delay (0..5) ] [ /dev/ttySx ]";
    }
}
if (@ARGV) {
    $file = shift @ARGV;
}

my $fault = 0;
my $ob;
my $pass;
my $fail;
my $in;
my $in2;
my @opts;
my $out;
my $err;
my $blk;
my $e;
my $tick;
my $tock;
my %required_param;

is_ok(0x0 == nocarp);				# 2
my @necessary_param = AltPort->set_test_mode_active(1);

## unlink $cfgfile;
foreach $e (@necessary_param) { $required_param{$e} = 0; }

## 2 - 5 SerialPort Global variable ($Babble);

is_bad(scalar AltPort->debug);		# 3: start out false
is_ok(scalar AltPort->debug(1));	# 4: set it

# 5: yes_true subroutine, no need to SHOUT if it works

$e="not ok $tc:";
unless (AltPort->debug("T"))   { print "$e \"T\"\n"; $fault++; }
if     (AltPort->debug("F"))   { print "$e \"F\"\n"; $fault++; }

no strict 'subs';
unless (AltPort->debug(T))     { print "$e T\n";     $fault++; }
if     (AltPort->debug(F))     { print "$e F\n";     $fault++; }
unless (AltPort->debug(Y))     { print "$e Y\n";     $fault++; }
if     (AltPort->debug(N))     { print "$e N\n";     $fault++; }
unless (AltPort->debug(ON))    { print "$e ON\n";    $fault++; }
if     (AltPort->debug(OFF))   { print "$e OFF\n";   $fault++; }
unless (AltPort->debug(TRUE))  { print "$e TRUE\n";  $fault++; }
if     (AltPort->debug(FALSE)) { print "$e FALSE\n"; $fault++; }
unless (AltPort->debug(Yes))   { print "$e Yes\n";   $fault++; }
if     (AltPort->debug(No))    { print "$e No\n";    $fault++; }
unless (AltPort->debug("yes")) { print "$e \"yes\"\n"; $fault++; }
if     (AltPort->debug("f"))   { print "$e \"f\"\n";   $fault++; }
use strict 'subs';

print "ok $tc\n" unless ($fault);		# 5
$tc++;

@opts = AltPort->debug;		# 6: binary_opt array
is_ok(test_bin_list(@opts));

# 7: Constructor

unless (is_ok ($ob = AltPort->new ($file))) {
    printf "could not open port $file\n";
    exit 1;
    # next test would die at runtime without $ob
}

#### 8 - 64: Check Port Capabilities 

## 8 - 21: Binary Capabilities

is_ok($ob->can_baud);				# 8
is_ok($ob->can_databits);			# 9
is_ok($ob->can_stopbits);			# 10
is_zero($ob->can_dtrdsr);			# 11
is_ok($ob->can_handshake);			# 12
is_ok($ob->can_parity_check);			# 13
is_ok($ob->can_parity_config);			# 14
is_ok($ob->can_parity_enable);			# 15
is_zero($ob->can_rlsd);				# 16
is_ok($ob->can_rtscts);				# 17
is_ok($ob->can_xonxoff);			# 18
is_zero($ob->can_interval_timeout);		# 19
is_ok($ob->can_total_timeout);			# 20
is_zero($ob->can_xon_char);			# 21
if ($naptime) {
    print "++++ page break\n";
    sleep $naptime;
}

is_zero($ob->can_spec_char);			# 22
is_zero($ob->can_16bitmode);			# 23
is_ok($ob->is_rs232);				# 24
is_zero($ob->is_modem);				# 25

#### 26 - xx: Set Basic Port Parameters 

## 26 - 31: Baud (Valid/Invalid/Current)

@opts=$ob->baudrate;		# list of allowed values
is_ok(1 == grep(/^9600$/, @opts));		# 26
is_zero(scalar grep(/^9601/, @opts));		# 27

is_ok($in = $ob->baudrate);			# 28
is_ok(1 == grep(/^$in$/, @opts));		# 29

is_bad(scalar $ob->baudrate(9601));		# 30
is_ok($in == $ob->baudrate(9600));		# 31
    # leaves 9600 pending

## 32 - xx: Parity (Valid/Invalid/Current)

@opts=$ob->parity;		# list of allowed values
is_ok(1 == grep(/none/, @opts));		# 32
is_zero(scalar grep(/any/, @opts));		# 33

is_ok($in = $ob->parity);			# 34
is_ok(1 == grep(/^$in$/, @opts));		# 35

is_bad(scalar $ob->parity("any"));		# 36
is_ok($in eq $ob->parity("none"));		# 37
    # leaves "none" pending

## 38 - 43: Databits (Valid/Invalid/Current)

@opts=$ob->databits;		# list of allowed values
is_ok(1 == grep(/8/, @opts));			# 38
is_zero(scalar grep(/4/, @opts));		# 39

is_ok($in = $ob->databits);			# 40
is_ok(1 == grep(/^$in$/, @opts));		# 41

is_bad(scalar $ob->databits(3));		# 42
is_ok($in == $ob->databits(8));			# 43
    # leaves 8 pending

if ($naptime) {
    print "++++ page break\n";
    sleep $naptime;
}

## 44 - 49: Stopbits (Valid/Invalid/Current)

@opts=$ob->stopbits;		# list of allowed values
is_ok(1 == grep(/2/, @opts));			# 44
is_zero(scalar grep(/1.5/, @opts));		# 45

is_ok($in = $ob->stopbits);			# 46
is_ok(1 == grep(/^$in$/, @opts));		# 47

is_bad(scalar $ob->stopbits(3));		# 48
is_ok($in == $ob->stopbits(1));			# 49
    # leaves 1 pending

## 50 - 55: Handshake (Valid/Invalid/Current)

@opts=$ob->handshake;		# list of allowed values
is_ok(1 == grep(/none/, @opts));		# 50
is_zero(scalar grep(/moo/, @opts));		# 51

is_ok($in = $ob->handshake);			# 52
is_ok(1 == grep(/^$in$/, @opts));		# 53

is_bad(scalar $ob->handshake("moo"));		# 54
is_ok($in = $ob->handshake("rts"));		# 55
    # leaves "rts" pending for status

## 56 - 61: Buffer Size

($in, $out) = $ob->buffer_max(512);
is_bad(defined $in);				# 56
($in, $out) = $ob->buffer_max;
is_ok(defined $in);				# 57

if (($in > 0) and ($in < 4096))		{ $in2 = $in; } 
else					{ $in2 = 4096; }

if (($out > 0) and ($out < 4096))	{ $err = $out; } 
else					{ $err = 4096; }

is_ok(scalar $ob->buffers($in2, $err));		# 58

@opts = $ob->buffers(4096, 4096, 4096);
is_bad(defined $opts[0]);			# 59
($in, $out)= $ob->buffers;
is_ok($in2 == $in);				# 60
is_ok($out == $err);				# 61

## 62 - 64: Other Parameters (Defaults)

is_ok("AltPort" eq $ob->alias("AltPort"));	# 62
is_zero(scalar $ob->parity_enable(0));		# 63
is_ok($ob->write_settings);			# 64
is_ok($ob->binary);				# 65

if ($naptime) {
    print "++++ page break\n";
    sleep $naptime;
}

## 66 - 67: Read Timeout Initialization

is_zero($ob->read_const_time);			# 66
is_zero($ob->read_char_time);			# 67

## 68 - 74: No Handshake, Polled Write

is_ok("none" eq $ob->handshake("none"));	# 68

$e="testing is a wonderful thing - this is a 60 byte long string";
#   123456789012345678901234567890123456789012345678901234567890
my $line = "\r\n$e\r\n$e\r\n$e\r\n";	# about 195 MS at 9600 baud

$tick=$ob->GetTickCount();
$pass=$ob->write($line);
is_ok(1 == $ob->write_drain);			# 69
$tock=$ob->GetTickCount();

is_ok($pass == 188);				# 70
$err=$tock - $tick;
is_bad (($err < 160) or ($err > 210));		# 71
print "<185> elapsed time=$err\n";

is_ok(scalar $ob->purge_tx);			# 72
is_ok(scalar $ob->purge_rx);			# 73
is_ok(scalar $ob->purge_all);			# 74

## 75 - 80: Optional Messages

@opts = $ob->user_msg;
is_ok(test_bin_list(@opts));			# 75
is_zero(scalar $ob->user_msg);			# 76
is_ok(1 == $ob->user_msg(1));			# 77

@opts = $ob->error_msg;
is_ok(test_bin_list(@opts));			# 78
is_zero(scalar $ob->error_msg);			# 79
is_ok(1 == $ob->error_msg(1));			# 80
undef $ob;

## 81 - 115: Reopen as (mostly 5.003 Compatible) Tie

    # constructor = TIEHANDLE method		# 81
unless (is_ok ($ob = tie(*PORT,'AltPort', $file))) {
    printf "could not reopen port from $file\n";
    exit 1;
    # next test would die at runtime without $ob
}

    # tie to PRINT method
$tick=$ob->GetTickCount();
$pass=print PORT $line;
is_ok(1 == $ob->write_drain);			# 82
$tock=$ob->GetTickCount();

is_ok($pass == 1);				# 83

$err=$tock - $tick;
is_bad (($err < 160) or ($err > 210));		# 84
print "<185> elapsed time=$err\n";

if ($naptime) {
    print "++++ page break\n";
    sleep $naptime;
}

    # tie to PRINTF method
$tick=$ob->GetTickCount();
if ( $] < 5.004 ) {
    $out=sprintf "123456789_%s_987654321", $line;
    $pass=print PORT $out;
}
else {
    $pass=printf PORT "123456789_%s_987654321", $line;
}
is_ok(1 == $ob->write_drain);			# 85
$tock=$ob->GetTickCount();

is_ok($pass == 1);				# 86
$err=$tock - $tick;
is_bad (($err < 180) or ($err > 235));		# 87
print "<205> elapsed time=$err\n";

is_ok (300 == $ob->read_const_time(300));	# 88
is_ok (20 == $ob->read_char_time(20));		# 89
$tick=$ob->GetTickCount();
$in2 = $ob->input;
$tock=$ob->GetTickCount();

is_ok (20 == $ob->read_char_time);		# 90
is_ok ($in2 eq "");				# 91

$err=$tock - $tick;
is_bad ($err > 50);				# 92
print "<0> elapsed time=$err\n";

is_ok (0 == $ob->read_char_time(0));		# 93
$tick=$ob->GetTickCount();
$in2= getc PORT;
$tock=$ob->GetTickCount();

is_bad (defined $in2);				# 94
$err=$tock - $tick;
is_bad (($err < 280) or ($err > 350));		# 95
print "<300> elapsed time=$err\n";

is_ok (0 == $ob->read_const_time(0));		# 96
$tick=$ob->GetTickCount();
$in2= getc PORT;
$tock=$ob->GetTickCount();

is_bad (defined $in2);				# 97
$err=$tock - $tick;
is_bad ($err > 50);				# 98
print "<0> elapsed time=$err\n";

## 99 - 103: Bad Port (new + quiet)

$file = "/dev/badport";
my $ob2;
is_bad ($ob2 = AltPort->new ($file));		# 99
is_bad (defined $ob2);				# 100
is_zero ($ob2 = AltPort->new ($file, 1));	# 101
is_bad ($ob2 = AltPort->new ($file, 0));	# 102
is_bad (defined $ob2);				# 103

if ($naptime) {
    print "++++ page break\n";
    sleep $naptime;
}

## 104 - 119: Output bits and pulses

if ($ob->can_ioctl) {
    is_ok ($ob->dtr_active(0));			# 104
    $tick=$ob->GetTickCount();
    is_ok ($ob->pulse_dtr_on(100));		# 105
    $tock=$ob->GetTickCount();
    $err=$tock - $tick;
    is_bad (($err < 180) or ($err > 240));	# 106
    print "<200> elapsed time=$err\n";
    
    is_ok ($ob->dtr_active(1));			# 107
    $tick=$ob->GetTickCount();
    is_ok ($ob->pulse_dtr_off(200));		# 108
    $tock=$ob->GetTickCount();
    $err=$tock - $tick;
    is_bad (($err < 370) or ($err > 450));	# 109
    print "<400> elapsed time=$err\n";
    
    is_ok ($ob->rts_active(0));			# 110
    $tick=$ob->GetTickCount();
    is_ok ($ob->pulse_rts_on(150));		# 111
    $tock=$ob->GetTickCount();
    $err=$tock - $tick;
    is_bad (($err < 275) or ($err > 345));	# 112
    print "<300> elapsed time=$err\n";
    
    is_ok ($ob->rts_active(1));			# 113
    $tick=$ob->GetTickCount();
    is_ok ($ob->pulse_rts_on(50));		# 114
    $tock=$ob->GetTickCount();
    $err=$tock - $tick;
    is_bad (($err < 80) or ($err > 130));	# 115
    print "<100> elapsed time=$err\n";
    
    is_ok ($ob->rts_active(0));			# 116
    is_ok ($ob->dtr_active(0));			# 117
}
else {
    print "bypassing ioctl tests\n";
    while ($tc < 117.1) { is_ok (1); }		# 104-117
}

$tick=$ob->GetTickCount();
is_ok ($ob->pulse_break_on(250));		# 118
$tock=$ob->GetTickCount();
$err=$tock - $tick;
is_bad (($err < 300) or ($err > 900));		# 119
print "<500> elapsed time=$err\n";

    # destructor = CLOSE method
if ( $] < 5.005 ) {
    is_ok($ob->close);				# 120
}
else {
    is_ok(close PORT);				# 120
}

    # destructor = DESTROY method
undef $ob;					# Don't forget this one!!
untie *PORT;

if ($naptime) {
    print "++++ page break\n";
    sleep $naptime;
}

no strict 'subs';
is_ok(0xffffffff == LONGsize);			# 121
is_ok(0xffff == SHORTsize);			# 122
is_ok(0x1 == nocarp);				# 123
is_ok(0x0 == yes_true("F"));			# 124
is_ok(0x1 == yes_true("T"));			# 125

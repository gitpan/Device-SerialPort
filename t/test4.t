#!/usr/bin/perl -w

use lib '.','./t','./blib/lib','../blib/lib';
# can run from here or distribution base

# Before installation is performed this script should be runnable with
# `perl test4.t time' which pauses `time' seconds (1..5) between pages

######################### We start with some black magic to print on failure.

BEGIN { $| = 1; print "1..313\n"; }
END {print "not ok 1\n" unless $loaded;}
use AltPort 0.06;		# check inheritance & export
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
my $patt;
my $instead;
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
is_ok ($ob->alias eq "AltPort");		# 10
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

if ($naptime) {
    print "++++ page break\n";
    sleep $naptime;
}

print "Stty Shortcut Parameters\n";

my $vstart_1 = $ob->is_xon_char;
is_ok(defined $vstart_1);			# 38
my $vstop_1 = $ob->is_xoff_char;
is_ok(defined $vstop_1);			# 39
my $vintr_1 = $ob->is_stty_intr;
is_ok(defined $vintr_1);			# 40
my $vquit_1 = $ob->is_stty_quit;
is_ok(defined $vquit_1);			# 41

my $veof_1 = $ob->is_stty_eof;
is_ok(defined $veof_1);				# 42
my $veol_1 = $ob->is_stty_eol;
is_ok(defined $veol_1);				# 43
my $verase_1 = $ob->is_stty_erase;
is_ok(defined $verase_1);			# 44
my $vkill_1 = $ob->is_stty_kill;
is_ok(defined $vkill_1);			# 45
my $vsusp_1 = $ob->is_stty_susp;
is_ok(defined $vsusp_1);			# 46

is_zero $ob->stty_echo;				# 47
my $echoe_1 = $ob->stty_echoe;
is_ok(defined $echoe_1);			# 48
my $echok_1 = $ob->stty_echok;
is_ok(defined $echok_1);			# 49

is_zero $ob->stty_echonl;			# 50
is_zero $ob->stty_istrip;			# 51
is_zero $ob->stty_icrnl;			# 52
is_zero $ob->stty_igncr;			# 53
is_zero $ob->stty_inlcr;			# 54
is_zero $ob->stty_opost;			# 55
is_zero $ob->stty_isig;				# 56
is_zero $ob->stty_icanon;			# 57

print "Change all the parameters\n";

#### 58 - 88: Modify All Port Capabilities

is_ok ($ob->baudrate(1200) == 1200);		# 58
is_ok ($ob->parity("odd") eq "odd");		# 59

if ($naptime) {
    print "++++ page break\n";
    sleep $naptime;
}

is_ok ($ob->databits(7) == 7);			# 60
is_ok ($ob->stopbits(2) == 2);			# 61
is_ok ($ob->handshake("xoff") eq "xoff");	# 62
is_ok ($ob->read_const_time(1000) == 1000);	# 63
is_ok ($ob->read_char_time(50) == 50);		# 64
is_ok ($ob->alias("oddPort") eq "oddPort");	# 65
is_ok (scalar $ob->parity_enable(1));		# 66
is_zero ($ob->user_msg(0));			# 67
is_zero ($ob->error_msg(0));			# 68

is_ok(64 == $ob->is_xon_char(64));		# 69
is_ok(65 == $ob->is_xoff_char(65));		# 70
is_ok(66 == $ob->is_stty_intr(66));		# 71
is_ok(67 == $ob->is_stty_quit(67));		# 72
is_ok(68 == $ob->is_stty_eof(68));		# 73
is_ok(69 == $ob->is_stty_eol(69));		# 74
is_ok(70 == $ob->is_stty_erase(70));		# 75
is_ok(71 == $ob->is_stty_kill(71));		# 76
is_ok(72 == $ob->is_stty_susp(72));		# 77

is_ok($echoe_1 != $ob->stty_echoe(! $echoe_1));	# 78
is_ok($echok_1 != $ob->stty_echok(! $echok_1));	# 79
is_ok(1 == $ob->stty_echonl(1));		# 80

if ($naptime) {
    print "++++ page break\n";
    sleep $naptime;
}

is_ok(1 == $ob->stty_istrip(1));		# 81
is_ok(1 == $ob->stty_icrnl(1));			# 82
is_ok(1 == $ob->stty_igncr(1));			# 83
is_ok(1 == $ob->stty_inlcr(1));			# 84
is_ok(1 == $ob->stty_opost(1));			# 85
is_ok(1 == $ob->stty_isig(1));			# 86
is_ok(1 == $ob->stty_icanon(1));		# 87
is_ok(1 == $ob->stty_echo(1));			# 88

#### 89 - 119: Check Port Capabilities Match Changes

is_ok ($ob->baudrate == 1200);			# 89
is_ok ($ob->parity eq "odd");			# 90
is_ok ($ob->databits == 7);			# 91
is_ok ($ob->stopbits == 2);			# 92
is_ok ($ob->handshake eq "xoff");		# 93
is_ok ($ob->read_const_time == 1000);		# 94
is_ok ($ob->read_char_time == 50);		# 95
is_ok ($ob->alias eq "oddPort");		# 96
is_ok (scalar $ob->parity_enable);		# 97
is_zero ($ob->user_msg);			# 98
is_zero ($ob->error_msg);			# 99

if ($naptime) {
    print "++++ page break\n";
    sleep $naptime;
}

is_ok(64 == $ob->is_xon_char);			# 100
is_ok(65 == $ob->is_xoff_char);			# 101
is_ok(66 == $ob->is_stty_intr);			# 102
is_ok(67 == $ob->is_stty_quit);			# 103
is_ok(68 == $ob->is_stty_eof);			# 104
is_ok(69 == $ob->is_stty_eol);			# 105
is_ok(70 == $ob->is_stty_erase);		# 106
is_ok(71 == $ob->is_stty_kill);			# 107
is_ok(72 == $ob->is_stty_susp);			# 108

is_ok($echoe_1 != $ob->stty_echoe);		# 109
is_ok($echok_1 != $ob->stty_echok);		# 110
is_ok(1 == $ob->stty_echonl);			# 111

is_ok(1 == $ob->stty_istrip);			# 112
is_ok(1 == $ob->stty_icrnl);			# 113
is_ok(1 == $ob->stty_igncr);			# 114
is_ok(1 == $ob->stty_inlcr);			# 115
is_ok(1 == $ob->stty_opost);			# 116
is_ok(1 == $ob->stty_isig);			# 117
is_ok(1 == $ob->stty_icanon);			# 118
is_ok(1 == $ob->stty_echo);			# 119

if ($naptime) {
    print "++++ page break\n";
    sleep $naptime;
}

print "Restore all the parameters\n";

is_ok ($ob->restart($cfgfile));			# 120

#### 121 - 72: Check Port Capabilities Match Original

is_ok ($ob->baudrate == 9600);			# 121
is_ok ($ob->parity eq "none");			# 122
is_ok ($ob->databits == 8);			# 123
is_ok ($ob->stopbits == 1);			# 124
is_ok ($ob->handshake eq "none");		# 125
is_ok ($ob->read_const_time == 0);		# 126
is_ok ($ob->read_char_time == 0);		# 127
is_ok ($ob->alias eq "AltPort");		# 128
is_zero (scalar $ob->parity_enable);		# 129
is_ok ($ob->user_msg == 1);			# 130
is_ok ($ob->error_msg == 1);			# 131

is_ok($vstart_1 == $ob->is_xon_char);		# 132
is_ok($vstop_1 == $ob->is_xoff_char);		# 133
is_ok($vintr_1 == $ob->is_stty_intr);		# 134
is_ok($vquit_1 == $ob->is_stty_quit);		# 135
is_ok($veof_1 == $ob->is_stty_eof);		# 136
is_ok($veol_1 == $ob->is_stty_eol);		# 137
is_ok($verase_1 == $ob->is_stty_erase);		# 138
is_ok($vkill_1 == $ob->is_stty_kill);		# 139
is_ok($vsusp_1 == $ob->is_stty_susp);		# 140

if ($naptime) {
    print "++++ page break\n";
    sleep $naptime;
}

is_ok(0 == $ob->stty_echo);			# 141
is_ok($echoe_1 == $ob->stty_echoe);		# 142
is_ok($echok_1 == $ob->stty_echok);		# 143
is_ok(0 == $ob->stty_echonl);			# 144
is_ok(0 == $ob->stty_istrip);			# 145
is_ok(0 == $ob->stty_icrnl);			# 146
is_ok(0 == $ob->stty_igncr);			# 147
is_ok(0 == $ob->stty_inlcr);			# 148
is_ok(0 == $ob->stty_opost);			# 149
is_ok(0 == $ob->stty_isig);			# 150
is_ok(0 == $ob->stty_icanon);			# 151

# 152 - 154: "Instant" return for read(0)

is_ok (2000 == $ob->read_const_time(2000));	# 152
$tick=$ob->get_tick_count;
($in, $in2) = $ob->read(0);
$tock=$ob->get_tick_count;

is_bad (defined $in);				# 153
$out=$tock - $tick;
is_ok ($out < 100);				# 154
print "<0> elapsed time=$out\n";

### 155 - 170: Defaults for lookfor

@opts = $ob->are_match;
is_ok ($#opts == 0);				# 155
is_ok ($opts[0] eq "\n");			# 156
is_ok ($ob->lookclear == 1);			# 157
is_ok ($ob->lookfor eq "");			# 158
is_ok ($ob->streamline eq "");			# 159

if ($naptime) {
    print "++++ page break\n";
    sleep $naptime;
}

($in, $out, $patt, $instead) = $ob->lastlook;
is_ok ($in eq "");				# 160
is_ok ($out eq "");				# 161
is_ok ($patt eq "");				# 162
is_ok ($instead eq "");				# 163
is_ok ($ob->matchclear eq "");			# 164

is_ok ("" eq $ob->output_record_separator);		# 165
is_ok ("" eq $ob->output_record_separator("ab"));	# 166
is_ok ("ab" eq $ob->output_record_separator);		# 167
is_ok ("ab" eq $ob->output_record_separator(""));	# 168
is_ok ("" eq $ob->output_record_separator);		# 169
is_ok ("" eq $ob->output_field_separator);		# 170

@opts = $ob->are_match ("END","Bye");
is_ok ($#opts == 1);				# 171
is_ok ($opts[0] eq "END");			# 172
is_ok ($opts[1] eq "Bye");			# 173
is_ok ($ob->lookclear("Good Bye, Hello") == 1);	# 174
is_ok (1);					# 175
is_ok ($ob->lookfor eq "Good ");		# 176

($in, $out, $patt, $instead) = $ob->lastlook;
is_ok ($in eq "Bye");				# 177
is_ok ($out eq ", Hello");			# 178
is_ok ($patt eq "Bye");				# 179
is_ok ($instead eq "");				# 180
is_ok ($ob->matchclear eq "Bye");		# 181

if ($naptime) {
    print "++++ page break\n";
    sleep $naptime;
}

is_ok ($ob->matchclear eq "");			# 182
is_ok ($ob->lookclear("Bye, Bye, Love. The END has come") == 1);	# 183
is_ok ($ob->lookfor eq "");			# 184

($in, $out, $patt, $instead) = $ob->lastlook;
is_ok ($in eq "Bye");				# 185
is_ok ($out eq ", Bye, Love. The END has come");# 186

is_ok ($patt eq "Bye");				# 187
is_ok ($instead eq "");				# 188
is_ok ($ob->matchclear eq "Bye");		# 189

($in, $out, $patt, $instead) = $ob->lastlook;
is_ok ($in eq "");				# 190
is_ok ($out eq ", Bye, Love. The END has come");# 191
is_ok ($patt eq "Bye");				# 192
is_ok ($instead eq "");				# 193

is_ok ($ob->lookfor eq ", ");			# 194
($in, $out, $patt, $instead) = $ob->lastlook;
is_ok ($in eq "Bye");				# 195
is_ok ($out eq ", Love. The END has come");	# 196
is_ok ($patt eq "Bye");				# 197
is_ok ($instead eq "");				# 198
is_ok ($ob->matchclear eq "Bye");		# 199

is_ok ($ob->lookfor eq ", Love. The ");		# 200
($in, $out, $patt, $instead) = $ob->lastlook;
is_ok ($in eq "END");				# 201
is_ok ($out eq " has come");			# 202
is_ok ($patt eq "END");				# 203

if ($naptime) {
    print "++++ page break\n";
    sleep $naptime;
}

is_ok ($instead eq "");				# 204
is_ok ($ob->matchclear eq "END");		# 205
is_ok ($ob->lookfor eq "");			# 206
is_ok ($ob->matchclear eq "");			# 207

($in, $out, $patt, $instead) = $ob->lastlook;
is_ok ($in eq "");				# 208
is_ok ($patt eq "");				# 209
is_ok ($instead eq " has come");		# 210

is_ok ($ob->lookclear("First\nSecond\nThe END") == 1);	# 211
is_ok ($ob->lookfor eq "First\nSecond\nThe ");	# 212
($in, $out, $patt, $instead) = $ob->lastlook;
is_ok ($in eq "END");				# 213
is_ok ($out eq "");				# 214
is_ok ($patt eq "END");				# 215
is_ok ($instead eq "");				# 216

is_ok ($ob->lookclear("Good Bye, Hello") == 1);	# 217
is_ok ($ob->streamline eq "Good ");		# 218

($in, $out, $patt, $instead) = $ob->lastlook;
is_ok ($in eq "Bye");				# 219
is_ok ($out eq ", Hello");			# 220
is_ok ($patt eq "Bye");				# 221
is_ok ($instead eq "");				# 222

is_ok ($ob->lookclear("Bye, Bye, Love. The END has come") == 1);	# 223
is_ok ($ob->streamline eq "");			# 224

($in, $out, $patt, $instead) = $ob->lastlook;
is_ok ($in eq "Bye");				# 225

if ($naptime) {
    print "++++ page break\n";
    sleep $naptime;
}

is_ok ($out eq ", Bye, Love. The END has come");# 226
is_ok ($patt eq "Bye");				# 227
is_ok ($instead eq "");				# 228
is_ok ($ob->matchclear eq "Bye");		# 229

($in, $out, $patt, $instead) = $ob->lastlook;
is_ok ($in eq "");				# 230
is_ok ($out eq ", Bye, Love. The END has come");# 231
is_ok ($patt eq "Bye");				# 232
is_ok ($instead eq "");				# 233

is_ok ($ob->streamline eq ", ");		# 234
($in, $out, $patt, $instead) = $ob->lastlook;
is_ok ($in eq "Bye");				# 235
is_ok ($out eq ", Love. The END has come");	# 236
is_ok ($patt eq "Bye");				# 237
is_ok ($instead eq "");				# 238
is_ok ($ob->matchclear eq "Bye");		# 239

is_ok ($ob->streamline eq ", Love. The ");	# 240
($in, $out, $patt, $instead) = $ob->lastlook;
is_ok ($in eq "END");				# 241
is_ok ($out eq " has come");			# 242
is_ok ($patt eq "END");				# 243
is_ok ($instead eq "");				# 244
is_ok ($ob->matchclear eq "END");		# 245
is_ok ($ob->streamline eq "");			# 246
is_ok ($ob->matchclear eq "");			# 247

if ($naptime) {
    print "++++ page break\n";
    sleep $naptime;
}

($in, $out, $patt, $instead) = $ob->lastlook;
is_ok ($in eq "");				# 248
is_ok ($patt eq "");				# 249
is_ok ($instead eq " has come");		# 250

is_ok ($ob->lookclear("First\nSecond\nThe END") == 1);	# 251
is_ok ($ob->streamline eq "First\nSecond\nThe ");	# 252
($in, $out, $patt, $instead) = $ob->lastlook;
is_ok ($in eq "END");				# 253
is_ok ($out eq "");				# 254
is_ok ($patt eq "END");				# 255
is_ok ($instead eq "");				# 256

# 257 - 303 Test and Normal "lookclear"

@opts = $ob->are_match("\n");
is_ok ($opts[0] eq "\n");			# 257
is_ok ($ob->lookclear("Before\nAfter") == 1);	# 258
is_ok ($ob->lookfor eq "Before");		# 259

($in, $out, $patt, $instead) = $ob->lastlook;
is_ok ($in eq "\n");				# 260
is_ok ($out eq "After");			# 261
is_ok ($patt eq "\n");				# 262
is_ok ($instead eq "");				# 263

is_ok ($ob->lookfor eq "");			# 264
($in, $out, $patt, $instead) = $ob->lastlook;
is_ok ($in eq "");				# 265
is_ok ($patt eq "");				# 266
is_ok ($instead eq "After");			# 267

@opts = $ob->are_match ("B*e","ab..ef","-re","12..56","END");
is_ok ($#opts == 4);				# 268
is_ok ($opts[2] eq "-re");			# 269

if ($naptime) {
    print "++++ page break\n";
    sleep $naptime;
}

is_ok ($ob->lookclear("Good Bye, the END, Hello") == 1);	# 270
is_ok ($ob->lookfor eq "Good Bye, the ");	# 271

($in, $out, $patt, $instead) = $ob->lastlook;
is_ok ($in eq "END");				# 272
is_ok ($out eq ", Hello");			# 273
is_ok ($patt eq "END");				# 274
is_ok ($instead eq "");				# 275

is_ok ($ob->lookclear("Good Bye, the END, Hello") == 1);	# 276
is_ok ($ob->streamline eq "Good Bye, the ");	# 277

($in, $out, $patt, $instead) = $ob->lastlook;
is_ok ($in eq "END");				# 278
is_ok ($out eq ", Hello");			# 279
is_ok ($patt eq "END");				# 280
is_ok ($instead eq "");				# 281

is_ok ($ob->lookclear("Good B*e, abcdef, 123456") == 1);	# 282
is_ok ($ob->lookfor eq "Good ");		# 283

($in, $out, $patt, $instead) = $ob->lastlook;
is_ok ($in eq "B*e");				# 284
is_ok ($out eq ", abcdef, 123456");		# 285
is_ok ($patt eq "B*e");				# 286
is_ok ($instead eq "");				# 287

is_ok ($ob->lookfor eq ", abcdef, ");		# 288

($in, $out, $patt, $instead) = $ob->lastlook;
is_ok ($in eq "123456");			# 289
is_ok ($out eq "");				# 290

if ($naptime) {
    print "++++ page break\n";
    sleep $naptime;
}

is_ok ($patt eq "12..56");			# 291
is_ok ($instead eq "");				# 292
is_ok ($ob->lookclear("Good B*e, abcdef, 123456") == 1);	# 293
is_ok ($ob->streamline eq "Good ");		# 294

($in, $out, $patt, $instead) = $ob->lastlook;
is_ok ($in eq "B*e");				# 295
is_ok ($out eq ", abcdef, 123456");		# 296
is_ok ($patt eq "B*e");				# 297
is_ok ($instead eq "");				# 298

is_ok ($ob->streamline eq ", abcdef, ");	# 299

($in, $out, $patt, $instead) = $ob->lastlook;
is_ok ($in eq "123456");			# 300
is_ok ($out eq "");				# 301
is_ok ($patt eq "12..56");			# 302
is_ok ($instead eq "");				# 303

@necessary_param = Device::SerialPort->set_test_mode_active(0);

is_bad ($ob->lookclear("Good\nBye"));		# 304
is_ok ($ob->lookfor eq "");			# 305
($in, $out, $patt, $instead) = $ob->lastlook;
is_ok ($in eq "");				# 306
is_ok ($out eq "");				# 307
is_ok ($patt eq "");				# 308

is_ok ("" eq $ob->output_field_separator(":"));	# 309
is_ok (":" eq $ob->output_field_separator);	# 310
is_ok (":" eq $ob->output_field_separator(""));	# 311
is_ok ("" eq $ob->output_field_separator);	# 312

is_ok ($ob->close);				# 313
undef $ob;

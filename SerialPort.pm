# Note: This is a POSIX version of the Win32::Serialport module
#       ported by Joe Doss 
#       for use with the MisterHouse program

# Prototypes for ioctl constants do not match POSIX constants
# so put them into implausible namespace and call them there

package SerialJunk;

use vars qw($ioctl_ok);
eval { require 'asm/termios.ph'; };
if ($@) {
   $ioctl_ok = 0;
##   print "error message: $@\n"; ## DEBUG ##
}
else {
   $ioctl_ok = 1;
}

package Device::SerialPort;

use POSIX qw(:termios_h);
use IO::Handle;

use vars qw($bitset $bitclear $rtsout $dtrout);
if ($SerialJunk::ioctl_ok) {
    $bitset = &SerialJunk::TIOCMBIS;
    $bitclear = &SerialJunk::TIOCMBIC;
    $rtsout = pack('L', &SerialJunk::TIOCM_RTS);
    $dtrout = pack('L', &SerialJunk::TIOCM_DTR);
}
else {
    $bitset = 0;
    $bitclear = 0;
    $rtsout = pack('L', 0);
    $dtrout = pack('L', 0);
}

use Carp;
use strict;

use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
$VERSION = '0.05';

require Exporter;

@ISA = qw(Exporter);
# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

@EXPORT= qw();
@EXPORT_OK= qw();
%EXPORT_TAGS = (PARAM	=> [qw( LONGsize	SHORTsize	OS_Error
				nocarp		yes_true )]);

Exporter::export_ok_tags('PARAM');

$EXPORT_TAGS{ALL} = \@EXPORT_OK;

#### Package variable declarations ####

# Linux-specific constant for Hardware Handshaking
sub CRTSCTS { 020000000000 }

# Linux-specific Baud-Rates
sub B57600  { 0010001 }
sub B115200 { 0010002 }
sub B230400 { 0010003 }
sub B460800 { 0010004 }

my %c_cc_fields = (
		   VEOF     => &POSIX::VEOF,
		   VEOL     => &POSIX::VEOL,
		   VERASE   => &POSIX::VERASE,
		   VINTR    => &POSIX::VINTR,
		   VKILL    => &POSIX::VKILL,
		   VQUIT    => &POSIX::VQUIT,
		   VSUSP    => &POSIX::VSUSP,
		   VSTART   => &POSIX::VSTART,
		   VSTOP    => &POSIX::VSTOP,
		   VMIN     => &POSIX::VMIN,
		   VTIME    => &POSIX::VTIME,
		   );

my %bauds = (
	     0        => B0,
	     50       => B50,
	     75       => B75,
	     110      => B110,
	     134      => B134,
	     150      => B150,
	     200      => B200,
	     300      => B300,
	     600      => B600,
	     1200     => B1200,
	     1800     => B1800,
	     2400     => B2400,
	     4800     => B4800,
	     9600     => B9600,
	     19200    => B19200,
	     38400    => B38400,
	     # These are Linux-specific
	     57600    => B57600,
	     115200   => B115200,
	     230400   => B230400,
	     460800   => B460800,
	     );

my $Babble = 0;
my $testactive = 0;	# test mode active

my @Yes_resp = (
		"YES", "Y",
		"ON",
		"TRUE", "T",
		"1"
		);

my @binary_opt = ( 0, 1 );
my @byte_opt = (0, 255);


## my $null=[];
my $null=0;
my $zero=0;

# Preloaded methods go here.

sub GetTickCount {
	# clone of Win32::GetTickCount - probably same 49 day problem
    my ($real2, $user2, $system2, $cuser2, $csystem2) = POSIX::times();
    $real2 *= 10.0;
    ## printf "real2 = %8.0f\n", $real2;
    return int $real2;
}

sub SHORTsize { 0xffff; }	# mostly for AltPort test
sub LONGsize { 0xffffffff; }	# mostly for AltPort test

sub OS_Error { print "Device::SerialPort OS_Error\n"; }

    # test*.pl only - suppresses default messages
sub set_test_mode_active {
    return unless (@_ == 2);
    $testactive = $_[1];     # allow "off"
    return 1;
}

sub nocarp { return $testactive }

sub yes_true {
    my $choice = uc shift;
    my $ans = 0;
    foreach (@Yes_resp) { $ans = 1 if ( $choice eq $_ ) }
    return $ans;
}

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self  = {};
    my $ok    = 0;		# API return value

    my $item = 0;


    $self->{NAME}     = shift;

                                # bbw change: 03/10/99
                                #  - Add quiet option so we can do a 'test'
                                #    new (print no error if fail)
                                # 
    my $quiet = shift;

    unless ($quiet or ($bitset && $bitclear && $rtsout && $dtrout) ) {
       nocarp or warn "disabling ioctl methods - constants not found\n";
    }

    my $lockfile = shift;
    if ($lockfile) {
        $self->{LOCK} = $lockfile;
	my $lockf = POSIX::open($self->{LOCK}, 
				    &POSIX::O_WRONLY |
				    &POSIX::O_CREAT |
				    &POSIX::O_NOCTTY |
				    &POSIX::O_EXCL);
	unless (defined $lockf) {
            unless ($quiet) {
                nocarp or carp "can't open lockfile: $self->{LOCK}\n"; 
            }
            return 0 if ($quiet);
	    return;
	}
	my $pid = "$$\n";
	$ok = POSIX::write($lockf, $pid, length $pid);
	my $ok2 = POSIX::close($lockf);
	return unless ($ok && (defined $ok2));
	sleep 2;	# wild guess for Version 0.05
    }
    else {
        $self->{LOCK} = "";
    }

    $self->{FD}= POSIX::open($self->{NAME}, 
				    &POSIX::O_RDWR |
				    &POSIX::O_NOCTTY |
				    &POSIX::O_NONBLOCK);

    unless (defined $self->{FD}) { $self->{FD} = -1; }
    unless ($self->{FD} >= 1) {
        unless ($quiet) {
            nocarp or carp "can't open device: $self->{NAME}\n"; 
        }
        $self->{FD} = -1;
        if ($self->{LOCK}) {
	    $ok = unlink $self->{LOCK};
	    unless ($ok or $quiet) {
                nocarp or carp "can't remove lockfile: $self->{LOCK}\n"; 
    	    }
            $self->{LOCK} = "";
        }
        return 0 if ($quiet);
	return;
    }

    $self->{TERMIOS} = POSIX::Termios->new();

    # a handle object for ioctls: read-only ok
    $self->{HANDLE} = new_from_fd IO::Handle ($self->{FD}, "r");
    
    # get the current attributes
    $ok = $self->{TERMIOS}->getattr($self->{FD});

    unless ( $ok ) {
        carp "can't getattr";
        undef $self;
        return undef;
    }

    # save the original values
    $self->{"_CFLAG"} = $self->{TERMIOS}->getcflag();
    $self->{"_IFLAG"} = $self->{TERMIOS}->getiflag();
    $self->{"_ISPEED"} = $self->{TERMIOS}->getispeed();
    $self->{"_LFLAG"} = $self->{TERMIOS}->getlflag();
    $self->{"_OFLAG"} = $self->{TERMIOS}->getoflag();
    $self->{"_OSPEED"} = $self->{TERMIOS}->getospeed();

    foreach $item (keys %c_cc_fields) {
	$self->{"_$item"} = $self->{TERMIOS}->getcc($c_cc_fields{$item});
    }

    # copy the original values into "current" values
    foreach $item (keys %c_cc_fields) {
	$self->{"C_$item"} = $self->{"_$item"};
    }

    $self->{"C_CFLAG"} = $self->{"_CFLAG"};
    $self->{"C_IFLAG"} = $self->{"_IFLAG"};
    $self->{"C_ISPEED"} = $self->{"_ISPEED"};
    $self->{"C_LFLAG"} = $self->{"_LFLAG"};
    $self->{"C_OFLAG"} = $self->{"_OFLAG"};
    $self->{"C_OSPEED"} = $self->{"_OSPEED"};

    # Finally, default to "raw" mode for this package
    $self->{"C_IFLAG"} &= ~(IGNBRK|BRKINT|PARMRK|ISTRIP|INLCR|IGNCR|ICRNL|IXON);
    $self->{"C_OFLAG"} &= ~OPOST;
    $self->{"C_LFLAG"} &= ~(ECHO|ECHONL|ICANON|ISIG|IEXTEN);
    $self->{"C_CFLAG"} &= ~(CSIZE|PARENB);
    $self->{"C_CFLAG"} |= (CS8|CLOCAL);
    &write_settings($self);

    $self->{ALIAS} = $self->{NAME};	# so "\\.\+++" can be changed

    # "private" data
    $self->{"_DEBUG"}    	= 0;
    $self->{U_MSG}     		= 0;
    $self->{E_MSG}     		= 0;
    $self->{RCONST}   		= 0;
    $self->{RTOT}   		= 0;

    bless ($self, $class);
    return $self;
}

sub write_settings {
    my $self = shift;
    my $item;

    # put current values into Termios structure
    $self->{TERMIOS}->setcflag($self->{"C_CFLAG"});
    $self->{TERMIOS}->setiflag($self->{"C_IFLAG"});
    $self->{TERMIOS}->setispeed($self->{"C_ISPEED"});
    $self->{TERMIOS}->setlflag($self->{"C_LFLAG"});
    $self->{TERMIOS}->setoflag($self->{"C_OFLAG"});
    $self->{TERMIOS}->setospeed($self->{"C_OSPEED"});

    foreach $item (keys %c_cc_fields) {
	$self->{TERMIOS}->setcc($c_cc_fields{$item}, $self->{"C_$item"});
    }

    $self->{TERMIOS}->setattr($self->{FD}, &POSIX::TCSANOW);

    if ($Babble) {
        print "writing settings to $self->{ALIAS}\n";
    }
    1;
}

# true/false capabilities (read only)
# currently just constants in the POSIX case

sub can_baud			{ return 1; }
sub can_databits		{ return 1; }
sub can_stopbits		{ return 1; }
sub can_dtrdsr			{ return 0; } # currently
sub can_handshake		{ return 1; }
sub can_parity_check		{ return 1; }
sub can_parity_config		{ return 1; }
sub can_parity_enable		{ return 1; }
sub can_rlsd			{ return 0; } # currently
sub can_16bitmode		{ return 0; } # Win32-specific
sub is_rs232			{ return 1; }
sub is_modem			{ return 0; } # Win32-specific
sub can_rtscts			{ return 1; }
sub can_xonxoff			{ return 1; }
sub can_xon_char		{ return 0; } # use stty
sub can_spec_char		{ return 0; } # use stty
sub can_interval_timeout	{ return 0; } # currently
sub can_total_timeout		{ return 1; } # currently
sub binary			{ return 1; }
  
sub reset_error			{ return 0; } # for compatibility

sub can_ioctl {
    return 0 unless ($bitset && $bitclear && $rtsout && $dtrout);
    return 1;
}
  
sub handshake {
    my $self = shift;
    
    if (@_) {
	if ( $_[0] eq "none" ) {
	    $self->{"C_IFLAG"} &= ~(IXON | IXOFF);
	    $self->{"C_CFLAG"} &= ~CRTSCTS;
	}
	elsif ( $_[0] eq "xoff" ) {
	    $self->{"C_IFLAG"} |= (IXON | IXOFF);
	    $self->{"C_CFLAG"} &= ~CRTSCTS;
	}
	elsif ( $_[0] eq "rts" ) {
	    $self->{"C_IFLAG"} &= ~(IXON | IXOFF);
	    $self->{"C_CFLAG"} |= CRTSCTS;
	}
        else {
            if ($self->{U_MSG} or $Babble) {
                carp "Can't set handshake on $self->{ALIAS}";
            }
	    return;
        }
	write_settings($self);
    }
    if (wantarray) { return ("none", "xoff", "rts"); }
    my $mask = (IXON|IXOFF);
    return "xoff" if ($mask == ($self->{"C_IFLAG"} & $mask));
    return "rts" if ($self->{"C_CFLAG"} & CRTSCTS);
    return "none";
}

sub baudrate {
    my $self = shift;
    my $item = 0;

    if (@_) {
        if (defined $bauds{$_[0]}) {
            $self->{"C_OSPEED"} = $bauds{$_[0]};
            $self->{"C_ISPEED"} = $bauds{$_[0]};
            write_settings($self);
        }
        else {
            if ($self->{U_MSG} or $Babble) {
                carp "Can't set baudrate on $self->{ALIAS}";
            }
	    return undef;
        }
    }
    if (wantarray) { return (keys %bauds); }
    foreach $item (keys %bauds) {
	return $item if ($bauds{$item} == $self->{"C_OSPEED"});
    }
    return undef;
}

sub parity {
    my $self = shift;
    if (@_) {
	if ( $_[0] eq "none" ) {
	    $self->{"C_IFLAG"} &= ~INPCK;
	    $self->{"C_CFLAG"} &= ~PARENB;
	}
	elsif ( $_[0] eq "odd" ) {
	    $self->{"C_IFLAG"} |= INPCK;
	    $self->{"C_CFLAG"} |= (PARENB|PARODD);
	}
	elsif ( $_[0] eq "even" ) {
	    $self->{"C_IFLAG"} |= INPCK;
	    $self->{"C_CFLAG"} |= PARENB;
	    $self->{"C_CFLAG"} &= ~PARODD;
	}
        else {
            if ($self->{U_MSG} or $Babble) {
                carp "Can't set parity on $self->{ALIAS}";
            }
	    return;
        }
	write_settings($self);
    }
    if (wantarray) { return ("none", "odd", "even"); }
    return "none" unless ($self->{"C_IFLAG"} & INPCK);
    my $mask = (PARENB|PARODD);
    return "odd"  if ($mask == ($self->{"C_CFLAG"} & $mask));
    $mask = (PARENB);
    return "even" if ($mask == ($self->{"C_CFLAG"} & $mask));
    return "none";
}

sub databits {
    my $self = shift;
    if (@_) {
	if ( $_[0] == 8 ) {
	    $self->{"C_CFLAG"} &= ~CSIZE;
	    $self->{"C_CFLAG"} |= CS8;
	}
	elsif ( $_[0] == 7 ) {
	    $self->{"C_CFLAG"} &= ~CSIZE;
	    $self->{"C_CFLAG"} |= CS7;
	}
	elsif ( $_[0] == 6 ) {
	    $self->{"C_CFLAG"} &= ~CSIZE;
	    $self->{"C_CFLAG"} |= CS6;
	}
	elsif ( $_[0] == 5 ) {
	    $self->{"C_CFLAG"} &= ~CSIZE;
	    $self->{"C_CFLAG"} |= CS5;
	}
        else {
            if ($self->{U_MSG} or $Babble) {
                carp "Can't set databits on $self->{ALIAS}";
            }
	    return;
        }
	write_settings($self);
    }
    if (wantarray) { return (5, 6, 7, 8); }
    my $mask = ($self->{"C_CFLAG"} & CSIZE);
    return 8 if ($mask == CS8);
    return 7 if ($mask == CS7);
    return 6 if ($mask == CS6);
    return 5;
}

sub stopbits {
    my $self = shift;
    if (@_) {
	if ( $_[0] == 2 ) {
	    $self->{"C_CFLAG"} |= CSTOPB;
	}
	elsif ( $_[0] == 1 ) {
	    $self->{"C_CFLAG"} &= ~CSTOPB;
	}
        else {
            if ($self->{U_MSG} or $Babble) {
                carp "Can't set stopbits on $self->{ALIAS}";
            }
	    return;
        }
	write_settings($self);
    }
    if (wantarray) { return (1, 2); }
    return 2 if ($self->{"C_CFLAG"} & CSTOPB);
    return 1;
}

sub alias {
    my $self = shift;
    if (@_) { $self->{ALIAS} = shift; }	# should return true for legal names
    return $self->{ALIAS};
}

sub buffers {
    my $self = shift;
    if (@_) { return unless (@_ == 2); }
    return wantarray ?  (4096, 4096) : 1;
}

sub read_const_time {
    my $self = shift;
    if (@_) {
	$self->{RCONST} = (shift)/1000; # milliseconds -> select_time
    }
    return $self->{RCONST}*1000;
}

sub read_char_time {
    my $self = shift;
    if (@_) {
	$self->{RTOT} = (shift)/1000; # milliseconds -> select_time
    }
    return $self->{RTOT}*1000;
}

sub read {
    return undef unless (@_ == 2);
    my $self = shift;
    my $wanted = shift;
    my $result = "";
    my $ok     = 0;
    return undef unless ($wanted > 0);

    if ($self->{"C_VMIN"} != $wanted) {
	$self->{"C_VMIN"} = $wanted;
        write_settings($self);
    }
    my $rin = "";
    vec($rin, $self->{FD}, 1) = 1;
    my $ein = $rin;
    my $tin = $self->{RCONST} + ($wanted * $self->{RTOT});
    my $rout;
    my $wout;
    my $eout;
    my $tout;
    my $ready = select($rout=$rin, $wout=undef, $eout=$ein, $tout=$tin);

    my $got = POSIX::read ($self->{FD}, $result, $wanted);

    unless (defined $got) { $got = -1; }
    if ($got == -1) {
	return (0,"") if (&POSIX::EAGAIN == ($ok = POSIX::errno()));
	carp "Error #$ok in Device::SerialPort::read"
    }

    print "read=$got, result=..$result..\n" if ($Babble);
    return ($got, $result);
}

sub input {
    return undef unless (@_ == 1);
    my $self = shift;
    my $ok     = 0;
    my $result = "";
    my $wanted = 4096;

    if ( $self->{"C_VMIN"} ) {
	$self->{"C_VMIN"} = 0;
	write_settings($self);
    }

    my $got = POSIX::read ($self->{FD}, $result, $wanted);

    unless (defined $got) { $got = -1; }
    if ($got == -1) {
	return "" if (&POSIX::EAGAIN == ($ok = POSIX::errno()));
	carp "Error #$ok in Device::SerialPort::input"
    }
    
    return $result;
}

sub write {
    return undef unless (@_ == 2);
    my $self = shift;
    my $wbuf = shift;
    my $ok;

    return 0 if ($wbuf eq "");
    my $lbuf = length ($wbuf);

    my $written = POSIX::write ($self->{FD}, $wbuf, $lbuf);

    return $written;
}

sub write_drain {
    my $self = shift;
    return undef if (@_);

  POSIX::tcdrain($self->{FD});
    return 1;
}

sub purge_all {
    my $self = shift;
    return undef if (@_);

  POSIX::tcflush($self->{FD}, TCIOFLUSH);
    return 1;
}

sub purge_rx {
    my $self = shift;
    return undef if (@_);

  POSIX::tcflush($self->{FD}, TCIFLUSH);
    return 1;
}

sub purge_tx {
    my $self = shift;
    return undef if (@_);

  POSIX::tcflush($self->{FD}, TCOFLUSH);
    return 1;
}

sub buffer_max {
    my $self = shift;
    if (@_) {return undef; }
    return (4096, 4096);
}

  # true/false parameters

sub user_msg {
    my $self = shift;
    if (@_) { $self->{U_MSG} = yes_true ( shift ) }
    return wantarray ? @binary_opt : $self->{U_MSG};
}

sub error_msg {
    my $self = shift;
    if (@_) { $self->{E_MSG} = yes_true ( shift ) }
    return wantarray ? @binary_opt : $self->{E_MSG};
}

sub parity_enable {
    my $self = shift;
    if (@_) {
	if ( yes_true( shift ) ) {
	    $self->{"C_IFLAG"} |= PARMRK;
	    $self->{"C_CFLAG"} |= PARENB;
        } else {
	    $self->{"C_IFLAG"} &= ~PARMRK;
	    $self->{"C_CFLAG"} &= ~PARENB;
	}
	write_settings($self);
    }
    return wantarray ? @binary_opt : ($self->{"C_CFLAG"} & PARENB);
}

sub dtr_active {
    return unless (@_ == 2);
    return unless ($bitset && $bitclear && $dtrout);
    my $self = shift;
    my $onoff = shift;
    # returns ioctl result
    if ($onoff) {
        ioctl($self->{HANDLE}, $bitset, $dtrout);
    }
    else {
        ioctl($self->{HANDLE}, $bitclear, $dtrout);
    }
}

sub rts_active {
    return unless (@_ == 2);
    return unless ($bitset && $bitclear && $rtsout);
    my $self = shift;
    my $onoff = shift;
    # returns ioctl result
    if ($onoff) {
        ioctl($self->{HANDLE}, $bitset, $rtsout);
    }
    else {
        ioctl($self->{HANDLE}, $bitclear, $rtsout);
    }
}

sub pulse_break_on {
    return unless (@_ == 2);
    my $self = shift;
    my $delay = (shift)/1000;
    my $length = 0;
    my $ok = POSIX::tcsendbreak($self->{FD}, $length);
    warn "could not pulse break on" unless ($ok);
    select (undef, undef, undef, $delay);
    return $ok;
}

sub pulse_rts_on {
    return unless (@_ == 2);
    return unless ($bitset && $bitclear && $rtsout);
    my $self = shift;
    my $delay = (shift)/1000;
    $self->rts_active(1) or warn "could not pulse rts on";
##    print "rts on\n"; ## DEBUG
    select (undef, undef, undef, $delay);
    $self->rts_active(0) or warn "could not restore from rts on";
##    print "rts_off\n"; ## DEBUG
    select (undef, undef, undef, $delay);
    1;
}

sub pulse_dtr_on {
    return unless (@_ == 2);
    return unless ($bitset && $bitclear && $dtrout);
    my $self = shift;
    my $delay = (shift)/1000;
    $self->dtr_active(1) or warn "could not pulse dtr on";
##    print "dtr on\n"; ## DEBUG
    select (undef, undef, undef, $delay);
    $self->dtr_active(0) or warn "could not restore from dtr on";
##    print "dtr_off\n"; ## DEBUG
    select (undef, undef, undef, $delay);
    1;
}

sub pulse_rts_off {
    return unless (@_ == 2);
    return unless ($bitset && $bitclear && $rtsout);
    my $self = shift;
    my $delay = (shift)/1000;
    $self->rts_active(0) or warn "could not pulse rts off";
##    print "rts off\n"; ## DEBUG
    select (undef, undef, undef, $delay);
    $self->rts_active(1) or warn "could not restore from rts off";
##    print "rts on\n"; ## DEBUG
    select (undef, undef, undef, $delay);
    1;
}

sub pulse_dtr_off {
    return unless (@_ == 2);
    return unless ($bitset && $bitclear && $dtrout);
    my $self = shift;
    my $delay = (shift)/1000;
    $self->dtr_active(0) or warn "could not pulse dtr off";
##    print "dtr off\n"; ## DEBUG
    select (undef, undef, undef, $delay);
    $self->dtr_active(1) or warn "could not restore from dtr off";
##    print "dtr on\n"; ## DEBUG
    select (undef, undef, undef, $delay);
    1;
}

sub debug {
    my $self = shift;
    if (ref($self))  {
        if (@_) { $self->{"_DEBUG"} = yes_true ( shift ); }
        if (wantarray) { return @binary_opt; }
        else {
	    my $tmp = $self->{"_DEBUG"};
            nocarp || carp "Debug level: $self->{ALIAS} = $tmp";
            return $self->{"_DEBUG"};
        }
    } else {
        if (@_) { $Babble = yes_true ( shift ); }
        if (wantarray) { return @binary_opt; }
        else {
            nocarp || carp "Debug Class = $Babble";
            return $Babble;
        }
    }
}

sub close {
    my $self = shift;
    my $ok = undef;
    my $item;

    return unless (defined $self->{NAME});

    if ($Babble) {
        carp "Closing $self " . $self->{ALIAS};
    }
    if ($self->{FD}) {
        purge_all ($self);

	# copy the original values into "current" values
	foreach $item (keys %c_cc_fields) {
	    $self->{"C_$item"} = $self->{"_$item"};
	}

	$self->{"C_CFLAG"} = $self->{"_CFLAG"};
	$self->{"C_IFLAG"} = $self->{"_IFLAG"};
	$self->{"C_ISPEED"} = $self->{"_ISPEED"};
	$self->{"C_LFLAG"} = $self->{"_LFLAG"};
	$self->{"C_OFLAG"} = $self->{"_OFLAG"};
	$self->{"C_OSPEED"} = $self->{"_OSPEED"};
	
	write_settings($self);

        $ok = POSIX::close($self->{FD});
	# also closes $self->{HANDLE}

	$self->{FD} = undef;
    }
    $self->{NAME} = undef;
    $self->{ALIAS} = undef;
    return unless ($ok);
    1;
}

##### tied FileHandle support
 
# DESTROY this
#      As with the other types of ties, this method will be called when the
#      tied handle is about to be destroyed. This is useful for debugging and
#      possibly cleaning up.

sub DESTROY {
    my $ok;
    my $self = shift;

    if ($self->{LOCK}) {
	$ok = unlink $self->{LOCK};
	unless ($ok) {
            nocarp or carp "can't remove lockfile: $self->{LOCK}\n"; 
	}
        $self->{LOCK} = "";
    }

    return unless (defined $self->{NAME});

    if ($self->{"_DEBUG"}) {
        carp "Destroying $self->{NAME}";
    }
    $self->close;
}
 
sub TIEHANDLE {
    my $proto = shift;
    my $class = ref($proto) || $proto;

    return unless (@_);

    my $self = new($class, shift);
##    my $self = start($class, shift);
    return $self;
}
 
# WRITE this, LIST
#      This method will be called when the handle is written to via the
#      syswrite function.

sub WRITE {
    return if (@_ < 3);
    my $self = shift;
    my $buf = shift;
    my $len = shift;
    my $offset = 0;
    if (@_) { $offset = shift; }
    my $out2 = substr($buf, $offset, $len);
    return unless ($self->PRINT($out2));
    return length($out2);
}

# PRINT this, LIST
#      This method will be triggered every time the tied handle is printed to
#      with the print() function. Beyond its self reference it also expects
#      the list that was passed to the print function.
 
sub PRINT {
    my $self = shift;
    return unless (@_);
    my $output = join("",@_);
##    if ($self->stty_opost) {
##	if ($self->stty_ocrnl) { $output =~ s/\r/\n/osg; }
##	if ($self->stty_onlcr) { $output =~ s/\n/\r\n/osg; }
##    }
    my $to_do = length($output);
    my $done = 0;
    my $written = 0;
    while ($done < $to_do) {
        my $out2 = substr($output, $done);
        $written = $self->write($out2);
	if (! defined $written) {
            return;
        }
	return 0 unless ($written);
	$done += $written;
    }
##    $ = 0;
    1;
}
 
# PRINTF this, LIST
#      This method will be triggered every time the tied handle is printed to
#      with the printf() function. Beyond its self reference it also expects
#      the format and list that was passed to the printf function.
 
sub PRINTF {
    my $self = shift;
    my $fmt = shift;
    return unless ($fmt);
    return unless (@_);
    my $output = sprintf($fmt, @_);
    $self->PRINT($output);
}
 
# READ this, LIST
#      This method will be called when the handle is read from via the read
#      or sysread functions.

sub READ {
    carp "tied read and sysread functions not yet supported\n";
    return;
}
####     return if (@_ < 3);
####     my $buf = \$_[1];
####     my ($self, $junk, $size, $offset) = @_;
####     unless (defined $offset) { $offset = 0; }
####     my $done = 0;
####     my $count_in = 0;
####     my $string_in = "";
####     my $in2 = "";
####     my $bufsize = $self->internal_buffer;
#### 
####     while ($done < $len) {
#### 	my $size = $len - $done;
####         if ($size > $bufsize) { $size = $bufsize; }
#### 	($count_in, $string_in) = $self->read($size);
#### 	if ($count_in) {
####             $in2 .= $string_in;
#### 	    $done += $count_in;
#### ##	    $ = 0;
#### 	}
#### 	elsif ($done) {
#### ##	    $ = 0;
#### 	    last;
#### 	}
####         else {
####             return;
####         }
####     }
####     $$buf = substr($$buf, 0, $offset);
####     substr($$buf, $offset, $done) = $in2;
####     return $done;
####}

# READLINE this
#      This method will be called when the handle is read from via <HANDLE>.
#      The method should return undef when there is no more data.
 
sub READLINE {
    carp "READLINE and tied <FD> functions not yet supported\n";
    return;
}
##    my $self = shift;
##    return if (@_);
##    my $gotit = "";
##    my $match = "";
##    my $was;
##
##    if (wantarray) {
##	my @lines;
##        for (;;) {
##            $was = $self->reset_error;
##	    if ($was) {
##	        $ = 1117; # ERROR_IO_DEVICE
##		return @lines if (@lines);
##                return;
##	    }
##            if (! defined ($gotit = $self->streamline($self->{"_SIZE"}))) {
##		return @lines if (@lines);
##                return;
##            }
##	    $match = $self->matchclear;
##            if ( ($gotit ne "") || ($match ne "") ) {
##	        $ = 0;
##		$gotit .= $match;
##                push (@lines, $gotit);
##		return @lines if ($gotit =~ /$self->{"_CLASTLINE"}/s);
##            }
##        }
##    }
##    else {
##        for (;;) {
##            $was = $self->reset_error;
##	    if ($was) {
##	        $ = 1117; # ERROR_IO_DEVICE
##                return;
##	    }
##            if (! defined ($gotit = $self->lookfor($self->{"_SIZE"}))) {
##                return;
##            }
##	    $match = $self->matchclear;
##            if ( ($gotit ne "") || ($match ne "") ) {
##	        $ = 0;
##                return $gotit.$match;  # traditional <HANDLE> behavior
##            }
##        }
##    }
##}
 
# GETC this
#      This method will be called when the getc function is called.
 
sub GETC {
    my $self = shift;
    my ($count, $in) = $self->read(1);
    if ($count == 1) {
        return $in;
    }
    return;
}
 
# CLOSE this
#      This method will be called when the handle is closed via the close
#      function.
 
sub CLOSE {
    my $self = shift;
    my $success = $self->close;
    if ($Babble) { printf "CLOSE result:%d\n", $success; }
    return $success;
}
 
1;  # so the require or use succeeds

# Autoload methods go after =cut, and are processed by the autosplit program.

__END__

=pod

=head1 NAME

Device::SerialPort - Linux/POSIX emulation of Win32::SerialPort functions.

=head1 SYNOPSIS

  use Device::SerialPort;

=head2 Constructors

       # $quiet and $lockfile are optional
  $PortObj = new Device::SerialPort ($PortName, $quiet, $lockfile)
       || die "Can't open $PortName: $!\n";

       # not implemented yet
  $PortObj = start Device::SerialPort ($Configuration_File_Name)
       || die "Can't start $Configuration_File_Name: $!\n";

       # $Configuration_File_Name not implemented yet
       # if you use this, expect future changes
  $PortObj = tie (*FH, 'Device::SerialPort', $PortName)
       || die "Can't tie using $PortName: $!\n";

=head2 Configuration Utility Methods

  $PortObj->alias("MODEM1");

       # before using start, restart, or tie
       # not implemented yet
  $PortObj->save($Configuration_File_Name)
       || warn "Can't save $Configuration_File_Name: $!\n";

       # currently optional after new, POSIX version expected to succeed
  $PortObj->write_settings;

       # rereads file to either return open port to a known state
       # or switch to a different configuration on the same port
       # not implemented yet
  $PortObj->restart($Configuration_File_Name)
       || warn "Can't reread $Configuration_File_Name: $^E\n";

  Device::SerialPort->set_test_mode_active(1);	# test suite use only

      # exported by :PARAM
  nocarp || carp "Something fishy";
  $a = SHORTsize;			# 0xffff
  $a = LONGsize;			# 0xffffffff
  $answer = yes_true("choice");		# 1 or 0
  OS_Error unless ($API_Call_OK);	# prints error

=head2 Configuration Parameter Methods

     # most methods can be called two ways:
  $PortObj->handshake("xoff");           # set parameter
  $flowcontrol = $PortObj->handshake;    # current value (scalar)

     # The only "list context" method calls from Win32::SerialPort
     # currently supported are those for baudrate, parity, databits,
     # stopbits, and handshake (which only accept specific input values).
  @handshake_opts = $PortObj->handshake; # permitted choices (list)

     # similar
  $PortObj->baudrate(9600);
  $PortObj->parity("odd");
  $PortObj->databits(8);
  $PortObj->stopbits(1);	# POSIX does not support 1.5 stopbits

     # these are essentially dummies in POSIX implementation
     # the calls exist to support compatibility
  $PortObj->buffers(4096, 4096);	# returns (4096, 4096)
  @max_values = $PortObj->buffer_max;	# returns (4096, 4096)
  $PortObj->reset_error;		# returns 0

     # true/false parameters (return scalar context only)
     # parameters exist, but message processing not yet fully implemented
  $PortObj->user_msg(ON);	# built-in instead of warn/die above
  $PortObj->error_msg(ON);	# translate error bitmasks and carp

  $PortObj->parity_enable(F);	# faults during input
  $PortObj->debug(0);

     # true/false capabilities (read only)
     # most are just constants in the POSIX case
  $PortObj->can_baud;			# 1
  $PortObj->can_databits;		# 1
  $PortObj->can_stopbits;		# 1
  $PortObj->can_dtrdsr;			# 0 currently
  $PortObj->can_handshake;		# 1
  $PortObj->can_parity_check;		# 1
  $PortObj->can_parity_config;		# 1
  $PortObj->can_parity_enable;		# 1
  $PortObj->can_rlsd;    		# 0 currently
  $PortObj->can_16bitmode;		# 0 Win32-specific
  $PortObj->is_rs232;			# 1
  $PortObj->is_modem;			# 0 Win32-specific
  $PortObj->can_rtscts;			# 1
  $PortObj->can_xonxoff;		# 1
  $PortObj->can_xon_char;		# 0 use stty
  $PortObj->can_spec_char;		# 0 use stty
  $PortObj->can_interval_timeout;	# 1 currently
  $PortObj->can_total_timeout;		# 0 currently
  $PortObj->can_ioctl;			# automatically detected by eval
  
=head2 Operating Methods

  ($count_in, $string_in) = $PortObj->read($InBytes);
  warn "read unsuccessful\n" unless ($count_in == $InBytes);

  $count_out = $PortObj->write($output_string);
  warn "write failed\n"		unless ($count_out);
  warn "write incomplete\n"	if ( $count_out != length($output_string) );

  if ($string_in = $PortObj->input) { PortObj->write($string_in); }
     # simple echo with no control character processing

  $PortObj->write_drain;  # POSIX replacement for Win32 write_done(1)
  $PortObj->purge_all;
  $PortObj->purge_rx;
  $PortObj->purge_tx;

      # controlling outputs from the port
  $PortObj->dtr_active(T);		# sends outputs direct to hardware
  $PortObj->rts_active(Yes);		# return status of ioctl call
					# return undef on failure

  $PortObj->pulse_break_on($milliseconds); # off version is implausible
  $PortObj->pulse_rts_on($milliseconds);
  $PortObj->pulse_rts_off($milliseconds);
  $PortObj->pulse_dtr_on($milliseconds);
  $PortObj->pulse_dtr_off($milliseconds);
      # sets_bit, delays, resets_bit, delays
      # returns undef if unsuccessful or ioctls not implemented

  $PortObj->read_const_time(100);	# const time for read (milliseconds)
  $PortObj->read_char_time(5);		# avg time between read char

=head2 Methods used with Tied FileHandles

      # will eventually tie with $Configuration_File_Name
  $PortObj = tie (*FH, 'Device::SerialPort', $Portname)
       || die "Can't tie: $!\n";             ## TIEHANDLE ##

  print FH "text";                           ## PRINT     ##
  $char = getc FH;                           ## GETC      ##
  syswrite FH, $out, length($out), 0;        ## WRITE     ##
  ## $line = <FH>;                           ## READLINE  ## not yet supported
  ## @lines = <FH>;                          ## READLINE  ## not yet supported
  printf FH "received: %s", $line;           ## PRINTF    ##
  read (FH, $in, 5, 0) or die "$^E";         ## READ      ##
  sysread (FH, $in, 5, 0) or die "$^E";      ## READ      ##
  close FH || warn "close failed";           ## CLOSE     ##
  undef $PortObj;
  untie *FH;                                 ## DESTROY   ##

  ## $PortObj->linesize(10);		# with READLINE not yet supported
  ## $PortObj->lastline("_GOT_ME_");	# with READLINE, list only

=head2 Destructors

  $PortObj->close || warn "close failed";
      # release port to OS - needed to reopen
      # close will not usually DESTROY the object
      # also called as: close FH || warn "close failed";

  undef $PortObj;
      # preferred unless reopen expected since it triggers DESTROY
      # calls $PortObj->close but does not confirm success
      # MUST precede untie - do all three IN THIS SEQUENCE before re-tie.

  untie *FH;

=head2 Methods for I/O Processing (not yet implemented)

  $PortObj->are_match("text", "\n");	# possible end strings
  $PortObj->lookclear;			# empty buffers
  $PortObj->write("Feed Me:");		# initial prompt
  $PortObj->is_prompt("More Food:");	# new prompt after "kill" char

  my $gotit = "";
  until ("" ne $gotit) {
      $gotit = $PortObj->lookfor;	# poll until data ready
      die "Aborted without match\n" unless (defined $gotit);
      sleep 1;				# polling sample time
  }

  printf "gotit = %s\n", $gotit;		# input BEFORE the match
  my ($match, $after, $pattern, $instead) = $PortObj->lastlook;
      # input that MATCHED, input AFTER the match, PATTERN that matched
      # input received INSTEAD when timeout without match
  printf "lastlook-match = %s  -after = %s  -pattern = %s\n",
                           $match,      $after,        $pattern;

  $gotit = $PortObj->lookfor($count);	# block until $count chars received

  $PortObj->are_match("-re", "pattern", "text");
      # possible match strings: "pattern" is a regular expression,
      #                         "text" is a literal string

=head1 DESCRIPTION

This module provides an object-based user interface essentially
identical to the one provided by the Win32::SerialPort module.

=head2 Initialization

The primary constructor is B<new> with a F<PortName> specified. This
will open the port and create the object. The port is not yet ready
for read/write access. First, the desired I<parameter settings> must
be established. Since these are tuning constants for an underlying
hardware driver in the Operating System, they are all checked for
validity by the methods that set them. The B<write_settings> method
updates the port (and will return True under POSIX). Ports are opened
for binary transfers. A separate C<binmode> is not needed.

  $PortObj = new Device::SerialPort ($PortName, $quiet, $lockfile)
       || die "Can't open $PortName: $!\n";

There are two optional parameters for B<new>. Failure to open a port
prints an error message to STDOUT by default. Since other applications
can use the port, one source of failure is "port in use". There was
originally no way to check this without getting a "fail message".
Setting C<$quiet> disables this built-in message. It also returns 0
instead of C<undef> if the port is unavailable (still FALSE, used for
testing this condition - other faults may still return C<undef>).
Use of C<$quiet> only applies to B<new>.

The C<$lockfile> parameter has a related purpose. It will attempt to
create a file (containing just the current process id) at the location
specified. This file will be automatically deleted when the C<$PortObj>
is no longer used (by DESTROY). You would usually request C<$lockfile>
with C<$quiet> true to disable messages while attempting to obtain
exclusive ownership of the port via the lock. Lockfiles are VERY preliminary
in Version 0.05. I know of intermittent timing problems with uugetty when
attempting to use a port also used for logins.

The second constructor, B<start> is intended to simplify scripts which
need a constant setup. It executes all the steps from B<new> to
B<write_settings> based on a previously saved configuration. This
constructor will return C<undef> on a bad configuration file or failure
of a validity check. The returned object is ready for access.

       # NOT yet implemented
  $PortObj2 = start Win32::SerialPort ($Configuration_File_Name)
       || die;

The third constructor, B<tie>, will combine the B<start> with Perl's
support for tied FileHandles (see I<perltie>). Device::SerialPort will
implement the complete set of methods: TIEHANDLE, PRINT, PRINTF,
WRITE, READ, GETC, READLINE, CLOSE, and DESTROY. Tied FileHandle
support is new with Version 0.04 and the READ and READLINE methods
are not yet supported. The implementation attempts to mimic
STDIN/STDOUT behaviour as closely as possible. Currently, the port
name is used in place of a C<$Configuration_File_Name>.

  $PortObj2 = tie (*FH, 'Device::SerialPort', $PortName)
       || die;

The tied FileHandle methods may be combined with the Device::SerialPort
methods for B<read, input>, and B<write> as well as other methods. The
typical restrictions against mixing B<print> with B<syswrite> do not
apply. Since both B<(tied) read> and B<sysread> call the same C<$ob-E<gt>READ>
method, and since a separate C<$ob-E<gt>read> method has existed for some
time in Device::SerialPort, you should always use B<sysread> with the
tied interface (when it is implemented).

=over 8

Certain parameters I<SHOULD> be set before executing B<write_settings>.
Others will attempt to deduce defaults from the hardware or from other
parameters. The I<Required> parameters are:

=item baudrate

Any legal value.

=item parity

One of the following: "none", "odd", "even".
If you select anything except "none", you will need to set B<parity_enable>.

=item databits

An integer from 5 to 8.

=item stopbits

Legal values are 1 and 2.

=item handshake

One of the following: "none", "rts", "xoff".

=back

Some individual parameters (eg. baudrate) can be changed after the
initialization is completed. These will be validated and will
update the port as required.

  $PortObj = new Device::SerialPort ($PortName) || die "Can't open $PortName: $!\n";

  $PortObj->user_msg(ON);
  $PortObj->databits(8);
  $PortObj->baudrate(9600);
  $PortObj->parity("none");
  $PortObj->stopbits(1);
  $PortObj->handshake("rts")

  $PortObj->write_settings;

  $PortObj->baudrate(300);

  $PortObj->close;

  undef $PortObj;  # closes port AND frees memory in perl

Use B<alias> to convert the name used by "built-in" messages.

  $PortObj->alias("FIDO");

Version 0.04 adds B<pulse> methods for the I<RTS, BREAK, and DTR> bits. The
B<pulse> methods assume the bit is in the opposite state when the method
is called. They set the requested state, delay the specified number of
milliseconds, set the opposite state, and again delay the specified time.
These methods are designed to support devices, such as the X10 "FireCracker"
control and some modems, which require pulses on these lines to signal
specific events or data. Timing for the I<active> part of B<pulse_break_on>
is handled by I<POSIX::tcsendbreak(0)>, which sends a 250-500 millisecond
BREAK pulse.

  $PortObj->pulse_break_on($milliseconds);
  $PortObj->pulse_rts_on($milliseconds);
  $PortObj->pulse_rts_off($milliseconds);
  $PortObj->pulse_dtr_on($milliseconds);
  $PortObj->pulse_dtr_off($milliseconds);

In Version 0.05, these calls and the B<rts_active> and B<dtr_active> calls
verify the parameters and any required I<ioctl constants>, and return C<undef>
unless the call succeeds. You can use the B<can_ioctl> method to see if
the required constants are available. On Version 0.04, the module would
not load unless I<asm/termios.ph> was found at startup.

=head2 Configuration and Capability Methods

The Win32 Serial Comm API provides extensive information concerning
the capabilities and options available for a specific port (and
instance). This module will return suitable responses to facilitate
porting code from that environment.

=over 8

Binary selections will accept as I<true> any of the following:
C<("YES", "Y", "ON", "TRUE", "T", "1", 1)> (upper/lower/mixed case)
Anything else is I<false>.

There are a large number of possible configuration and option parameters.
To facilitate checking option validity in scripts, most configuration
methods can be used in two different ways:

=item method called with an argument

The parameter is set to the argument, if valid. An invalid argument
returns I<false> (undef) and the parameter is unchanged. The function
will also I<carp> if B<$user_msg> is I<true>. The port will be updated
immediately if allowed (an automatic B<write_settings> is called).

=item method called with no argument in scalar context

The current value is returned. If the value is not initialized either
directly or by default, return "undef" which will parse to I<false>.
For binary selections (true/false), return the current value. All
current values from "multivalue" selections will parse to I<true>.

=item method called with no argument in list context

Methods which only accept a limited number of specific input values
return a list consisting of all acceptable choices. The null list
C<(undef)> will be returned for failed calls in list context (e.g. for
an invalid or unexpected argument). Only the baudrate, parity, databits,
stopbits, and handshake methods currently support this feature.

=back

=head2 Exports

Nothing is exported by default. The following tags can be used to have
large sets of symbols exported:

=over 4

=item :PARAM

Utility subroutines and constants for parameter setting and test:

	LONGsize	SHORTsize	nocarp		yes_true
	OS_Error

=item :ALL

All of the above. Except for the I<test suite>, there is not really a good
reason to do this.

=back

=head1 NOTES

The object returned by B<new> is NOT a I<Filehandle>. You will be
disappointed if you try to use it as one.

e.g. the following is WRONG!!____C<print $PortObj "some text";>

This module uses I<POSIX termios> extensively. Raw API calls are B<very>
unforgiving. You will certainly want to start perl with the B<-w> switch.
If you can, B<use strict> as well. Try to ferret out all the syntax and
usage problems BEFORE issuing the API calls (many of which modify tuning
constants in hardware device drivers....not where you want to look for bugs).

With all the options, this module needs a good tutorial. It doesn't
have one yet.

=head1 KNOWN LIMITATIONS

The current version of the module has been tested with Perl 5.003 and
above. It was initially ported from Win32 and was designed to be used
without requiring a compiler or using XS. Since everything is (sometimes
convoluted but still pure) Perl, you can fix flaws and change limits if
required. But please file a bug report if you do.

The B<read> method, and tied methods which call it, currently can use a
fixed timeout which approximates behavior of the I<Win32::SerialPort>
B<read_const_time> and B<read_char_time> methods. It is used internally
by I<select>. If the timeout is set to zero, the B<read> call will return
immediately.

  $PortObj->read_const_time(500);	# 500 milliseconds = 0.5 seconds
  $PortObj->read_char_time(5);		# avg time between read char

The timing model defines the total time allowed to complete the operation.
A fixed overhead time is added to the product of bytes and per_byte_time.

Read_Total = B<read_const_time> + (B<read_char_time> * bytes_to_read)

Write timeouts and B<read_interval> timeouts are not currently supported.

=head1 BUGS

The module does not reliably open with lockfiles. Experiment if you like.

With all the I<currently unimplemented features>, we don't need any more.
But there probably are some.

__Please send comments and bug reports to wcbirthisel@alum.mit.edu.

=head1 Win32::SerialPort & Win32API::CommPort

=head2 Win32::SerialPort Functions Not Currently Supported

  ($BlockingFlags, $InBytes, $OutBytes, $ErrorFlags) = $PortObj->status;
  $LatchErrorFlags = $PortObj->reset_error;

  $PortObj->read_interval(100);		# max time between read char
  $PortObj->write_char_time(5);
  $PortObj->write_const_time(100);

=head2 Functions Handled in a POSIX system by "stty"

	xon_limit	xoff_limit	xon_char	xoff_char
	eof_char	event_char	error_char	stty_intr
	stty_quit	stty_eof	stty_eol	stty_erase
	stty_kill	is_stty_intr	is_stty_quit	is_stty_eof
	is_stty_eol	is_stty_erase	is_stty_kill	stty_clear
	is_stty_clear	stty_bsdel	stty_echo	stty_echoe
	stty_echok	stty_echonl	stty_echoke	stty_echoctl
	stty_istrip	stty_icrnl	stty_ocrnl	stty_igncr
	stty_inlcr	stty_onlcr	stty_isig	stty_icanon

=head2 Win32::SerialPort Functions Not Ported to POSIX

	modemlines	transmit_char

=head2 Win32API::CommPort Functions Not Ported to POSIX

	init_done	fetch_DCB	update_DCB	initialize
	are_buffers	are_baudrate	are_handshake	are_parity
	are_databits	are_stopbits	is_handshake	xmit_imm_char
	is_baudrate	is_parity	is_databits	is_write_char_time
	debug_comm	is_xon_limit	is_xoff_limit	is_read_const_time
	is_xoff_char	is_eof_char	is_event_char	is_read_char_time
	is_read_buf	is_write_buf	is_buffers	is_read_interval
	is_error_char	is_xon_char	is_stopbits	is_write_const_time
	is_binary	is_status	write_bg	is_parity_enable
	is_modemlines	read_bg		read_done	write_bg
	xoff_active	is_read_buf	is_write_buf	xon_active
	write_done	suspend_tx	resume_tx	break_active

=head2 "raw" Win32 API Calls and Constants

A large number of Win32-specific elements have been omitted. Most of
these are only available in Win32::SerialPort and Win32API::CommPort
as optional Exports. The list includes the following:

=over 4

=item :STAT

The Constants named BM_*, MS_*, CE_*, and ST_*

=item :RAW

The API Wrapper Methods and Constants used only to support them
including PURGE_*, SET*, CLR*, EV_*, and ERROR_IO*

=item :COMMPROP

The Constants used for Feature and Properties Detection including
BAUD_*, PST_*, PCF_*, SP_*, DATABITS_*, STOPBITS_*, PARITY_*, and 
COMMPROP_INITIALIZED

=item :DCB

The constants for the I<Win32 Device Control Block> including
CBR_*, DTR_*, RTS_*, *PARITY, *STOPBIT*, and FM_*

=back

=head2 Compatibility

This code implements the functions required to support the MisterHouse
Home Automation software by Bruce Winter. It does not attempt to support
functions from Win32::SerialPort such as B<stty_emulation> that already
have POSIX implementations or to replicate I<Win32 idosyncracies>. However,
the supported functions are intended to clone the equivalent functions
in Win32::SerialPort and Win32API::CommPort. Any discrepancies or
omissions should be considered bugs and reported to the maintainer.

=head1 AUTHORS

Based on Win32::SerialPort.pm, Version 0.8, by Bill Birthisel

Ported to linux/POSIX by Joe Doss for MisterHouse

Currently maintained by:
Bill Birthisel, wcbirthisel@alum.mit.edu, http://members.aol.com/Bbirthisel/

=head1 SEE ALSO

Win32API::CommPort

Win32::SerialPort

Perltoot.xxx - Tom (Christiansen)'s Object-Oriented Tutorial

=head1 COPYRIGHT

Copyright (C) 1999, Bill Birthisel. All rights reserved.

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself. 28 July 1999.

=cut

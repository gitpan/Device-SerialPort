
#### BEGIN { require 5.004; }

use Config qw(%Config);
use strict;
use ExtUtils::Install qw( install );

exit main();

sub main
{
    install_default_no_blib( "Device/SerialPort" )
      or die "Can't install package Device::SerialPort: $!\n";
    # install_default() should append to perl/lib/perllocal.pod but doesn't
    # as of Perl5.004_04 so use "make install" if this is important to you.
    0;
}

sub install_default_no_blib {
  @_ < 2 or die "install_default should be called with 0 or 1 argument";
  my $FULLEXT = shift;
  defined $FULLEXT or die "Do not know to where to write install log";
  my $INST_LIB = "./lib";
  my $HTML_LIB = "./html";

  my $html_dest = "";	# edit real html base here if autodetect fails

  if (exists $Config{installhtmldir} ) {
      $html_dest = "$Config{installhtmldir}";
  }
  elsif (exists $Config{installprivlib} ) {
      $html_dest = "$Config{installprivlib}";
      $html_dest =~ s%\\lib%\\html%;
  }

  if ( length ($html_dest) ) {
      $html_dest .= '\lib\site';
  }
  else {
      die "Can't find html base directory. Edit Install.PL manually.\n";
  }

  install({
	   read => "$Config{sitearchexp}/auto/$FULLEXT/.packlist",
	   write => "$Config{installsitearch}/auto/$FULLEXT/.packlist",
	   $INST_LIB => "$Config{installsitelib}",
	   $HTML_LIB => "$html_dest"
	  },1,0,0);
}

__END__

# Module: UnixTime. See below for documentation.
# Copyright (C) 2012-2014 RedStone Development Group, et al.
# This program is free software; rights to this code are stated in doc/LICENSE.
package M::UnixTime;
use strict;
use warnings;
use API::Std qw(cmd_add cmd_del);
use API::IRC qw(privmsg);

# Initialization subroutine.
sub _init {
	if($^O eq "linux") {
		# Create the UNIXTIME command.
		cmd_add('UNIXTIME', 0, 0, \%M::UnixTime::HELP_UNIXTIME, \&M::UnixTime::cmd_unixtime) or return;

		# Success.
		return 1;
	} else {
		cmd_add('UNIXTIME', 0, 0, \%M::UnixTime::HELP_UNIXTIME, \&M::UnixTime::cmd_unixtime2) or return;
	}
}

# Void subroutine.
sub _void {
    # Delete the UNIXTIME command.
    cmd_del('UNIXTIME') or return;

    # Success.
    return 1;
}

# Help hash for UNIXTIME.
our %HELP_UNIXTIME = (
    en => "This command changes a set of numbers to the appropriate normal time format. \2Syntax:\2 UNIXTIME <TIME>",
	#nl => "Dit commando verandert een tijd van unixtime naar normaal leesbare tijd \2Syntax:\2 UNIXTIME <TIME>",
);

# Callback for UNIXTIME command.
sub cmd_unixtime {
    my ($src, @argv) = @_;
	if(!defined($argv[0])) {
		privmsg($src->{svr}, $src->{chan}, trans('Too little parameters').q{.});
        return;
	}
	if(defined($argv[1])) {
		privmsg($src->{svr}, $src->{chan}, trans('Too many parameters').q{.});
        return;
	}
	if(Scalar::Util::looks_like_number($argv[0])) {
		my $output;
		my $timevariable;
		$timevariable = "date -d @".$argv[0];
		$output = `$timevariable`;
		$output =~ s/\n//g;
		privmsg($src->{svr}, $src->{chan}, "Unixtime format: \2$argv[0]\2 is \2$output\2");
	} else {
		privmsg($src->{svr}, $src->{chan}, "ERROR: Incorrect time format.");
	}
    return 1;
}

sub cmd_unixtime2 {
	my ($src, @argv) = @_;
	if(!defined($argv[0])) {
		privmsg($src->{svr}, $src->{chan}, trans('Too little parameters').q{.});
        return;
	}
	if(defined($argv[1])) {
		privmsg($src->{svr}, $src->{chan}, trans('Too many parameters').q{.});
        return;
	}
	if(Scalar::Util::looks_like_number($argv[0])) {
		my $time = time;
		my @months = ("Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec");
		my ($sec, $min, $hour, $day,$month,$year) = (localtime($time))[0,1,2,3,4,5];
		privmsg($src->{svr}, $src->{chan}, "Unixtime format: \2$argv[0]\2 is \2".$months[$month]." ".$day.", ".($year+1900)." ".$hour.":".$min.":".$sec."\2");
	} else {
		privmsg($src->{svr}, $src->{chan}, "ERROR: Incorrect time format.");
	}
    return 1;
}

# Start initialization.
API::Std::mod_init('UnixTime', 'Peter', '1.00', '3.0.0a11');
# build: perl=5.010000

__END__

=head1 NAME

 UnixTime - Time Conversion.

=head1 VERSION

 1.00

=head1 SYNOPSIS

 <+[nas]peter> !unixtime 111111
  Unixtime format: 111111 is Fri Jan  2 06:51:51 UTC 1970

=head1 DESCRIPTION

This command will change a unixtime format to normal readable time.

=head1 AUTHOR

This module was written by Peter.

=head1 LICENSE AND COPYRIGHT

This module is Copyright 2012-2014 RedStone Development Group. All rights
reserved.

This module is released under the same licensing terms as RedStone itself.

=cut

# vim: set ai et ts=4 sw=4:

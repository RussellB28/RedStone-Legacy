# Module: UnixTime. See below for documentation.
# Copyright (C) 2014 RedStone Development Group, et al.
# This program is free software; rights to this code are stated in doc/LICENSE.
package M::UnixTime;
use strict;
use warnings;
use API::Std qw(cmd_add cmd_del trans);
use API::IRC qw(privmsg);
use Date::Parse qw(str2time);

# Initialization subroutine.
sub _init {
	if($^O eq "linux") {
		# Create the UNIXTIME command.
		cmd_add('UNIXTIME', 0, 0, \%M::UnixTime::HELP_UNIXTIME, \&M::UnixTime::cmd_unixtime) or return;

		# Success.
		return 1;
	} else {
		return;
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
    en => "This command changes a set of numbers to the appropriate normal time format. \2Syntax:\2 UNIXTIME <TO/FROM> <DATETIME/UNIXTIME>",
	#nl => "Dit commando verandert een tijd van unixtime naar normaal leesbare tijd \2Syntax:\2 UNIXTIME <TO/FROM> <DATETIME/UNIXTIME>",
);

# Callback for UNIXTIME command.
sub cmd_unixtime {
    my ($src, @argv) = @_;
	if(!defined($argv[0])) {
		privmsg($src->{svr}, $src->{chan}, trans('Too little parameters').q{.});
        return;
	}

    if(lc($argv[0]) eq "from")
    {

	    if(lc($argv[1]) eq "now")
	    {
		    my $output;
		    my $timevariable;
		    $timevariable = "date -d @".time();
		    $output = `$timevariable`;
		    $output =~ s/\n//g;
		    privmsg($src->{svr}, $src->{chan}, "Unixtime format: \2NOW\2 is \2".$output."\2");
		    return;
	    }

	    if($argv[1] < -67768036191676799 || $argv[1] > 67768036191676799)
	    {
                privmsg($src->{svr}, $src->{chan}, trans('Invalid 64-Bit Timestamp. Must be between minus 67768036191676799 and positive 67768036191676799').q{.});
                return;
	    }

	    if(Scalar::Util::looks_like_number($argv[1])) {
		    my $output;
		    my $timevariable;
		    $timevariable = "date -d @".$argv[1];
		    $output = `$timevariable`;
		    $output =~ s/\n//g;
		    privmsg($src->{svr}, $src->{chan}, "Unixtime format: \2$argv[1]\2 is \2$output\2");
	    } else {
		    privmsg($src->{svr}, $src->{chan}, "ERROR: Incorrect time format.");
	    }
    }
    elsif(lc($argv[0]) eq "to")
    {
	    if(lc($argv[1]) eq "now")
	    {
		    privmsg($src->{svr}, $src->{chan}, "Datetime format: \2NOW\2 is \2".time()."\2");
		    return;
	    }

        my $msg;
	    for(my $i = 1; $i < scalar(@argv); $i++) {
		    $msg .= " ".$argv[$i];
	    }

        if(str2time($msg))
        {
            privmsg($src->{svr}, $src->{chan}, "Datetime format:\2$msg\2 is \2".str2time($msg)."\2");
        }
        else
        {
            privmsg($src->{svr}, $src->{chan}, "ERROR: Incorrect or Unknown time format.");
        }
    }
    else
    {
        privmsg($src->{svr}, $src->{chan}, trans('Syntax: unixtime [to/from] [dateformat/unixtime]').q{.});
    }
    return 1;
}

# Start initialization.
API::Std::mod_init('UnixTime', 'Russell M Bradford', '2.00', '3.0.0a11');
# build: cpan=Date::Parse perl=5.010000

__END__

=head1 NAME

 UnixTime - Time Conversion.

=head1 VERSION

 2.00

=head1 SYNOPSIS

 <SomeUser> !unixtime from 111111
 <SomeBot> Unixtime format: 111111 is Fri Jan  2 06:51:51 UTC 1970

 <SomeUser> !unixtime to Fri Jan  2 06:51:51 UTC 1970
 <SomeBot> Datetime format: Fri Jan  2 06:51:51 UTC 1970 is 111111 

=head1 DESCRIPTION

This command will change a unixtime format to normal readable time.

=head1 AUTHOR

This module was written by Russell M Bradford.

=head1 LICENSE AND COPYRIGHT

This module is Copyright 2014 Russell M Bradford. All rights
reserved.

This module is released under the same licensing terms as RedStone itself.

=cut

# vim: set ai et ts=4 sw=4:


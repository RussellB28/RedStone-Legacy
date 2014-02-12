# Module: ChanStat. See below for documentation.
# Copyright (C) 2010-2014 RedStone Development Group, et al.
# This program is free software; rights to this code are stated in doc/LICENSE.
package M::ChanStat;
use strict;
use warnings;
use API::Std qw(cmd_add cmd_del hook_add hook_del rchook_add rchook_del has_priv match_user);
use API::IRC qw(privmsg notice who);
my (@PING, $STATE, $OPT, %AWAY);
my $aways = 0;
my $opers = 0;
my $bots = 0; 
my $regs = 0;
my $heres = 0;

my $cows = 0;
my $cas = 0;
my $coos = 0;
my $chs = 0;
my $cvs = 0;
my $LAST = 0;

# Initialization subroutine.
sub _init {
    cmd_add('CHANSTAT', 0, 0, \%M::Ping::HELP_CHANSTAT, \&M::ChanStat::cmd_chanstat) or return;
    hook_add('on_whoreply', 'chanstat.who', \&M::ChanStat::on_whoreply) or return;
    # Hook onto numeric 315.
    rchook_add('315', 'chanstat.eow', \&M::ChanStat::on_eow) or return;
    # Success.
    return 1;
}

# Void subroutine.
sub _void {
    cmd_del('CHANSTAT') or return;
    hook_del('on_whoreply', 'chanstat.who') or return;
    # Delete 315 hook.
    rchook_del('315', 'chanstat.eow') or return;
    # Success.
    return 1;
}

# Help for CHANSTAT.
our %HELP_CHANSTAT = (
    en => "This command will show the current channels user statistics. \2Syntax:\2 CHANSTAT",
);

# Callback for CHANSTAT command.
sub cmd_chanstat {
    my ($src, @argv) = @_;


    if(defined($argv[0]))
    {
        $OPT = lc($argv[0]);
    }
    else
    {
        $OPT = "count";
    }

    # Check ratelimit (once every two minutes).
    if ((time - $LAST) < 10) {
        notice($src->{svr}, $src->{nick}, 'This command is ratelimited. Please wait a while before using it again.');
        return;
    }

    # Set last used time to current time.
    $LAST = time;

    $STATE = $src->{svr}.'::'.$src->{chan};

    # Ship off a WHO.
    who($src->{svr}, $src->{chan});

    return 1;
}

# Callback for WHO reply.
sub on_whoreply {
    my ($svr, $nick, $target, undef, undef, undef, $status, undef, undef) = @_;
    
    # Check if we're doing a ping right now.
    if ($STATE) {
        # Check if this is the target channel.
        if ($STATE eq $svr.'::'.$target) {
            # User is Away
            if ($status =~ m/G/xsm) {
                #push @PING, $nick;
		$aways++;
            }
            # User is Here
            if ($status =~ m/H/xsm) {
                #push @PING, $nick;
		$heres++;
            }
            # User is Regged
            if ($status =~ m/r/xsm) {
                #push @PING, $nick;
		$regs++;
            }
            # User is Bot
            if ($status =~ m/B/xsm) {
                #push @PING, $nick;
		$bots++;
            }
            # User is IRC Operator
            if ($status =~ m/\*/xsm) {
                #push @PING, $nick;
		$opers++;
            }

            if ($status =~ m/\~/xsm) {
                #push @PING, $nick;
		$cows++;
            }
            if ($status =~ m/\&/xsm) {
                #push @PING, $nick;
		$cas++;
            }
            if ($status =~ m/\@/xsm) {
                #push @PING, $nick;
		$coos++;
            }
            if ($status =~ m/\%/xsm) {
                #push @PING, $nick;
		$chs++;
            }
            if ($status =~ m/\+/xsm) {
                #push @PING, $nick;
		$cvs++;
            }
        }
    }

    return 1;
}

sub on_eow {
    if ($STATE) {
        my ($svr, $chan) = split '::', $STATE, 2;
        my $total = $aways + $heres;


        if($OPT eq "count")
        {
            privmsg($svr, $chan, "\002Channel Statistics for $chan\002");
            privmsg($svr, $chan, "[\002Owners:\002 $cows] [\002Admins:\002 $cas] [\002Ops:\002 $coos] [\002Halfops:\002 $chs] [\002Voices:\002 $cvs]");
            privmsg($svr, $chan, "[\002Away:\002 $aways] [\002Here:\002 $heres] [\002Bots:\002 $bots]");
            privmsg($svr, $chan, "[\002Registered Users:\002 $regs] [\002IRC Operators:\002 $opers] [\002Total Users:\002 $total]");
        }
        else
        {
            my ($c1, $c2, $c3, $c4, $c5, $c6, $c7, $c8, $c9, $c10);
            $c1 = $cows / $total * 100;
            $c2 = $cas / $total * 100;
            $c3 = $coos / $total * 100;
            $c4 = $chs / $total * 100;
            $c5 = $cvs / $total * 100;
            $c6 = $aways / $total * 100;
            $c7 = $heres / $total * 100;
            $c8 = $bots / $total * 100;
            $c9 = $regs / $total * 100;
            $c10 = $opers / $total * 100;

            privmsg($svr, $chan, "\002Channel Statistics for $chan\002");
            privmsg($svr, $chan, "[\002Owners:\002 ".int($c1)."%] [\002Admins:\002 ".int($c2)."%] [\002Ops:\002 ".int($c3)."%] [\002Halfops:\002 ".int($c4)."%] [\002Voices:\002 ".int($c5)."%]");
            privmsg($svr, $chan, "[\002Away:\002 ".int($c6)."%] [\002Here:\002 ".int($c7)."%] [\002Bots:\002 ".int($c8)."%]");
            privmsg($svr, $chan, "[\002Registered Users:\002 ".int($c9)."%] [\002IRC Operators:\002 ".int($c10)."%] [\002Total Users:\002 100%]");
        
        }
	$aways = 0;
	$heres = 0;
	$regs = 0;
	$bots = 0;
	$opers = 0;
    $cows = 0;
    $cas = 0;
    $coos = 0;
    $chs = 0;
    $cvs = 0;
    undef($STATE);
    undef($OPT);
    }

    return 1;
}

# Start initialization.
API::Std::mod_init('ChanStat', 'Russell M Bradford', '1.00', '3.0.0a11');
# build: perl=5.010000

__END__

=head1 NAME

 ChanStat - Basic Channel Statistics.

=head1 VERSION

 1.00

=head1 SYNOPSIS

 <user> !chanstat percent  
 <auto> Channel Statistics for #somechannel
 <auto> [Owners: 8%] [Admins: 25%] [Ops: 16%] [Halfops: 8%] [Voices: 41%]
 <auto> [Away: 8%] [Here: 91%] [Bots: 58%]
 <auto> [Registered Users: 100%] [IRC Operators: 33%] [Total Users: 100%]

 <user> !chanstat count
 <auto> Channel Statistics for #somechannel
 <auto> [Owners: 1] [Admins: 3] [Ops: 2] [Halfops: 1] [Voices: 5]
 <auto> [Away: 1] [Here: 11] [Bots: 7]
 <auto> [Registered Users: 12] [IRC Operators: 4] [Total Users: 12]

=head1 DESCRIPTION

This creates the CHANSTAT command, which will count every user in the channel,
using the output of '/who' and show statistics in the format requested.

=head1 AUTHOR

This module was written by Russell M Bradford.

This module is maintained by RedStone Development Group.

=head1 LICENSE AND COPYRIGHT

This module is Copyright 2010-2014 RedStone Development Group. All rights
reserved.

This module is released under the same licensing terms as RedStone itself.

=cut

# vim: set ai et ts=4 sw=4:

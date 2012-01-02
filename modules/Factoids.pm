# Module: Factoids. See below for documentation.
# Copyright (C) 2010-2012 Xelhua Development Group, et al.
# This program is free software; rights to this code are stated in doc/LICENSE.
package M::Factoids;
use strict;
use warnings;
use feature qw(switch);
use API::Std qw(cmd_add cmd_del hook_add hook_del trans err conf_get);
use API::IRC qw(privmsg notice);

# Initialization subroutine.
sub _init {
    # Check the database format. Fail to load if it's PostgreSQL.
    if ($Auto::ENFEAT =~ /pgsql/) { err(2, 'Unable to load QDB: PostgreSQL is not supported.', 0); return }

    # Create our database table if doesn't exist.
    $Auto::DB->do('CREATE TABLE IF NOT EXISTS factoids (net TEXT, chan TEXT, trigger TEXT, response TEXT)') or return;

    # Create the FACTOID command.
    cmd_add('FACTOID', 2, 'cmd.factoid', \%M::Factoids::HELP_FACTOID, \&M::Factoids::cmd_factoid);
    # Create our on_cprivmsg hook.
    hook_add('on_cprivmsg', 'factoid.parse', \&M::Factoids::on_cprivmsg) or return;

    # Success.
    return 1;
}

# Void subroutine.
sub _void {
    # Delete the FACTOID command.
    cmd_del('FACTOID') or return;
    # Delete our on_cprivmsg hook.
    hook_del('on_cprivmsg', 'factoid.parse') or return;

    # Success.
    return 1;
}

# Help hash for the FACTOID command.
our %HELP_FACTOID = (
    en => "This command allows you to add/delete/edit factoids. [#channel] is only needed in PM. \2Syntax:\2 FACTOID (ADD|DEL|EDIT) [#channel] <trigger> [response]",
);

# Callback for FACTOID command.
sub cmd_factoid {
    my ($src, @argv) = @_;

    # Check for required parameters.
    my $i = 1;
    if (!exists $src->{chan}) { $i = 2 }
    if (!defined $argv[$i]) {
        notice($src->{svr}, $src->{nick}, trans('Not enough parameters').q{.});
        return;
    }
    if (!exists $src->{chan}) { $src->{chan} = $argv[1]; splice @argv, 1, 1 }

    # Check for ADD|DEL.
    given (uc $argv[0]) {
        when ('ADD') {
            # Extra parameter required.
            if (!defined $argv[2]) {
                notice($src->{svr}, $src->{nick}, trans('Not enough parameters').q{.});
                return;
            }

            my $fchar = (conf_get('fantasy_pf'))[0][0];
            if (substr($argv[1], 0, 1) eq $fchar) {
                notice($src->{svr}, $src->{nick}, "Due to the design of this module, adding a factoid starting with $fchar isn't possible. Sorry.");
                return;
            }


            # Ensure it doesn't already exist.
            my $cdbq = $Auto::DB->prepare('SELECT * FROM factoids WHERE net = ? AND chan = ? AND trigger = ?');
            $cdbq->execute(lc $src->{svr}, lc $src->{chan}, lc $argv[1]);
            if ($cdbq->fetchrow_array) {
                notice($src->{svr}, $src->{nick}, 'That factoid already exists.');
                return;
            }

            # Now create it.
            my $dbq = $Auto::DB->prepare('INSERT INTO factoids (net, chan, trigger, response) VALUES (?, ?, ?, ?)');
            $dbq->execute(lc $src->{svr}, lc $src->{chan}, lc $argv[1], join(q{ }, @argv[2..$#argv])) or 
                notice($src->{svr}, $src->{nick}, trans('An error occurred')) and return;

            notice($src->{svr}, $src->{nick}, "Factoid \2".lc $argv[1]."\2 for \2$src->{chan}\2 on \2$src->{svr}\2 successfully created.");
        }
        when ('EDIT') {
            # Ensure it exists.
            my $cdbq = $Auto::DB->prepare('SELECT * FROM factoids WHERE net = ? AND chan = ? AND trigger = ?');
            $cdbq->execute(lc $src->{svr}, lc $src->{chan}, lc $argv[1]);
            if (!$cdbq->fetchrow_array) {
                notice($src->{svr}, $src->{nick}, 'That factoid doesn\'t exist.');
                return;
            }

            # Now update it.
            my $dbq = $Auto::DB->prepare('UPDATE factoids SET response = ? WHERE net = ? AND chan = ? AND trigger = ?');
            $dbq->execute(join(q{ }, @argv[2..$#argv]), lc $src->{svr}, lc $src->{chan}, lc $argv[1]) or notice($src->{svr}, $src->{nick}, trans('An error occurred')) and return;

            notice($src->{svr}, $src->{nick}, "Factoid \2".lc $argv[1]."\2 for \2$src->{chan}\2 on \2$src->{svr}\2 successfully edited.");
       }
        when ('DEL') {
            # Ensure it exists.
            my $cdbq = $Auto::DB->prepare('SELECT * FROM factoids WHERE net = ? AND chan = ? AND trigger = ?');
            $cdbq->execute(lc $src->{svr}, lc $src->{chan}, lc $argv[1]);
            if (!$cdbq->fetchrow_array) {
                notice($src->{svr}, $src->{nick}, 'That factoid doesn\'t exist.');
                return;
            }

            # Now delete it.
            my $dbq = $Auto::DB->prepare('DELETE FROM factoids WHERE net = ? AND chan = ? AND trigger = ?');
            $dbq->execute(lc $src->{svr}, lc $src->{chan}, lc $argv[1]) or
                notice($src->{svr}, $src->{nick}, trans('An error occurred')) and return;
            
            notice($src->{svr}, $src->{nick}, "Factoid \2".lc $argv[1]."\2 for \2$src->{chan}\2 on \2$src->{svr}\2 successfully deleted.");
        }
        default { notice($src->{svr}, $src->{nick}, trans('Unknown action', $_).q{.}) }
    }

    return 1;
}

# Our on_cprivmsg hook.
sub on_cprivmsg {
    my ($src, $chan, @msg) = @_;

    # Prepare message.
    my $msg = join q{ }, @msg;
    my $fchar = (conf_get('fantasy_pf'))[0][0];
    $msg =~ s/\Q$fchar\E/\$!\$/gxsm;
    $msg =~ s/ /[s]/gsm;

    # Check if it matches a factoid.
    my $cdbq = $Auto::DB->prepare('SELECT response FROM factoids WHERE net = ? AND chan = ? AND trigger = ?') or return 1; 
    $cdbq->execute(lc $src->{svr}, lc $chan, lc $msg) or return 1;
    my $worked = 0;
    FETCH:
    if (my $res = $cdbq->fetchrow_array) {
        # Filter out special variables.
        $res =~ s/\$!\$/$fchar/gxsm;
        $res =~ s/\$nick\$/$src->{nick}/gxsm;
        $res =~ s/\$chan\$/$chan/gxsm;
        $res =~ s/\$net\$/$src->{svr}/gxsm;
        privmsg($src->{svr}, $chan, $res);
        $worked = 1;
    }
    if (!$worked) {
        $cdbq->execute(lc $src->{svr}, '*', lc $msg) or return 1;
        $worked = 1;
        goto 'FETCH';
    }

    return 1;
}

# Start initialization.
API::Std::mod_init('Factoids', 'Xelhua', '1.00', '3.0.0a11');
# build: perl=5.010000

__END__

=head1 NAME

Factoids - Provides per-channel-per-network factoids.

=head1 VERSION

 1.00

=head1 SYNOPSIS

 <starcoder> .factoid add hi Hello, $nick$! Welcome to $chan$!
 -blue- Factoid hi for #bot on testnet successfully created.
 <starcoder> hi
 <blue> Hello, starcoder! Welcome to #bot!
 <starcoder> .factoid add $!$foo Foo, bar, baz, etc.
 -blue- Factoid $!$foo for #bot on testnet successfully created.
 <starcoder> .foo
 <blue> Foo, bar, baz, etc.
 <starcoder> .factoid edit $!$foo Bar, foo, baz, etc.
 -blue- Factoid $!$foo for #bot on testnet successfully created.
 <starcoder> .foo
 <blue> Bar, foo, baz, etc.

=head1 DESCRIPTION

This module provides per-channel-per-network factoid (trigger/response)
functionality with various extra useful abilities.

This is done with: FACTOID (ADD|DEL|EDIT) [#channel] <trigger> <response>

[#channel] is used if you send the command in PM to the bot.

Specify * for [#channel] to make it respond to the trigger in all channels on
that given network.

The FACTOID command requires the cmd.factoid privilege to use.

The trigger and response also support special variables. Read below.

=head1 SPECIAL VARIABLES

All special variables are substituted at fetch time, not insert time.

Trigger supports:

$!$: The current fantasy character. (fantasy_pf in your config)

Response supports:

$!$: The current fantasy character. (fantasy_pf in your config)
$nick$: The user's nick.
$chan$: The current channel.
$net$: The name of the current network. (as defined by your config)

=head1 AUTHOR

This module was written by Elijah Perrault.

This module is maintained by Xelhua Development Group.

=head1 LICENSE AND COPYRIGHT

This module is Copyright 2010-2012 Xelhua Development Group.

Released under the same licensing terms as Auto itself.

=cut

# vim: set ai et sw=4 ts=4:

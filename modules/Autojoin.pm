# Module: Autojoin. See below for documentation.
# Copyright (C) 2010-2014 RedStone Development Group, et al.
# This program is free software; rights to this code are stated in doc/LICENSE.
package M::Autojoin;
use strict;
use warnings;
use feature qw(switch);
use API::Std qw(conf_get trans cmd_add cmd_del hook_add hook_del);
use API::IRC qw(notice privmsg cpart cjoin);
use API::Log qw(slog dbug alog);

# Initialization subroutine.
sub _init {
    # PostgreSQL is not supported, yet.
    if ($Auto::ENFEAT =~ /pgsql/) { err(3, 'Unable to load Autojoin: PostgreSQL is not supported.', 0); return }


    # Create `autojoin` table.
    $Auto::DB->do('CREATE TABLE IF NOT EXISTS autojoin (net TEXT, chan TEXT, key TEXT)') or return;

    # Create our required hooks.
    hook_add('on_connect', 'autojoin.connect', \&M::Autojoin::on_connect, 1) or return; # Hook at same level as core so nothing stops us.

    cmd_add('AUTOJOIN', 0, 'cmd.autojoin', \%M::Autojoin::HELP_AUTOJOIN, \&M::Autojoin::cmd_autojoin) or return;

    # Success.
    return 1;
}

# Void subroutine.
sub _void {
    # Delete the hooks.
    hook_del('on_connect', 'autojoin.connect') or return;

    # Delete the command.
    cmd_del('AUTOJOIN') or return;

    # Success.
    return 1;
}

# Help for AUTOJOIN.
our %HELP_AUTOJOIN = (
    en => "This command allows manipulation of autojoin. \2Syntax:\2 AUTOJOIN <ADD|DEL|LIST> [ [<#channel>[\@network] [key]] | <network>]",
);

# Subroutine to check if a channel is already on the autojoin list.
sub check_status {
    my ($net, $chan) = @_;
    my $q = $Auto::DB->prepare('SELECT net FROM autojoin WHERE net = ? AND chan = ?') or return 0;
    $q->execute(lc $net, lc $chan) or return 0;
    if ($q->fetchrow_array) {
        return 1;
    }
    return 0;
}

# Subroutine to check if a channel is in the config (legacy autojoin).
sub in_conf {
    my ($net, $chan) = @_;
    return 0 if !conf_get("server:$net:ajoin");
    my @ajoin = @{ (conf_get("server:$net:ajoin"))[0] };

    if (!defined $ajoin[1]) {
        my @sajoin = split(',', $ajoin[0]);
        foreach(@sajoin) {
            return 1 if ($_ =~ m/\s/xsm and lc((split(/ /, @sajoin))[0]) eq lc($chan));
            return 1 if lc $_ eq lc $chan;
        }
    }
    else {
        foreach (@ajoin) {
            return 1 if ($_ =~ m/\s/xsm and lc((split(/ /, @ajoin))[0]) eq lc($chan));
            return 1 if lc $_ eq $chan;
        }
    }
    return 0;
}

# Callback for the AUTOJOIN command.
sub cmd_autojoin {
    my ($src, @argv) = @_;

    if (!defined $argv[0]) {
        notice($src->{svr}, $src->{nick}, trans('Not enough parameters').q{.});
        return;
    }

    my $target = (defined $src->{chan} ? $src->{chan} : $src->{nick});

    given(uc $argv[0]) {
        when ('ADD') {
            my $chan;
            my $svr = lc($src->{svr});
            if (!defined $argv[1]) {
                notice($src->{svr}, $src->{nick}, trans('Not enough parameters').q{.});
                return;
            }
            $chan = $src->{chan};
            if (defined $argv[1]) {
                if ($argv[1] =~ m/(#.*)\@(.*)/) {
                    $chan = $1;
                    $svr = lc($2);
                }
                else {
                    $chan = $argv[1];
                }                          
            }
            my $key = (defined $argv[2] ? $argv[2] : undef);
            if(!fix_net($svr)) {
                privmsg($src->{svr}, $target, "I'm not configured for $svr.");
                return;
            }
            notice($src->{svr}, $target, "$chan\@$svr is manually configured thus can not be added through AUTOJOIN.") and return if in_conf(fix_net($svr), $chan);
            notice($src->{svr}, $target, "$chan\@$svr is already on my autojoin list.") and return if check_status($svr, $chan);
            if (add($svr, $chan, $key)) {
                $svr = fix_net($svr);
                privmsg($src->{svr}, $target, "$chan\@$svr was added to my autojoin list.");
                slog("[\2Autojoin\2] $$src{nick} added $chan\@$svr to my autojoin list.");
                cjoin($svr, $chan, $key);
            }
            else {
                privmsg($src->{svr}, $target, 'Failed to add to autojoin.');
            }

        }
        when ('DEL') {
            my $chan;
            my $svr = lc($src->{svr});
            if (!defined $argv[1]) {
                notice($src->{svr}, $src->{nick}, trans('Not enough parameters').q{.});
                return;
            }
            $chan = $src->{chan};
            if (defined $argv[1]) {
                if ($argv[1] =~ m/(#.*)\@(.*)/) {
                    $chan = $1;
                    $svr = lc($2);
                }   
                else {
                    $chan = $argv[1];
                }
            }
            if(!fix_net($svr)) {
                privmsg($src->{svr}, $target, "I'm not configured for $svr.");
                return;
            }
            notice($src->{svr}, $target, "$chan\@$svr is manually configured thus can not be deleted.") and return if in_conf(fix_net($svr), $chan);
            notice($src->{svr}, $target, "$chan\@$svr is not on my autojoin list.") and return if !check_status($svr, $chan);
            if (del($svr, $chan)) {
                $svr = fix_net($svr);
                privmsg($src->{svr}, $target, "$chan\@$svr deleted from my autojoin list.");
                slog("[\2Autojoin\2] $$src{nick} deleted $chan\@$svr from my autojoin list.");
                cpart($svr, $chan, 'Removed from autojoin.');
            }
            else {
                privmsg($src->{svr}, $target, 'Failed to delete from autojoin.');
            }
        }
        when ('LIST') {
            my $svr = (defined $argv[1] ? lc($argv[1]) : lc($src->{svr}));
            my $chan = $src->{chan};
            if(!fix_net($svr)) {
                privmsg($src->{svr}, $target, "I'm not configured for $svr.");
                return;
            }
            my $dbh = $Auto::DB->prepare('SELECT chan FROM autojoin WHERE net = ?');
            $dbh->execute(lc $svr);
            my @data = $dbh->fetchall_arrayref;
            my @channels = ();
            foreach my $first (@data) {
                foreach my $second (@{$first}) {
                    foreach my $channel (@{$second}) {
                        push @channels, $channel;
                    }
                }
            }
            privmsg($src->{svr}, $target, join ', ', @channels);
        }
        default {
            # We don't know this command.
            notice($src->{svr}, $src->{nick}, trans('Unknown action', $_).q{.});
            return;
        }
    }

   return 1;
}

sub on_connect {
    my ($svr) = @_;
    my $dbh = $Auto::DB->prepare('SELECT * FROM autojoin WHERE net = ?');
    $dbh->execute(lc $svr);
    my $data = $dbh->fetchall_hashref('chan');
    foreach my $key (keys %$data) {
        cjoin($svr, $key, $data->{$key}->{key});
    }
}

sub fix_net {
    my ($net) = @_;
    my %servers = conf_get('server');
    foreach my $name (keys %servers) {
         if (lc($name) eq lc($net)) {
              return $name;
         }
    }
    return 0;
}

# Begin API
sub add {
    my ($net, $chan, $key) = @_;
    my $dbq = $Auto::DB->prepare('INSERT INTO autojoin (net, chan, key) VALUES (?, ?, ?)');
    return 1 if $dbq->execute(lc $net, lc $chan, $key);
    return 0;
}

sub del {
    my ($net, $chan) = @_;
    my $dbq = $Auto::DB->prepare('DELETE FROM autojoin WHERE net = ? AND chan = ?');
    return 1 if $dbq->execute(lc $net, lc $chan);
    return 0;
}

# Start initialization.
API::Std::mod_init('Autojoin', 'Ethrik', '1.00', '3.0.0a11');
# build: perl=5.010000

__END__

=head1 NAME

Autojoin

=head1 VERSION

 1.00

=head1 SYNOPSIS

<user> !autojoin add #channel
<auto> #channel@network added to my autojoin list.

=head1 DESCRIPTION

This module separates autojoin from the core. This allows us to easily manipulate it.

=head2 Notes

This module does not care if a network is deleted from the configuration. This will change when
servers are added to the db as well. With that will come a server manipulation module as well.
Also, eventually support for legacy autojoins (in the config) will be dropped. Please start using
this. This module also can not tell the difference of when a channel is added to manual autojoin.
That being said if you add a channel to the config that's already in the db do not complain
when you can't delete it.

=head1 AUTHOR

This module was written by Matthew Barksdale.

This module is maintained by RedStone Development Group.

=head1 LICENSE AND COPYRIGHT

This module is Copyright 2010-2014 RedStone Development Group. All rights
reserved.

This module is released under the same licensing terms as RedStone itself.

=cut

# vim: set ai et ts=4 sw=4:


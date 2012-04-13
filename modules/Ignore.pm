# Module: Ignore. See below for documentation.
# Copyright (C) 2010-2012 Xelhua Development Group, et al.
# This program is free software; rights to this code are stated in doc/LICENSE.
package M::Ignore;
use strict;
use warnings;
use feature qw(switch);
use API::Std qw(trans cmd_add cmd_del hook_add hook_del);
use API::IRC qw(notice privmsg);
use API::Log qw(slog dbug alog);

# Initialization subroutine.
sub _init {
    # PostgreSQL is not supported, yet.
    if ($Auto::ENFEAT =~ /pgsql/) { err(3, 'Unable to load Ignore: PostgreSQL is not supported.', 0); return }

    # Create `ignores` table.
    $Auto::DB->do('CREATE TABLE IF NOT EXISTS ignores (net TEXT, mask TEXT)') or return;

    # Create our required hooks.
    hook_add('on_privmsg', 'ignore.privmsg', sub { return -1 if is_ignored(shift); }, 0) or return; # Hook at same level as core so nothing stops us.

    cmd_add('IGNORE', 0, 'cmd.ignore', \%M::Ignore::HELP_AUTOJOIN, \&M::Ignore::cmd_ignore) or return;

    # Success.
    return 1;
}

# Void subroutine.
sub _void {
    # Delete the hooks.
    hook_del('on_privmsg', 'ignore.privmsg') or return;

    # Delete the command.
    cmd_del('IGNORE') or return;

    # Success.
    return 1;
}

# Help for IGNORE.
our %HELP_IGNORE = (
    en => "This command allows manipulation of Auto's ignore list. \2Syntax:\2 IGNORE <ADD|DEL|LIST> [ [<nick|mask> [<network>] | [<network] ]",
);

# Subroutine to check if a mask is ignored.
sub is_ignored {
    my $src = shift;
    my $q = $Auto::DB->prepare('SELECT * FROM ignores WHERE net = ?') or return 0;
    $q->execute(lc $src->{svr}) or return 0;
    my $data = $q->fetchall_hashref('mask');
    foreach (keys %$data) {
        return 1 if API::IRC::match_mask($src->{mask}, $_);
    }
    return 0;
}

# Callback for the IGNORE command.
sub cmd_ignore {
    my ($src, @argv) = @_;

    if (!defined $argv[0]) {
        notice($src->{svr}, $src->{nick}, trans('Not enough parameters').q{.});
        return;
    }

    my $target = (defined $src->{chan} ? $src->{chan} : $src->{nick});

    given(uc $argv[0]) {
        when ('ADD') {
            if (!defined $argv[1]) {
                notice($src->{svr}, $src->{nick}, trans('Not enough parameters').q{.});
                return;
            }
            my $svr = (defined $argv[2] ? lc $argv[2] : lc $src->{svr});
            if(!fix_net($svr)) {
                privmsg($src->{svr}, $target, "I'm not configured for $svr.");
                return;
            }
            my %tmp = %$src;
            $tmp{svr} = fix_net($svr);
            $tmp{mask} = fix_mask($argv[1]);
            privmsg($src->{svr}, $target, "$tmp{mask} is already on my ignore list on $svr.") and return if is_ignored(\%tmp);
            my $dbq = $Auto::DB->prepare('INSERT INTO ignores (net, mask) VALUES (?, ?)');
            if ($dbq->execute(lc $svr, $tmp{mask})) {
                $svr = fix_net($svr);
                privmsg($src->{svr}, $target, "$tmp{mask} was added to my ignore list on $svr.");
                slog("[\2Ignore\2] $$src{nick} added $tmp{mask} to my ignore list on $svr.");
            }
            else {
                privmsg($src->{svr}, $target, 'Failed to add to ignore list.');
            }

        }
        when ('DEL') {
            if (!defined $argv[1]) {
                notice($src->{svr}, $src->{nick}, trans('Not enough parameters').q{.});
                return;
            }
            my $svr = (defined $argv[2] ? lc $argv[2] : lc $src->{svr});
            if(!fix_net($svr)) {
                privmsg($src->{svr}, $target, "I'm not configured for $svr.");
                return;
            }
            my %tmp = %$src;
            $tmp{svr} = fix_net($svr);
            $tmp{mask} = fix_mask($argv[1]);
            privmsg($src->{svr}, $target, "$tmp{mask} is not on my ignore list on $svr.") and return if !is_ignored(\%tmp);
            my $dbq = $Auto::DB->prepare('DELETE FROM ignores WHERE net = ? AND mask = ?');
            if ($dbq->execute(lc $svr, $tmp{mask})) {
                $svr = fix_net($svr);
                privmsg($src->{svr}, $target, "$tmp{mask} deleted from my ignore list on $svr.");
                slog("[\2Ignore\2] $$src{nick} deleted $tmp{mask} from my autojoin list on $svr.");
            }
            else {
                privmsg($src->{svr}, $target, 'Failed to delete from ignore list.');
            }
        }
        when ('LIST') {
            my $svr = (defined $argv[1] ? lc($argv[1]) : lc($src->{svr}));
            if(!fix_net($svr)) {
                privmsg($src->{svr}, $target, "I'm not configured for $svr.");
                return;
            }
            my $dbh = $Auto::DB->prepare('SELECT mask FROM ignores WHERE net = ?');
            $dbh->execute(lc $svr);
            my @data = $dbh->fetchall_arrayref;
            my @masks = ();
            foreach my $first (@data) {
                foreach my $second (@{$first}) {
                    foreach my $mask (@{$second}) {
                        push @masks, $mask;
                    }
                }
            }
            privmsg($src->{svr}, $target, join ', ', @masks);
        }
        default {
            # We don't know this command.
            notice($src->{svr}, $src->{nick}, trans('Unknown action', $_).q{.});
            return;
        }
    }

   return 1;
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

sub fix_mask {
    my $mask = shift;
    given ($mask) {
        when (m/(.+)!(.+)\@(.+)/) { return $mask; } # Already in proper format.
        when (m/(.+)!(.+)$/) { return "$1!$2\@*"; } # Given nick!user
        when (m/(.+)\@(.+)$/) { return "*!$1\@$2"; } # Given user@host
        when (m/(.+)$/) { return "$1!*\@*"; } # Given nick
        default { return $mask; } # WTF? We must've been passed an invalid host. It's not worth the effort to clean it up.
    }
}

# Start initialization.
API::Std::mod_init('Ignore', 'Ethrik', '1.00', '3.0.0a11');
# build: perl=5.010000

__END__

=head1 NAME

Ignore

=head1 VERSION

 1.00

=head1 SYNOPSIS

<user> !ignore add matthew
<auto> matthew!*@* was added to my ignore list on somenetwork.

=head1 DESCRIPTION

This module adds the ability to ignore a user. This works by stopping all hooks
associated with an ignore user.

=head2 Notes

This module does not care if a network is deleted from the configuration. This will change when
servers are added to the db as well. With that will come a server manipulation module as well.

=head1 AUTHOR

This module was written by Matthew Barksdale.

This module is maintained by Ethrik Development Group.

=head1 LICENSE AND COPYRIGHT

This module is Copyright 2010-2012 Ethrik Development Group. All rights
reserved.

This module is released under the same licensing terms as Auto itself.

=cut

# vim: set ai et ts=4 sw=4:


# lib/State/IRC.pm - IRC state data.
# Copyright (C) 2010-2012 Xelhua Development Group, et al.
# This program is free software; rights to this code are stated in doc/LICENSE.
package State::IRC;
use strict;
use warnings;
use API::Std qw(hook_add rchook_add);
our (%chanusers, %botinfo, @who_wait);

# Create on_namesreply hook.
hook_add('on_namesreply', 'state.irc.names', sub {
    my ($svr, $chan, undef) = @_;

    # Ship off a WHO and wait for data.
    API::IRC::who($svr, $chan);
    push @who_wait, lc $chan;

    return 1;
}, 1);

# Create a WHO reply hook.
hook_add('on_whoreply', 'state.irc.who', sub {
    my ($svr, $nick, $chan, undef, undef, undef, $status, undef, undef) = @_;

    # Are we expecting WHO data for this channel?
    if (lc $chan ~~ @who_wait) {
        # Grab the server's prefixes.
        my @prefixes = values %{$Proto::IRC::csprefix{$svr}};
        # And this user's modes.
        my @umodes = split //, $status;

        # Iterate through their modes, saving channel status modes to memory.
        $chanusers{$svr}{lc $chan}{lc $nick} = q{};
        foreach my $mode (@umodes) {
            if ($mode ~~ @prefixes) {
                # Okay, so we've got some channel status, figure out the actual mode.
                my $amode;
                while (my ($pmod, $pfx) = each %{$Proto::IRC::csprefix{$svr}}) {
                    if ($pfx eq $mode) { $amode = $pmod }
                }

                # Great, now add it to their modes in memory.
                $chanusers{$svr}{lc $chan}{lc $nick} .= $amode;
            }
        }

        # If their modes are still empty, mark them as a normal user.
        if ($chanusers{$svr}{lc $chan}{lc $nick} eq q{}) {
            $chanusers{$svr}{lc $chan}{lc $nick} = 1;
        }
    }

    return 1;
}, 1);

# Create end of WHO hook.
rchook_add('315', 'state.irc.eow', sub {
    my ($svr, (undef, undef, undef, $chan, undef)) = @_;

    # If we're expecting WHO data for this channel, stop expecting, provided we've gotten data at all.
    if (lc $chan ~~ @who_wait and keys %{$chanusers{$svr}{lc $chan}} > 0) {
        for my $loc (0..$#who_wait) {
            if ($who_wait[$loc] eq lc $chan) { splice @who_wait, $loc, 1; last }
        }
    }

    return 1;
});

1;

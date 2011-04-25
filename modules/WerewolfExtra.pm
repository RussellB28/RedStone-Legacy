# Module: WerewolfExtra. See below for documentation.
# Copyright (C) 2010-2011 Xelhua Development Group, et al.
# This program is free software; rights to this code are stated in doc/LICENSE.
package M::WerewolfExtra;
use strict;
use warnings;
use feature qw(switch);
use API::Std qw(cmd_add cmd_del trans);
use API::IRC qw(privmsg notice cmode ison);
our ($GOAT);

# Initialization subroutine.
sub _init {
    # Create the WOLFE command.
    cmd_add('WOLFE', 0, 0, \%M::WerewolfExtra::HELP_WOLFE, \&M::WerewolfExtra::cmd_wolfe) or return;

    # Success.
    return 1;
}

# Void subroutine.
sub _void {
    # Delete the WOLFE command.
    cmd_del('WOLFE') or return;

    # Success.
    return 1;
}

# Help hash for the WOLFE command.
our %HELP_WOLFE = (
    'en' => "This command allows you to perform various idle actions in a game of Werewolf (A.K.A. Mafia). \2Syntax:\2 WOLFE (GOAT) [parameters]",
);

# Callback for the WOLFE command.
sub cmd_wolfe {
    my ($src, @argv) = @_;

    # We require at least one parameter.
    if (!defined $argv[0]) {
        notice($src->{svr}, $src->{nick}, trans('Not enough parameters').q{.});
        return;
    }

    # Iterate the parameter.
    given (uc $argv[0]) {
        when (/^(GOAT|G)$/) {
            # We require at least one parameter.
            if (!defined $argv[1]) {
                notice($src->{svr}, $src->{nick}, trans('Not enough parameters').q{.});
                return;
            }

            # Check if a game is running.
            if (!$M::Werewolf::GAME) {
                notice($src->{svr}, $src->{nick}, 'No game is currently running.');
                return;
            }
                
            # Check if this is the game channel.
            if ($src->{svr}.'/'.$src->{chan} ne $M::Werewolf::GAMECHAN) {
                notice($src->{svr}, $src->{nick}, "Werewolf is currently running in \2$M::Werewolf::GAMECHAN\2.");
                return;
            }

            # Make sure they're playing.
            if (!exists $M::Werewolf::PLAYERS{lc $src->{nick}}) {
                notice($src->{svr}, $src->{nick}, 'You\'re not currently playing.');
                return;
            }

            # Only in the day.
            if ($M::Werewolf::PHASE ne 'd') {
                notice($src->{svr}, $src->{nick}, 'The goats are currently asleep.');
                return;
            }

            # Goat is ratelimited to once per day.
            if ($GOAT) {
                notice($src->{svr}, $src->{nick}, 'Only one goat per day.');
                return;
            }

            # Check if the target is on the channel.
            if (!ison($src->{svr}, $src->{chan}, lc $argv[1])) {
                notice($src->{svr}, $src->{nick}, "\2$argv[1]\2 is not currently on the channel.");
                return;
            }

            # Go Go Go!
            my $tu = lc $argv[1];
            privmsg($src->{svr}, $src->{chan}, "\2$src->{nick}'s\2 goat walks by and kicks \2$Core::IRC::Users::users{$src->{svr}}{$tu}\2.");
            $GOAT = 1;
        }
        default { notice($src->{svr}, $src->{nick}, trans('Unknown action', $_).q{.}) }
    }

    return 1;
}

# Start initialization.
API::Std::mod_init('WerewolfExtra', 'Xelhua', '1.00', '3.0.0a11');
# build: perl=5.010000

__END__

=head1 NAME

WerewolfExtra - Silly idle commands for Werewolf

=head1 VERSION

 1.00

=head1 SYNOPSIS

None

=head1 DESCRIPTION

This module does nothing but provides extra idle, silly, useless commands for
those that must have something silly.

It provides the following commands:

 WOLFE GOAT|G - Kick someone with a goat. (Yes, really.)

=head1 DEPENDENCIES

This module depends on the following Auto module(s):

=over

=item Werewolf

The Werewolf module provides the game that this module provides extra silly
commands for. Using this module without Werewolf will likely cause a fatal
error.

=back

=head1 AUTHOR

This module was written by Elijah Perrault.

This module is maintained by Xelhua Development Group.

=head1 LICENSE AND COPYRIGHT

This module is Copyright (C) 2010-2011, Xelhua Development Group.

This module is released under the same terms as Auto itself.

=cut

# vim: set ai et ts=4 sw=4:

# Module: NickPrefix.
# Copyright (C) 2010-2012 Ethrik Development Group, et al.
# This program is free software; rights to this code are stated in doc/LICENSE.
package M::NickPrefix;
use strict;
use warnings;
use API::Std qw(trans hook_add hook_del has_priv match_user);
use API::IRC qw(privmsg notice);

# Initialization subroutine.
sub _init {
    # Add a hook for when we join a channel.
    hook_add('on_cprivmsg', 'nprefix.msg', \&M::NickPrefix::on_privmsg) or return;
    return 1;
}

# Void subroutine.
sub _void {
    # Delete the hook.
    hook_del('on_cprivmsg', 'nprefix.msg') or return;
    return 1;
}

# PRIVMSG hook subroutine.
sub on_privmsg {
    my ($src, $chan, @argv) = @_;
    
    return if !defined $argv[1]; # If there's no argument, no need to parse it.

    $src->{chan} = $chan;
    my %data = %$src;
    my $snick = $State::IRC::botinfo{$src->{svr}}{nick};

    if ($argv[0] =~ m/^\Q$snick\E([:\,]{0,1})$/i) {
        # We were just highlighted here.
        my $cmd = uc($argv[1]);
        my ($lcn, $lcc); # Only used in command level 3.
        shift @argv; shift @argv;
        if (defined $API::Std::CMDS{$cmd}) {
            if ($API::Std::CMDS{$cmd}{lvl} == 3) { 
                ($lcn, $lcc) = split '/', (conf_get('logchan'))[0][0];
            }
            if (($API::Std::CMDS{$cmd}{lvl} == 0 or $API::Std::CMDS{$cmd}{lvl} == 2) or ($API::Std::CMDS{$cmd}{lvl} == 3 and lc $chan eq lc $lcc and lc $src->{svr} eq lc $lcn)) {
                # This is a public command.
                if (API::Std::ratelimit_check(%data)) {
                    # Continue if user passes rate limit checks.
                    if ($API::Std::CMDS{$cmd}{priv}) {
                        # This command requires a privilege.
                        if (has_priv(match_user(%data), $API::Std::CMDS{$cmd}{priv})) {
                            # They have the privilege.
                            & { $API::Std::CMDS{$cmd}{'sub'} } ($src, @argv);
                        }
                        else {
                            # They don't have the privilege.
                            notice($src->{svr}, $src->{nick}, trans('Permission denied').q{.});
                        }
                    }
                    else {
                        # This command does not require a privilege.
                        & { $API::Std::CMDS{$cmd}{'sub'} } ($src, @argv);
                    }
                }
                else {
                    # They reached rate limit, tell them.
                    notice($src->{svr}, $src->{nick}, trans('Rate limit exceeded').q{.});
                }
            }
        }
        else {
            # Not a command.
        }
    }
    return 1;
}


# Start initialization.
API::Std::mod_init('NickPrfix', 'Ethrik', '1.00', '3.0.0a11');
# build: perl=5.010000

__END__

=head1 NAME

NickPrefix - Allows you to address the bot by its nick.

=head1 VERSION

 1.00

=head1 SYNOPSIS

 <matthew> Auto, eval 1
 <Auto> matthew: 1

=head1 DESCRIPTION

This module looks for its nick in a PRIVMSG, once
it finds it it tries to match followed arguments
with a command registered to Auto.


=head1 INSTALL

No additonal steps need to be taking to use this module.

=head1 AUTHOR

This module was written by Matthew Barksdale.

This module is maintained by Ethrik Development Group.

=head1 LICENSE AND COPYRIGHT

This module is Copyright 2010-2012 Ethrik Development Group.

Released under the same licensing terms as Auto itself.

=cut

# vim: set ai et sw=4 ts=4:

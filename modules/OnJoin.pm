# Module: OnJoin.
# Copyright (C) 2010-2014 RedStone Development Group, et al.
# This program is free software; rights to this code are stated in doc/LICENSE.
package M::OnJoin;
use strict;
use warnings;
use API::Std qw(hook_add hook_del conf_get);
use API::IRC qw(privmsg);
our $greet;

# Initialization subroutine.
sub _init {
    # Add a hook for when we join a channel.
    hook_add('on_ucjoin', 'oj.cjoin', \&M::OnJoin::on_chanjoin) or return;
    hook_add('on_rehash', 'oj.rehash', \&M::OnJoin::on_rehash) or return;
    $greet = (conf_get('onjoin_greet') ? (conf_get('onjoin_greet'))[0][0] : "Hello channel! I am a bot!");
    return 1;
}

# Void subroutine.
sub _void {
    # Delete the hooks.
    hook_del('on_ucjoin', 'oj.cjoin') or return;
    hook_del('on_rehash', 'oj.rehash') or return;
    return 1;
}

# on_chanjoin subroutine.
sub on_chanjoin {
    my ($svr, $chan) = @_;
    
    # Send a PRIVMSG.
    privmsg($svr, $chan, $greet);
    
    return 1;
}

# on_rehash subroutine.
sub on_rehash {
    # Reset $greet
    $greet = (conf_get('onjoin_greet') ? (conf_get('onjoin_greet'))[0][0] : "Hello channel! I am a bot!");
}

# Start initialization.
API::Std::mod_init('OnJoin', 'Xelhua', '1.00', '3.0.0a11');
# build: perl=5.010000

__END__

=head1 NAME

OnJoin - An example module meant to replace HelloChan.

=head1 VERSION

 1.00

=head1 SYNOPSIS

 * Auto has joined #moocows
 <Auto> Hello channel! I am a moocow!

=head1 DESCRIPTION

This module sends "Hello channel! I am a bot!" or a custom 
greeting whenever it joins a channel.

=head1 INSTALL

Add onjoin_greet to your configuration file.
Example: onjoin_greet "Hello channel! I am not a bot!";

=head1 AUTHOR

This module was written by Matthew Barksdale.

This module is maintained by RedStone Development Group.

=head1 LICENSE AND COPYRIGHT

This module is Copyright 2010-2014 RedStone Development Group.

Released under the same licensing terms as RedStone itself.

=cut

# vim: set ai et sw=4 ts=4:

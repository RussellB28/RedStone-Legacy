# Module: macmini. See below for documentation.
# Copyright (C) 2010-2012 Ethrik Development Group, et al.
# This program is free software; rights to this code are stated in doc/LICENSE.
package M::macmini;
use strict;
use warnings;
use API::Std qw(cmd_add cmd_del);
use API::IRC qw(privmsg);

# Initialization subroutine.
sub _init {
    # Create k command.
    cmd_add('K', 0, 0, \%M::macmini::HELP_GENERIC, \&M::macmini::cmd_k) or return;
    # Create is command.
    cmd_add('IS', 0, 0, \%M::macmini::HELP_GENERIC, \&M::macmini::cmd_is) or return;
    # Success.
    return 1;
}

# Void subroutine.
sub _void {
    # Delete k command.
    cmd_del('K') or return;
    # Delete is command.
    cmd_del('IS') or return;
    # Success.
    return 1;
}

# Generic help.
our %HELP_GENERIC = (
    en => "This is a generic command. These usually reply with sometime simple.",
);

# Callback for K command.
sub cmd_k {
    my ($src, undef) = @_;

    privmsg($src->{svr}, $src->{chan}, 'k');
    
    return 1;
}

# Callback for IS command.
sub cmd_is {
    my ($src, undef) = @_;

    privmsg($src->{svr}, $src->{chan}, 'yes, yes I am.');

    return 1;
}


# Start initialization.
API::Std::mod_init('macmini', 'Ethrik', '1.00', '3.0.0a11');
# build: perl=5.010000

__END__

=head1 NAME

macmini - An auto module for mac-mini.

=head1 VERSION

 1.00

=head1 SYNOPSIS

 <starcoder> !k
 <Auto> k

=head1 DESCRIPTION

This will create the k and is command.

=head1 AUTHOR

This module was written by Matthew Barksdale.

This module is maintained by Ethrik Development Group.

=head1 LICENSE AND COPYRIGHT

This module is Copyright 2010-2012 Ethrik Development Group.

Released under the same licensing terms as Auto itself.

=cut

# vim: set ai et ts=4 sw=4:

# Module: Relay. See below for documentation.
# Copyright (C) 2010-2011 Xelhua Development Group, et al.
# This program is free software; rights to this code are stated in doc/LICENSE.
package M::Relay;
use strict;
use warnings;
use API::Std qw(hook_add hook_del);
use API::IRC qw(privmsg);

# Initialization subroutine.
sub _init {
    # Channel PRIVMSGs.
    hook_add('on_cprivmsg', 'relay.cprivmsg', \&M::Relay::on_cprivmsg);
}

# Void subroutine.
sub _void {
    # Channel PRIVMSGs.
    hook_del('on_cprivmsg', 'relay.cprivmsg');
}


# Channel PRIVMSGs handler.
sub on_cprivmsg {
    my ($src, $chan, @data) = @_;

    if ($src->{svr} eq 'Staticbox') { return }

    if ($chan eq '#starcoder' or $chan eq '##starcoder') {
        my $msg = join q{ }, @data;
        if ($msg =~ s/^\001ACTION(.*)\001$//xsm) {
            $msg = '* '.$src->{nick}.q{@}.$src->{svr}.$1;
        }
        else {
            $msg = '<'.$src->{nick}.q{@}."$src->{svr}> $msg";
        }

        foreach (keys %Auto::SOCKET) {
            if ($_ ne $src->{svr} and $_ ne 'Staticbox') {
                privmsg($_, '#starcoder', $msg);
                privmsg($_, '##starcoder', $msg);
            }
        }
    }

    return 1;
}

# Start initialization.
API::Std::mod_init('Relay', 'Xelhua', '1.00', '3.0.0a11');
# build: perl=5.010000

__END__

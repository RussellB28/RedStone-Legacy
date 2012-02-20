# Module: DNS. See below for documentation.
# Copyright (C) 2010-2012 Ethrik Development Group, et al.
# This program is free software; rights to this code are stated in doc/LICENSE.
package M::DNS;
use strict;
use warnings;
use API::Std qw(cmd_add cmd_del trans);
use API::IRC qw(privmsg notice);
use Net::DNS;

# Initialization subroutine.
sub _init {
    # Create the DNS command.
    cmd_add('DNS', 0, 0, \%M::DNS::HELP_DNS, \&M::DNS::cmd_dns) or return;

    # Success.
    return 1;
}

# Void subroutine.
sub _void {
    # Delete the DNS command.
    cmd_del('DNS') or return;

    # Success.
    return 1;
}

# Help hash.
our %HELP_DNS = (
    en => "This command will do a DNS lookup. \2Syntax:\2 DNS <host>",
);

# Callback for DNS command.
sub cmd_dns {
    my ($src, @argv) = @_;
     
    if (!defined $argv[0]) {
        notice($src->{svr}, $src->{nick}, trans('Not enough parameters').q{.});
        return;
    }
    my $res = Net::DNS::Resolver->new;
    my $query = $res->search($argv[0]);
    my @results;

    if ($query) {
        foreach my $rr ($query->answer) {
            next if $rr->type ne 'A';
            push(@results, $rr->address);
        }
    }
    else {
        privmsg($src->{svr}, $src->{chan}, 'Unable to do query.');
        return;
    }

    if (@results) {
        privmsg($src->{svr}, $src->{chan}, "Results for \2$argv[0]\2:");
        my $result = join ' ', @results;
        privmsg($src->{svr}, $src->{chan}, "Results (".scalar(@results)."): ".$result);
    }
    else {
        privmsg($src->{svr}, $src->{chan}, "No results found for \2$argv[0]\2.");
        return;
    }

    return 1;
}

# Start initialization.
API::Std::mod_init('DNS', 'Xelhua', '1.01', '3.0.0a11');
# build: cpan=Net::DNS perl=5.010000

__END__

=head1 NAME

DNS - Net::DNS interface.

=head1 VERSION

 1.00

=head1 SYNOPSIS

 <matthew> !dns ethrik.net
 <blue> Results for ethrik.net:
 <blue> Results (1): 217.114.62.164

=head1 DESCRIPTION

This module creates the DNS command for preforming DNS
lookups.

=head1 DEPENDENCIES

This module depends on the following CPAN modules:

=over

=item L<Net::DNS>

This is the DNS agent this module uses.

=back

=head1 AUTHOR

This module was written by Matthew Barksdale.

This module is maintained by Ethrik Development Group.

=head1 LICENSE AND COPYRIGHT

This module is Copyright 2010-2012 Ethrik Development Group.

Released under the same licensing terms as Auto itself.

=cut

# vim: set ai et sw=4 ts=4:

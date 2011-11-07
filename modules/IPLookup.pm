# Module: IP Lookup. See below for documentation. 
# Copyright (C) 2010-2011 Xelhua Development Group, et al.
# This program is free software; rights to this code are stated in doc/LICENSE.
package M::IPLookup;

use strict;
use warnings;
use API::Std qw(cmd_add cmd_del conf_get);
use API::IRC qw(privmsg);
use IP::Info;

# Initalization subroutine.
sub _init {
    # Create IP lookup command
    cmd_add('IPLOOKUP',0,0, \%M::IPLookup::HELP_IPLOOKUP, \&M::IPLookup::cmd_iplookup) or return;
    
    # Success
    return 1;
}

sub _void  {
    cmd_del('IPLOOKUP') or return;
    
    return 1;
}
    

our %HELP_IPLOOKUP = (
    en => "This command will retrieve the IP information for the specified address. \002Syntax:\002 IPLOOKUP <address>",
);

sub cmd_iplookup {
    my ($src, @args) = @_;
    my $ip = join(' ', @args);
    
    if ($ip) {
        eval {
            my $api_key = (conf_get("ipinfo:api_key"))[0][0] if conf_get("ipinfo:api_key");
            my $api_secret = (conf_get("ipinfo:api_secret"))[0][0] if conf_get("ipinfo:api_secret");
            my $ip_info = IP::Info->new($api_key,$api_secret);
    
            my $ip_response = $ip_info->ipaddress($ip);
    
            privmsg($src->{svr}, $src->{chan}, "IP: ".$ip." | ASN: ".$ip_response->asn()." | Carrier: ".ucfirst($ip_response->carrier())." | Organization: ".ucfirst($ip_response->organization())." | Location: ".ucfirst($ip_response->city()).", ".ucfirst($ip_response->country()));
        };
        
        if ($@) {
            privmsg($src->{svr}, $src->{chan}, 'An error occured while looking up the IP address.'); 
            
        }
    
    } else {
        privmsg($src->{svr}, $src->{chan}, 'Not enough parameters.');
    }
    
    return 1;
}

# Start initialization.
API::Std::mod_init('IPLookup', 'Xelhua', '1.00', '3.0.0a11');
# build: cpan=IP::Info,Readonly::XS perl=5.010000


__END__

=head1 IP Lookup

=head2 Description

=over

This module adds the IP LOOKUP command for retrieving ASN
info for an IP.

=back

=head2 Examples

=over

<JohnSmith> !iplookup 8.8.8.8
<Auto> IP: 8.8.8.8 | ASN: 15169 | Carrier: Google inc. | Organization: Google incorporated | Location: Mountain view, United states

=back

=head2 To Do

=over

=back

=head2 Technical

=over

This module requires IP::Info and Readonly::XS. Both are 
obtainable from CPAN <http://www.cpan.org>.

This module is compatible with Auto version 3.0.0a10+.

=back

# vim: set ai et sw=4 ts=4:

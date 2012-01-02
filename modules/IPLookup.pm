# Module: IP Lookup. See below for documentation. 
# Copyright (C) 2010-2012 Xelhua Development Group, et al.
# This program is free software; rights to this code are stated in doc/LICENSE.
package M::IPLookup;

use strict;
use warnings;
use API::Std qw(cmd_add cmd_del conf_get);
use API::IRC qw(privmsg);
use Net::Whois::IANA;
use Regexp::Common qw/net/;
use Socket;

# Initalization subroutine.
sub _init {
    # Create IP lookup command
    cmd_add('IPLOOKUP', 0, 0, \%M::IPLookup::HELP_IPLOOKUP, \&M::IPLookup::cmd_iplookup) or return;
    
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
    
    privmsg($src->{svr}, $src->{chan}, "The IP address, ".$ip.", is not valid.") and return if $ip !~ /^$RE{net}{IPv4}$/;

    if ($ip) {
        my $iana = Net::Whois::IANA->new;
        $iana->whois_query(-ip => $ip);  
  
        my $info = $iana->fullinfo;
        $info =~ s/:\s+/:/g;
        my ($asn, $city, $state);
        if ($info =~ /OriginAS:AS(.*)/) {
            $asn = $1;
        }
        if ($info =~ /City:(.*)/) {
            $city = $1;
        }
        if ($info =~ /StateProv:(.*)/) {
            $state = $1;
        }
        my $iaddr = inet_aton($ip);
        my $rdns = gethostbyaddr($iaddr, AF_INET);
        privmsg($src->{svr}, $src->{chan}, "IP: ".$ip." | ASN: ".(defined($asn) ? $asn : 'N/A')." | Location: ".(defined($city) ? $city : 'N/A').", ".(defined($state) ? $state : 'N/A').", ".$iana->country." | Netname: ".$iana->netname." | Description: ".$iana->descr." | Source: ".$iana->source." | rDNS: ".(defined($rdns) ? $rdns : 'None')." | Abuse: ".$iana->abuse);
    } else {
        privmsg($src->{svr}, $src->{chan}, 'Not enough parameters.');
    }
    
    return 1;
}

# Start initialization.
API::Std::mod_init('IPLookup', 'Xelhua', '1.01', '3.0.0a11');
# build: cpan=Net::Whois::IANA,Regexp::Common perl=5.010000


__END__

=head1 Name
IP Lookup  - Lookup information on an IP address

=head1 VERSION
1.01

=head1 SYNOPSIS
<JohnSmith> !iplookup 8.8.8.8
<Auto> IP: 8.8.8.8 | ASN: N/A | Country: Mountain View, CA, US | Netname: LVLT-ORG-8-8 | Description: Level 3 Communications, Inc. | Source: ARIN | rDNS google-public-dns-a.google.com | Abuse: security@level3.com

=head1 DESCRIPTION
This module adds the IP LOOKUP command for retrieving ASN info for an IP.

=head1 INSTALL
This module requires Net::Whois::IANA and Regexp::Common. Both are obtainable from CPAN <http://www.cpan.org>.

=head1 AUTHOR
This module was written by Liam Smith <me@liam.co>.
This module is maintained by Liam Smith <me@liam.co>.

=head1 LICENSE AND COPYRIGHT
This module is Copyright 2010-2012 Xelhua Development Group, et al.
This module is released under the same licensing terms as Auto itself.
=cut

# vim: set ai et sw=4 ts=4:

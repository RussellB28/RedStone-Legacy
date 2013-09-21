# Module: IP Lookup. See below for documentation. 
# Copyright (C) 2013 Russell M Bradford, et al.
# This program is free software; rights to this code are stated in doc/LICENSE.
package M::IPLookup;

use strict;
use warnings;
use API::Std qw(cmd_add cmd_del conf_get);
use API::IRC qw(privmsg);
use Regexp::Common qw/net/;
use JSON;
use Socket;
use Net::DNS;

# Initalization subroutine.
sub _init {
    # Create IP lookup command
    cmd_add('IPLOOKUP', 0, 0, \%M::IPLookup::HELP_IPLOOKUP, \&M::IPLookup::cmd_iplookup) or return;
    cmd_add('IL', 0, 0, \%M::IPLookup::HELP_IPLOOKUP, \&M::IPLookup::cmd_iplookup) or return;
    
    # Success
    return 1;
}

sub _void  {
    cmd_del('IPLOOKUP') or return;
    cmd_del('IL') or return;
    
    return 1;
}
    

our %HELP_IPLOOKUP = (
    en => "This command will retrieve the IP information for the specified address. \002Syntax:\002 IPLOOKUP <address>",
);

sub cmd_iplookup {
    my ($src, @argv) = @_;

    if(!defined($argv[0]))
    {
        privmsg($src->{svr}, $src->{chan}, "Not Enough Parameters. Please specify a Domain or IPv4, IPv6 address");        
        return 0;
    }

    my $api_url = "http://ip-api.com/json/".$argv[0];


    $Auto::http->request(
        url => $api_url,
        on_response => sub {
            my $result = shift;

            if($result->is_success)
            {
                my $jsonresp = $result->decoded_content;
                my $jsonbits = decode_json($jsonresp);
                if($jsonbits->{"status"} eq "fail")
                {
                    privmsg($src->{svr}, $src->{chan}, "An Error Occured: ".$jsonbits->{"message"}." - Did you check that the IP was valid??");
                    return 0;
                }

                my $hexip;
                foreach (split /\./, $argv[0]) 
                { 
	                $hexip .= sprintf("\U%02x", $_); 
                }
                my @octets;
                my $longip;
                @octets = split(/\./, $argv[0]);
                $longip = ($octets[0]*1<<24)+($octets[1]*1<<16)+($octets[2]*1<<8)+($octets[3]);

                my $rdns;
                my $res = Net::DNS::Resolver->new;
                $res->tcp_timeout(3);
                $res->udp_timeout(3);
                my $dnsq = $res->search($argv[0]);
                if ($dnsq) {
                    foreach my $dnsr ($dnsq->answer) {
                        next if $dnsr->type ne 'PTR';
                        $rdns = $dnsr->rdatastr;
                    }
                }
                else
                {
                    $rdns = "None";
                }

                if($jsonbits->{"city"} eq "") { $jsonbits->{"city"} = "N/A"; }
                if($jsonbits->{"regionName"} eq "") { $jsonbits->{"regionName"} = "N/A"; }
                if($jsonbits->{"countryCode"} eq "") { $jsonbits->{"countryCode"} = "N/A"; }
                if($jsonbits->{"isp"} eq "") { $jsonbits->{"isp"} = "N/A"; }
                if($jsonbits->{"org"} eq "") { $jsonbits->{"org"} = "N/A"; }
                if($jsonbits->{"as"} eq "") { $jsonbits->{"as"} = "N/A"; }
                

                if($argv[0] !~ /^$RE{net}{IPv4}$/)
                {
                    privmsg($src->{svr}, $src->{target}, "\002Information for IP: ".$jsonbits->{"query"}."\002");
                }
                else
                {
                    privmsg($src->{svr}, $src->{target}, "\002Information for IP: ".$jsonbits->{"query"}." (Hex: 0x$hexip - Long: $longip)\002");
                }
                privmsg($src->{svr}, $src->{target}, "Reverse DNS: ".$rdns."");
                privmsg($src->{svr}, $src->{target}, "Location: ".$jsonbits->{"city"}.", ".$jsonbits->{"regionName"}.", ".uc($jsonbits->{"countryCode"})."");
                privmsg($src->{svr}, $src->{target}, "ISP: ".$jsonbits->{"isp"}."");
                privmsg($src->{svr}, $src->{target}, "Organisation: ".$jsonbits->{"org"}."");
                privmsg($src->{svr}, $src->{target}, "AS Information: ".$jsonbits->{"as"}."");
                #privmsg($src->{svr}, $src->{target}, "Coordinates: ".$jsonbits->{"lat"}.", ".$jsonbits->{"lon"});
                
            }
            else
            {
                privmsg($src->{svr}, $src->{chan}, "An unexpected error occured. Please try again shortly.");
                return 0;
            }
        },
        on_error => sub {
                my $error = shift;
                privmsg($src->{svr}, $src->{chan}, "An error occured: $error");
                return 0;
        }
    );    
    return 1;
}

# Start initialization.
API::Std::mod_init('IPLookup', 'Russell M Bradford', '2.00', '3.0.0a11');
# build: cpan=Net::DNS,Regexp::Common,JSON perl=5.010000


__END__

=head1 Name
IP Lookup  - Lookup information on an IP address

=head1 VERSION
2.00

=head1 SYNOPSIS
<Roy> !iplookup 2001:1af8:4300:a011:14:0:0:0
<RedStone> Information for IP: 2001:1af8:4300:a011:14:0:0:0
<RedStone> Reverse DNS: ub3r.l33t.c0de5.org.
<RedStone> Location: N/A, N/A, NL
<RedStone> ISP: N/A
<RedStone> Organisation: N/A
<RedStone> AS Information: AS16265 LeaseWeb B.V.

=head1 DESCRIPTION
This module adds the IP LOOKUP command for retrieving ASN info for an IPv4 or IPv6 address.

=head1 INSTALL
This module requires Net::DNS, JSON and Regexp::Common. All are obtainable from CPAN <http://www.cpan.org>.

=head1 AUTHOR
This module was written by Russell M Bradford <russell[at]rbradford.me>.
This module is maintained by Russell M Bradford <russell[at]rbradford.me>.

=head1 LICENSE AND COPYRIGHT
This module is Copyright 2013 Russell M Bradford, et al.
This module is released under the same licensing terms as RedStone itself.
=cut

# vim: set ai et sw=4 ts=4:

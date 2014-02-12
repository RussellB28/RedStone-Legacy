# Module: HostedBy. See below for documentation.
# Copyright (C) 2012-2014 RedStone Development Group, et al.
# This program is free software; rights to this code are stated in doc/LICENSE.
package M::HostedBy;
use strict;
use warnings;
use Furl;
use URI::Escape;
use API::Std qw(cmd_add cmd_del trans);
use API::IRC qw(privmsg);
use API::Log qw(dbug);

# Initialization subroutine.
sub _init {
	cmd_add('hostedby', 0, 0, \%M::HostedBy::HELP_HOSTEDBY, \&M::HostedBy::cmd_hostedby) or return;
	# Success.
    return 1;
}

# Void subroutine.
sub _void {
	cmd_del('hostedby') or return;
	
    # Success.
    return 1;
}

our %HELP_HOSTEDBY = (
    en => "Will check the host of a domain (not subdomain) \2Syntax:\2 HOSTEDBY <DOMAIN>",
	#nl => "Controleert welk bedrijf het domein host (geen subdomeinen) \2Syntax:\2 HOSTEDBY <DOMAIN>",
);

sub cmd_hostedby {
    my ($src, @argv) = @_;
	if(!defined($argv[0])) {
		privmsg($src->{svr}, $src->{target}, trans('Too little parameters').q{.});
        return;
	}
	if(defined($argv[1])) {
		privmsg($src->{svr}, $src->{target}, trans('Too many parameters').q{.});
        return;
	}
	my $url = "http://ishostedby.com/search.php?q=".uri_escape($argv[0])."&submit=ANALIZE+NOW";
	$Auto::http->request(
		url => $url,
		on_response => sub {
			my $response = shift;
			if (!$response->is_success) {
				privmsg($src->{svr}, $src->{target},"An unexpected error occured.");
				return;
			}
			my $content = $response->content;
			$content =~ s/\n//g;
			if($content =~ /\. This website is hosted at (.+?)"\/>/) {
				privmsg($src->{svr}, $src->{target}, "\2$argv[0]\2 is hosted at \2".$1."\2");
			} elsif($content =~ /but we could not find any information about it/) {
				privmsg($src->{svr}, $src->{target}, "No information available for \2$argv[0]\2");
			} else {
				privmsg($src->{svr}, $src->{target}, "An unexpected error occured.");
			}
		},
		on_error => sub {
			privmsg($src->{svr}, $src->{target}, "An unexpected error occured.");
			return;
		},
	);
}

# Start initialization.
API::Std::mod_init('HostedBy', 'Peter', '1.00', '3.0.0a11');
# build: perl=5.010000

__END__

=head1 NAME

HostedBy - IRC interface to check which company hosts what domain.

=head1 VERSION

 1.00
 
=head1 SYNOPSIS

 

=head1 DESCRIPTION

This creates several ShoutCast specific commands, that can check the spelling of a single word.

=head1 CONFIGURATION

No configurable options.

=head1 DEPENDENCIES

This module depends on the following CPAN modules:

=over


=back

=head1 AUTHOR

This module was written by Peter

=head1 LICENSE AND COPYRIGHT

This module is Copyright 2012-2014 RedStone Development Group.

Released under the same licensing terms as RedStone itself.

=cut

# vim: set ai et sw=4 ts=4:

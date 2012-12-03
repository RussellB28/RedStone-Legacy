# Module: PHP. See below for documentation.
# Copyright (C) 2012 [NAS]peter, et al.
# This program is free software; rights to this code are stated in doc/LICENSE.
package M::PHP;
use strict;
use warnings;
use API::Std qw(cmd_add cmd_del trans);
use API::IRC qw(privmsg);
use API::Log qw(slog dbug alog);

# Initialization subroutine.
sub _init {
	cmd_add('PHP', 0, 0, \%M::PHP::HELP_PHP, \&M::PHP::cmd_php) or return;
	# Success.
    return 1;
}

# Void subroutine.
sub _void {
	cmd_del('PHP') or return;
	
    # Success.
    return 1;
}

our %HELP_PHP = (
    en => "Will check if the function in the parameter exists and the parameters to the function and description of the function. \2Syntax:\2 PHP <Name of function>",
);

sub cmd_php {
    my ($src, @argv) = @_;
	if(!defined($argv[0])) {
		privmsg($src->{svr}, $src->{chan}, trans('Too little parameters').q{.});
        return;
	}
	if(defined($argv[1])) {
		privmsg($src->{svr}, $src->{chan}, trans('Too many parameters').q{.});
        return;
	}
	
	my $var = $argv[0];
	$var =~ s/_/-/g;
	
	my $url = 'http://php.net/manual/en/function.'.$var.'.php';
	$Auto::http->request(
        url => $url,
        on_response => sub {
            my $response = shift;
        	if ($response->is_success) {
	        	my $content = $response->decoded_content;
	        	$content =~ s/\n//g;
	        	if($content =~ /<div id="content" class="default"><h1>Not Found<\/h1>/) {
					privmsg($src->{svr}, $src->{target},"Function ".$argv[0]." was not found.");
				}
				#<div class="methodsynopsis dc-description"><span class="type">int</span> <span class="methodname"><strong>strpos</strong></span>( <span class="methodparam"><span class="type">string</span> <code class="parameter">$haystack</code></span>, <span class="methodparam"><span class="type"><a href="language.pseudo-types.php#language.types.mixed" class="type mixed">mixed</a></span> <code class="parameter">$needle</code></span>[, <span class="methodparam"><span class="type">int</span> <code class="parameter">$offset</code><span class="initializer"> = 0</span></span>] )</div>
				#int strpos ( string $haystack , mixed $needle [, int $offset = 0 ] )
				my $usage = $content;
				$usage =~ s/<\/div><br \/><br \/><!--UdmComment-->(.*)//gi;
				$usage =~ s/<h3 class="title">Parameters<\/h3>(.*)//gi;
				$usage =~ s/(.*)<h3 class="title">Description<\/h3>//gi;
				$usage =~ s/<(?:[^>'"]*|(['"]).*?\1)*>//gs;
				while($usage =~ /  /) {
					$usage =~ s/  / /g;
				}
				privmsg($src->{svr},$src->{target},"Function: \002".$argv[0]."\002");
				if($usage =~ /(.*)\)(.*)/) {
					privmsg($src->{svr},$src->{target},"\002Syntax:\002".$1.")");
					privmsg($src->{svr},$src->{target},"\002Description:\002".$2);
				}
				privmsg($src->{svr},$src->{target},"\002URL:\002 ".$url);
        	} else {
        		privmsg($src->{svr}, $src->{target}, "An error occurred while retrieving the function.");
	        	return;
        	}
        },
        on_error => sub {
            my $error = shift;
            privmsg($src->{svr}, $src->{target}, "An error occurred while retrieving the function: $error");
        }
    );
    return 1;
}

# Start initialization.
API::Std::mod_init('PHP', '[NAS]peter', '1.0', '3.0.0a11');
# build: perl=5.010000 cpan=

__END__

=head1 NAME

Spell - IRC interface to check for PHP functions

=head1 VERSION

 1.01
 
=head1 SYNOPSIS

 <Peter>   @php convert_uuencode
 <SomeBot> Function: convert_uuencode
 <SomeBot> Syntax: string convert_uuencode ( string $data ) convert_uuencode() encodes a string using the uuencode algorithm. Uuencode translates all strings (including binary&#039;s ones) 
 <SomeBot> Description: into printable characters, making them safe for network transmissions. Uuencoded data is about 35% larger than the original.  
 <SomeBot> URL: http://php.net/manual/en/function.convert-uuencode.php 

=head1 DESCRIPTION

This allows people to look up PHP functions

=head1 CONFIGURATION

No configurable options.

=head1 DEPENDENCIES

This module depends on the following CPAN modules:

=over

=back

=head1 AUTHOR

This module was written by [NAS]peter

=head1 LICENSE AND COPYRIGHT

This module is Copyright 2012 [NAS]peter.

Released under the same licensing terms as Auto itself.

=cut

# vim: set ai et sw=4 ts=4:
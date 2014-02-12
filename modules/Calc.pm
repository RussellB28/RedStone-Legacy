# Module: Calc. See below for documentation.
# Copyright (C) 2010-2014 RedStone Development Group, et al.
# This program is free software; rights to this code are stated in doc/LICENSE.
package M::Calc;
use strict;
use warnings;
use API::Std qw(cmd_add cmd_del trans);
use API::IRC qw(privmsg notice);
use URI::Escape;
use JSON -support_by_pp;

# Initialization subroutine.
sub _init {
    # Create the CALC command.
    cmd_add('CALC', 0, 0, \%M::Calc::HELP_CALC, \&M::Calc::cmd_calc) or return;

    # Success.
    return 1;
}

# Void subroutine.
sub _void {
    # Delete the CALC command.
    cmd_del('CALC') or return;

    # Success.
    return 1;
}

# Help hash.
our %FHELP_CALC = (
    en => "This command will calculate an expression using Google Calculator. \2Syntax:\2 CALC <expression>",
    de => "Dieser Befehl berechnet einen Ausdruck mit den Google Rechner. \2Syntax:\2 CALC <expression>",
);

# Callback for CALC command.
sub cmd_calc {
    my ($src, @argv) = @_;

    # Create an instance of JSON.
    my $json = JSON->new();    
    
    # Put together the call to the Google Calculator API. 
    if (!defined $argv[0]) {
        notice($src->{svr}, $src->{nick}, trans('Not enough parameters').q{.});
        return;
    }
    my $expr = join ' ', @argv;
    my $url = 'http://www.google.com/ig/calculator?q='.uri_escape($expr);
    # Get the response via HTTP.

    $Auto::http->request(
        url => $url,
        on_response => sub {
            my $response = shift;
            if (!$response->is_success)
            {
                privmsg($src->{svr}, $src->{target}, 'An error occurred while sending your expression to Google Calculator.');
                return;
            }
            # Get data  parse it.
            my $data = $json->allow_nonref->relaxed->escape_slash->loose->allow_singlequote->allow_barekey->decode($response->decoded_content);

            if ($data->{error} eq q{} or $data->{error} eq 0) {
                # And send to channel
                privmsg($src->{svr}, $src->{target}, "Result: $data->{lhs} = $data->{rhs}");
            }
            else {
                # Otherwise, send an error message.
                privmsg($src->{svr}, $src->{target}, 'Google Calculator sent an error.');
            }
        },
        on_error => sub {
            my $error = shift;
            privmsg($src->{svr}, $src->{target}, "An error occurred while sending your expression to Google Calculator: $error");
        }
    );

    return 1;
}

# Start initialization.
API::Std::mod_init('Calc', 'Xelhua', '1.02', '3.0.0a11');
# build: cpan=URI::Escape,JSON,JSON::PP perl=5.010000

__END__

=head1 NAME

Calc - Interface to Google Calculator

=head1 VERSION

 1.01

=head1 SYNOPSIS

 <starcoder> !calc 1+1
 <blue> Result: 1 + 1 = 2

=head1 DESCRIPTION

This module creates the CALC command for evaluating expressions on Google
Calculator and returning the result.

=head1 DEPENDENCIES

This module depends on the following CPAN modules:

=over

=item L<URI::Escape>

This is used to escape special characters from expressions.

=item L<JSON>

This is used to parse the data returned by the Google Calculator API.

=back

=head1 AUTHOR

This module was written by Matthew Barksdale.

This module is maintained by RedStone Development Group.

=head1 LICENSE AND COPYRIGHT

This module is Copyright 2010-2014 RedStone Development Group.

Released under the same licensing terms as RedStone itself.

=cut

# vim: set ai et sw=4 ts=4:

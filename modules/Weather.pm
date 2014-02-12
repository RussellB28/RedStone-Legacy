# Module: Weather. See below for documentation.
# Copyright (C) 2010-2014 RedStone Development Group, et al.
# This program is free software; rights to this code are stated in doc/LICENSE.
package M::Weather;
use strict;
use warnings;
use API::Std qw(cmd_add cmd_del trans);
use API::IRC qw(privmsg notice);
use XML::Simple;

# Initialization subroutine.
sub _init  {
    # Create the Weather command.
    cmd_add('WEATHER', 0, 0, \%M::Weather::HELP_WEATHER, \&M::Weather::weather) or return;

    # Success.
    return 1;
}

# Void subroutine.
sub _void  {
    # Delete the Weather command.
    cmd_del('WEATHER') or return;

    # Success.
    return 1;
}

# Help hashes.
our %HELP_WEATHER = (
    en => "This command will retrieve the weather via Wunderground for the specified location. \002Syntax:\002 WEATHER <location>",
    fr => "Cette commande permet de récupérer la météo via Wunderground pour l'emplacement spécifié. \002Syntaxe:\002 WEATHER <emplacement>",
);

# Callback for Weather command.
sub weather {
    my ($src, @args) = @_;

    # Put together the call to the Wunderground API. 
    if (!defined $args[0]) {
        notice($src->{svr}, $src->{nick}, trans('Not enough parameters').".");
        return;
    }
    my $loc = join(' ', @args);
    $loc =~ s/ /%20/g;
    my $url = "http://api.wunderground.com/auto/wui/geo/WXCurrentObXML/index.xml?query=".$loc;

    $Auto::http->request(
        url => $url,
        on_response => sub {
            my $response = shift;

            if ($response->is_success) {
                # If successful, decode the content.
                my $d = XMLin($response->decoded_content);
                # And send to channel
                if (!ref($d->{observation_location}->{country})) {
                    my $windc = $d->{wind_string};
                    if (substr($windc, length($windc) - 1, 1) eq " ") { $windc = substr($windc, 0, length($windc) - 1) }
                    privmsg($src->{svr}, $src->{target}, "Results for \2".$d->{observation_location}->{full}."\2 - \2Temperature:\2 ".$d->{temperature_string}." \2Wind Conditions:\2 ".$windc." \2Conditions:\2 ".$d->{weather});
                    privmsg($src->{svr}, $src->{target}, "\2Heat index:\2 ".$d->{heat_index_string}." \2Humidity:\2 ".$d->{relative_humidity}." \2Pressure:\2 ".$d->{pressure_string}." - ".$d->{observation_time});
                }
                else {
                    # Otherwise, send an error message.
                    privmsg($src->{svr}, $src->{target}, 'Location not found.');
                }
            }
            else {
                # Otherwise, send an error message.
                privmsg($src->{svr}, $src->{target}, 'An error occurred while retrieving your weather.');
            }
        },
        on_error => sub {
            my $error = shift;
            privmsg($src->{svr}, $src->{target}, "An error occurred while retrieving your weather: $error");
        },
    );

    return 1;
}

# Start initialization.
API::Std::mod_init('Weather', 'Xelhua', '1.02', '3.0.0a11');
# build: cpan=XML::Simple perl=5.010000

__END__

=head1 Weather

=head2 Description

=over

This module adds the WEATHER command for retrieving the 
current weather.

=back

=head2 Examples

=over

<JohnSmith> !weather 10111
<Auto> Results for Central Park, New York - Temperature: 27 F (-3 C) Wind Conditions: 
From the NE at 9 MPH Gusting to 22 MPH Conditions: Overcast
<Auto> Heat index: NA Humidity: 89% Pressure: 30.22 in (1023 mb) - Last Updated on February 1, 9:51 PM EST

=back

=head2 To Do

=over

* Add Spanish, French and German translations for the help hashes.

=back

=head2 Technical

=over

This module requires LWP::UserAgent and XML::Simple. Both are 
obtainable from CPAN <http://www.cpan.org>.

This module is compatible with RedStone version 3.0.0a10+.

=back

# vim: set ai et sw=4 ts=4:

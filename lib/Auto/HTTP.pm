# Copyright (c) 2013 Auto Development Group
# see doc/LICENSE for license information.
package Auto::HTTP;
use Net::Async::HTTP;
use URI;
use API::Log qw(dbug);

sub new { 
    my $http = Net::Async::HTTP->new(
        user_agent => 'Auto IRC Bot',
    );
    $Auto::loop->add($http);
    return bless {
        http => $http,
    }, shift;
}

sub http { return shift->{http}; }

sub request {
    my ($self, %args) = @_;

    foreach my $what (qw|url on_response on_error|) {
        next if defined $args{$what};
        dbug("Auto::HTTP request is missing the '$what' parameter.");
        return 0;
    }

    $args{ua} ||= 'RedStone IRC Bot';
    $self->http->{user_agent} = delete $args{ua};

    my $uri = URI->new($args{url});
    dbug('Auto::HTTP request was unable to create a URI object with the provided URL. Please verify it is properly formed.') and return 0 if !$uri->can('host');

    $self->http->do_request(
        uri => $uri,
        %args
    );
}

1;

# vim: set ai et sw=4 ts=4:

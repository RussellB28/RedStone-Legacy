# Copyright (c) 2013-2014 RedStone Development Group
# see doc/LICENSE for license information.
package Auto::Attributes;

use warnings;
use strict;
use 5.010;

sub import {
    my $package = caller;
    no strict 'refs';
    foreach my $sym (@_[1..$#_]) {
        my $name = $sym;

        # this is quite ugly, but it's the only way to do it for compatibility with perl 5.10
        my $symb = substr $name, 0, 1;
        my $code;

        given ($sym) {
            when (['@', '%']) {
                $name = substr $name, 1;
                continue;
            }

            # array
            when ('@') {
                $code = sub {
                    my $self = shift;
                    if ($self->{$name} && ref $self->{$name} eq 'ARRAY') {
                        return @{$self->{$name}};
                    }
                    # empty array
                    return @{$self->{$name} = []};
                }
            }

            # hash
            when ('%') {
                $code = sub {
                    my $self = shift;
                    if ($self->{$name} && ref $self->{$name} eq 'HASH') {
                        return %{$self->{$name}};
                    }
                    # empty hash
                    return %{$self->{$name} = {}};
                }
            }

            # scalar
            default {
                $code = sub { shift->{$name} }
            }
        }

        *{$package.q(::).$name} = $code;
    }
}

1;

# vim: set ai et sw=4 ts=4:

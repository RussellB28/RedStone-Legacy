# lib/API/Socket.pm - Socket manipulation subroutines.
# Copyright (C) 2010-2013 Auto Development Group, et al.
# This program is free software; rights to this code are stated in doc/LICENSE.
package API::Socket;
use strict;
use warnings;
use API::Log qw(alog dbug);
use API::Std qw(err);
use Exporter;
use base qw(Exporter);
use POSIX;

our @EXPORT_OK = qw(add_socket del_socket send_socket is_socket on_disconnect);

sub add_socket {
    my ($id, $object, $handler) = @_;
    alog('add_socket(): Socket already exists.') and return if defined($Auto::SOCKET{$id});
    alog('add_socket(): Specified handler is not valid.') and return if ref($handler) ne 'CODE';
    alog('add_socket(): Specified socket object is not defined.') and return if !defined $object;
    alog('add_socket(): Specified socket object is not a valid IO::Socket object.') and return if !$object->isa('IO::Handle');
    $Auto::SOCKET{$id}{handler} = $handler;
    $Auto::SOCKET{$id}{socket} = $object;
    if (Auto::is_ircsock($id) and ref($object) ne 'IO::Socket::SSL') {
        binmode($object, ':encoding(UTF-8)');
    }
    my $stream = $Auto::SOCKET{$id}{stream} = IO::Async::Stream->new(
        handle  => $object,
        on_read => sub {
            my (undef, $buffref, $eof) = @_;
            while ($$buffref =~ s/^(.*)\n//) {
                my $type = (Auto::is_ircsock($id) ? 'IRC' : 'Socket');
                dbug "[$type] $id << $1";
                &{$handler}($id, $1);
            }
        },
        on_read_eof => sub {
            API::Socket::on_disconnect($id);
        }
        on_write_eof => sub {
            API::Socket::on_disconnect($id);
        },
        on_read_error => sub {
            API::Socket::on_disconnect($id);
        },
        on_write_error => sub {
            API::Socket::on_disconnect($id);
        },
    );
    $Auto::loop->add($stream);
    alog("add_socket(): Socket $id added.");
    return 1;
}

sub del_socket {
    my ($id) = @_;
    return if !defined($Auto::SOCKET{$id});
    $Auto::SOCKET{$id}{stream}->close_when_empty;
    $Auto::loop->remove($Auto::SOCKET{$id}{stream});
    delete $Auto::SOCKET{$id};
    alog("del_socket(): Socket $id deleted.");
    return 1;
}

sub send_socket {
    my ($id, $data) = @_;
    if (defined($Auto::SOCKET{$id})) {
        if (Auto::is_ircsock($id)) {
            $Auto::SOCKET{$id}{stream}->write("$data\r\n");
            dbug "[IRC] $id >> $data";
        }
        else {
            $Auto::SOCKET{$id}{stream}->write($data);
            dbug "[Socket] $id >> $data";
        }
    }
    else {
        return;
    }
    return 1;
}

sub is_socket {
    my ($id) = @_;
    return 1 if defined($Auto::SOCKET{$id});
    return 0;
}

sub on_disconnect {
    my $id = shift;
    err(2, "Lost connection to $id!", 0);
    del_socket($id);
    API::Std::event_run('on_disconnect', $id) if Auto::is_ircsock($id);
    my $i = 0;
    foreach (keys %Auto::SOCKET) { $i++ if Auto::is_ircsock($_); }
    if (!$i) {
        API::Std::event_run('on_shutdown');
        dbug '* No more IRC connections, shutting down.';
        alog '* No more IRC connections, shutting down.';
        sleep 1;
        exit;
    }
}


1;
# vim: set ai et sw=4 ts=4:

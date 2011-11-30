# lib/API/Socket.pm - Socket manipulation subroutines.
# Copyright (C) 2010-2011 Xelhua Development Group, et al.
# This program is free software; rights to this code are stated in doc/LICENSE.
package API::Socket;
use strict;
use warnings;
use API::Log qw(alog dbug);
use API::Std qw(conf_get);
use Exporter;
use base qw(Exporter);
use POSIX;

our @EXPORT_OK = qw(add_socket del_socket send_socket is_socket);

sub add_socket {
    my ($id, $object, $handler) = @_;
    alog('add_socket(): Socket already exists.') if defined($Auto::SOCKET{$id});
    alog('add_socket(): Specified handler is not valid.') if ref($handler) ne 'CODE';
    alog('add_socket(): Specified socket object is not a valid IO::Socket object.') if !$object->isa('IO::Handle');
    $Auto::SOCKET{$id}{handler} = $handler;
    $Auto::SOCKET{$id}{socket} = $object;
    if (conf_get("server:$id") and ref($object) ne 'IO::Socket::SSL') {
        binmode($object, ':encoding(UTF-8)');
    }
    $Auto::SELECT->add($object);
    alog("add_socket(): Socket $id added.");
    return 1;
}

sub del_socket {
    my ($id) = @_;
    return if !defined($Auto::SOCKET{$id});
    $Auto::SELECT->remove($Auto::SOCKET{$id}{socket});
    delete $Auto::SOCKET{$id};
    alog("del_socket(): Socket $id deleted.");
    return 1;
}

sub send_socket {
    my ($id, $data) = @_;
    if (defined($Auto::SOCKET{$id})) {
        syswrite $Auto::SOCKET{$id}{socket}, "$data\r\n", POSIX::BUFSIZ, 0;
        if (conf_get("server:$id")) {
            dbug "[IRC] $id >> $data";
        }
        else {
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


1;
# vim: set ai et sw=4 ts=4:

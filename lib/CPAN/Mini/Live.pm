package CPAN::Mini::Live;
use strict;
use warnings;
use AnyEvent::FriendFeed::Realtime;
use base qw( CPAN::Mini );
our $VERSION = '0.33';

sub update_mirror {
    my $self = shift;
    $self = $self->new(@_) unless ref $self;

    # first we have to catch up if we've missed anything
    $self->SUPER::update_mirror();

    # and now we try being live
    warn "and live...\n";
    my $done   = AnyEvent->condvar;
    my $client = AnyEvent::FriendFeed::Realtime->new(
        request  => '/feed/minicpan',
        on_entry => sub {
            my $entry = shift;
            my $body  = $entry->{body};
            my ($action) = $body =~ /^(.+?) /;
            my ($uri)    = $body =~ /href="(.+?)"/;
            my $path     = $uri;
            my $remote   = $self->{remote};
            $path =~ s/^$remote//;
            my $local_file
                = File::Spec->catfile( $self->{local}, split m{/}, $path );
            warn "live [$action] [$path]";

            if ( $action eq 'mirror_file' ) {
                $self->mirror_file($path);
            } elsif ( $action eq 'clean_file' ) {
                $self->clean_file($local_file);
            } else {
                warn "ERROR: unknown action $action";
            }
        },
        on_error => sub {
            warn "ERROR: $_[0]";
            $done->send;
        },
    );
    $done->recv;
}

1;

__END__


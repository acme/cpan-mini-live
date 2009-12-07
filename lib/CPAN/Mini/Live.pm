package CPAN::Mini::Live;
use strict;
use warnings;
use AnyEvent::FriendFeed::Realtime;
use Net::FriendFeed;
use base qw( CPAN::Mini );
our $VERSION = '0.33';

sub update_mirror {
    my $self = shift;
    $self = $self->new(@_) unless ref $self;

    # first we have to catch up if we've missed anything
    my $friendfeed = Net::FriendFeed->new();
    my @recent     = @{ $friendfeed->fetch_user_feed('minicpan')->{entries} };
    my @todo;
    foreach my $entry (@recent) {
        my $action = $entry->{title};
        my $uri    = $entry->{link};
        my $path   = $uri;
        my $remote = $self->{remote};
        $path =~ s/^$remote//;
        my $local_file
            = File::Spec->catfile( $self->{local}, split m{/}, $path );
        warn "? $action $path";
        if (   $action eq 'mirror_file'
            && $path =~ /authors/
            && $path !~ /CHECKSUMS/
            && -f $local_file )
        {
            last;
        } elsif ( $action eq 'clean_file'
            && $path =~ /authors/
            && !-f $local_file )
        {
            last;
        } else {
            push @todo, [ $action, $path, $uri, $local_file ];
        }
    }

    if ( @todo == @recent ) {
        die "Too much out of date, please run a manual sync first";
    }

    if (@todo) {
        foreach my $entry (@todo) {
            my ( $action, $path, $uri, $local_file ) = @$entry;
            warn "todo: $action $path\n";
            if ( $action eq 'mirror_file' ) {
                $self->mirror_file($path);
            } else {
                $self->clean_file($local_file);
            }
        }
    }

    warn "and live...\n";

    # and now we try being live
    my $done   = AnyEvent->condvar;
    my $client = AnyEvent::FriendFeed::Realtime->new(
        request  => '/feed/minicpan',
        on_entry => sub {
            my $entry = shift;
            use YAML;
            warn Dump $entry;
            my $body = $entry->{body};
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


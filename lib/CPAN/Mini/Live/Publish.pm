package CPAN::Mini::Live::Publish;
use strict;
use warnings;
use base qw( CPAN::Mini );
use File::Spec;
use File::Slurp;
use Net::FriendFeed;

sub mirror_file {
    my ( $self, $path, $skip_if_present, $arg ) = @_;

    my $remote_uri
        = eval { $path->isa('URI') }
        ? $path
        : URI->new_abs( $path, $self->{remote} )->as_string;

    my $local_file
        = File::Spec->catfile(
        $arg->{to_scratch} ? $self->{scratch} : $self->{local},
        split m{/}, $path );

    my $file_exists = -f $local_file;
    my ( $contents, $atime, $mtime );
    if ($file_exists) {
        ( $atime, $mtime ) = ( stat $local_file )[ 8, 9 ];
        $contents = read_file($local_file);
    }

    my $return = $self->SUPER::mirror_file( $path, $skip_if_present, $arg );
    $skip_if_present ||= 0;

    my $mirrored = $self->{mirrored}{$local_file};

    if (   $mirrored == 2
        && $self->{recent}->{$path}
        && !$self->{_friendfeed_seen}->{$path}++ )
    {
        eval { $self->notify( 'mirror_file', $remote_uri ); };
        if ($@) {
            if ($file_exists) {
                write_file( $local_file, $contents );
                utime( $atime, $mtime, $local_file );
            } else {
                unlink($local_file);
            }
            die $@;
        }
    }
    return $return;
}

sub clean_file {
    my ( $self, $file ) = @_;

    my $file_exists = -f $file;
    my ( $contents, $atime, $mtime );
    if ($file_exists) {
        ( $atime, $mtime ) = ( stat $file )[ 8, 9 ];
        $contents = read_file($file);
    }

    my $return = $self->SUPER::clean_file($file);

    my $path  = $file;
    my $local = $self->{local};
    $path =~ s/^$local//;

    # full URL
    my $remote_uri
        = eval { $path->isa('URI') }
        ? $path
        : URI->new_abs( $path, $self->{remote} )->as_string;

    if ( $path ne 'RECENT' ) {
        eval { $self->notify( 'clean_file', $remote_uri ); };

        if ($@) {
            if ($file_exists) {
                write_file( $file, $contents );
                utime( $atime, $mtime, $file );
            }
            die $@;
        }
    }
    return $return;
}

sub notify {
    my ( $self, $action, $uri ) = @_;
    my $friendfeed = $self->{_friendfeed};
    unless ( $self->{_friendfeed} ) {
        my %config    = CPAN::Mini->read_config;
        my $username  = $config{friendfeed_username};
        my $remotekey = $config{friendfeed_remotekey};
        $friendfeed = Net::FriendFeed->new(
            { login => $username, remotekey => $remotekey } );
        $friendfeed->validate || die $friendfeed->last_error;
        $self->{_friendfeed} = $friendfeed;
    }
    warn "$action $uri\n";
    $friendfeed->publish_link( $action, $uri )
        || die $friendfeed->last_error;
}

1;

__END__

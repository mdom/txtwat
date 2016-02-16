package App::twtxtpl;

use strict;
use warnings;
use Getopt::Long qw(GetOptionsFromArray);
use Config::Tiny;
use Path::Tiny;
use Mojo::UserAgent;
use Moo;
use App::twtxtpl::Tweet;
use IO::Pager;
use String::ShellQuote;
use File::Basename qw(basename);

our $VERSION = '0.01';

has name => ( is => 'ro', default => sub { basename $0 } );
has config => ( is => 'lazy' );
has config_file =>
  ( is => 'ro', default => sub { path('~/.config/twtxt/config') } );

sub _build_config {
    my ($self) = @_;
    unless ( $self->config_file->exists ) {
        $self->config_file->parent->mkpath;
        $self->config_file->touch;
    }
    my $config   = Config::Tiny->read( $self->config_file->stringify );
    my %defaults = (
        check_following   => 1,
        use_pager         => 1,
        use_cache         => 1,
        disclose_identity => 0,
        limit_timeline    => 20,
        timeout           => 5,
        sorting           => 'descending',
        time_format       => '%F %H:%M',
        twtfile           => path('~/twtxt'),
    );
    $config->{twtxt} = { %defaults, %{ $config->{twtxt} || {} } };
    return $config;
}

sub run {
    my ( $self, $subcommand ) = splice( @_, 0, 2 );
    my %subcommands =
      map { $_ => 1 } qw(timeline follow unfollow following tweet view );
    if ( $subcommands{$subcommand} and $self->can($subcommand) ) {
        $self->$subcommand(@_);
    }
    else {
        die $self->name . ": Unknown subcommand $subcommand.\n";
    }
    return 0;

}

sub timeline {
    my $self = shift;
    my $ua   = Mojo::UserAgent->new();
    $ua->request_timeout( $self->config->{twtxt}->{timeout} );
    $ua->max_redirects(5);
    my @tweets;
    Mojo::IOLoop->delay(
        sub {
            my $delay = shift;
            while ( my ( $user, $url ) = each %{ $self->config->{following} } )
            {
                $delay->pass($user);
                $ua->get( $url => $delay->begin );
            }
        },
        sub {
            my ( $delay, @results ) = @_;
            while ( my ( $user, $tx ) = splice( @results, 0, 2 ) ) {

                if ( my $res = $tx->success ) {
                    push @tweets, map {
                        App::twtxtpl::Tweet->new(
                            user      => $user,
                            timestamp => $_->[0],
                            text      => $_->[1]
                          )
                      }
                      map { [ split /\t/, $_, 2 ] }
                      split( /\n/, $res->body );
                }
                else {
                    my $err = $tx->error;
                    warn "Failing to get tweets for $user: "
                      . (
                        $err->{code}
                        ? "$err->{code} response: $err->{message}"
                        : "Connection error: $err->{message}"
                      ) . "\n";

                }
            }
        }
    )->wait;
    @tweets = sort {
            $self->config->{twtxt}->{sorting} eq 'descending'
          ? $b->timestamp->epoch <=> $a->timestamp->epoch
          : $a->timestamp->epoch <=> $b->timestamp->epoch
    } @tweets;
    my $fh;
    if ( $self->config->{twtxt}->{use_pager} ) {
        IO::Pager->new($fh);
    }
    else {
        $fh = \*STDOUT;
    }
    my $limit = $self->config->{twtxt}->{limit_timeline} - 1;
    for my $tweet ( @tweets[ 0 .. $limit ] ) {
        printf {$fh} "%s %s: %s\n",
          $tweet->strftime( $self->config->{twtxt}->{time_format} ),
          $tweet->user, $tweet->text;
    }
}

sub tweet {
    my ( $self, $text ) = @_;
    my $tweet = App::twtxtpl::Tweet->new( text => $text );
    my $file = path( $self->config->{twtxt}->{twtfile} );
    $file->touch unless $file->exists;
    $file->append_utf8( $tweet->to_string . "\n" );
    return;
}

sub follow {
    my ( $self, $whom, $url ) = @_;
    $self->config->{following}->{$whom} = $url;
    $self->config->write( $self->config_file, 'utf8' );
    return;
}

sub unfollow {
    my ( $self, $whom, $url ) = @_;
    delete $self->config->{following}->{$whom};
    $self->config->write( $self->config_file, 'utf8' );
    print "You've unfollowed $whom.\n";
    return;
}

sub following {
    my ( $self, $whom, $url ) = @_;
    for my $user ( keys %{ $self->config->{following} } ) {
        print "$user \@ " . $self->config->{following}->{$user} . "\n";
    }
    return;
}

1;

__END__

=pod

=head1 NAME

twtxtpl - Decentralised, minimalist microblogging service for hackers

=head1 COPYRIGHT AND LICENSE

Copyright 2015 Mario Domgoergen C<< <mario@domgoergen.com> >>

This program is free software: you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free Software
Foundation, either version 3 of the License, or (at your option) any later
version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with
this program.  If not, see <http://www.gnu.org/licenses/>.

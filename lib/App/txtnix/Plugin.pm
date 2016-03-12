package App::txtnix::Plugin;
use strict;
use warnings;
use Mojo::Base -base;

has 'app';
has handlers => sub { {} };
has config   => sub { shift->_build_config };

sub _build_config {
    my $self = shift;
    my ($name) = ref($self) =~ /^.*::(.*)$/;
    return $self->app->read_config->{$name};
}

sub is_enabled {
    my $self   = shift;
    my $config = $self->config;
    return defined $self->config && $self->config->{enabled};
}

1;

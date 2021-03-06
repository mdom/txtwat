package App::txtnix::Cmd::config::edit;
use Mojo::Base 'App::txtnix';

sub run {
    my ( $self, $opts ) = @_;
    my $editor = $ENV{VISUAL} || $ENV{EDITOR} || 'vi';
    system( $editor, $self->config_file ) == 0
      or die "Can't edit configuration file: $!\n";
    return 0;
}

1;

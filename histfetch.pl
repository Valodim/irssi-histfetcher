# ZNC Mysql Log query backlog
#
use strict;

use vars qw($VERSION %IRSSI);
$VERSION = '2011121001';
%IRSSI = (
    authors     => 'Valodim',
    contact     => 'valodim@mugenguild.com',
    name        => 'histfetch',
    description => 'requests a backlog from the bnc server on query window',
    license     => 'GPLv2',
    changed     => $VERSION,
);  

use Irssi 20020324;

sub sig_window_item_new ($$) {
    my ($win, $witem) = @_;

    return unless (ref $witem && $witem->{type} eq 'QUERY');

    my $name = lc $witem->{name};

    my ($read_handle, $write_handle);
    pipe($read_handle, $write_handle);

    my $oldfh = select($write_handle);
    $| = 1;
    select $oldfh;

    my $pid = fork();

    if ($pid > 0) { # parent

        close($write_handle);
        Irssi::pidwait_add($pid);

        my $job = $pid;
        my $tag;
        my @args = ($read_handle, \$tag, $job, $win);
        $tag = Irssi::input_add(fileno($read_handle),
            Irssi::INPUT_READ,
            \&child_input,
            \@args);

    } else { # child

        my $msgs = `ssh -o ConnectTimeout=2 $witem->{server}->{address} ./histfetcher $witem->{server}->{tag} $name 2>&1`;

        print $write_handle $msgs;
        print $write_handle "__DONE__";
        close($write_handle);

        POSIX::_exit(1);
    }

}

sub child_input {
    my $args = shift;
    my ($read_handle, $input_tag_ref, $job, $win) = @$args;

    my $data = <$read_handle>;

    if ($data =~ m/__DONE__/) {
        close($read_handle);
        Irssi::input_remove($$input_tag_ref);
    } else {
        $win->print(substr($data, 0, -1), MSGLEVEL_NOHILIGHT);
    }

}

# Irssi::settings_add_int($IRSSI{name}, 'queryresume_host', 10);
Irssi::signal_add('window item new', 'sig_window_item_new');

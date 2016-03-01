package Vmprobe::Probe::cache::restore;

use common::sense;

use Vmprobe::Cache;
use Vmprobe::Cache::Snapshot;

sub run {
    my ($params) = @_;

    die "need path" if !defined $params->{path};
    die "need snapshot" if !defined $params->{snapshot};
    die "can't specify both save and diff" if defined $params->{save} && defined $params->{diff};

    if (defined $params->{save}) {
        $Vmprobe::Cache::snapshots->{$params->{save}} = $params->{snapshot};
    }

    my $snapshot;

    if (defined $params->{diff}) {
        my $before = $Vmprobe::Cache::snapshots->{$params->{diff}};
        die "unknown snapshot id: $params->{diff}" if !defined $before;

        $snapshot = Vmprobe::Cache::Snapshot::delta($before, $params->{snapshot});

        $Vmprobe::Cache::snapshots->{$params->{diff}} = $snapshot;
    } else {
        $snapshot = $params->{snapshot};
    }

    my $snapshot = Vmprobe::Cache::Snapshot::restore($params->{path}, $params->{snapshot});

    return {};
}

1;

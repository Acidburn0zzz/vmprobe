package Vmprobe::Viewer::Page::ProbeFiles;

use common::sense;

use Curses;

use Vmprobe::Cache::Snapshot;
use Vmprobe::Util;

use parent 'Vmprobe::Viewer::Page::BaseProbe';




our $bindings = [
    {
        key => 's',
        desc => 'change sort order',
        cb => sub {
                  my ($self) = @_;

                  $self->{selected_type_index}++;
                  $self->{selected_type_index} = 0 if $self->{selected_type_index} >= @{ $self->{snapshot_types} };

                  $self->schedule_draw(1);
                  $self->draw(0) if !$self->hidden && $self->in_topwindow;
              },
    },
];




sub process_entry {
    my ($self, $entry) = @_;

    my $output = {};

    foreach my $key (keys %{ $entry->{data}->{snapshots} }) {
        $output->{$key} = Vmprobe::Cache::Snapshot::parse_records($entry->{data}->{snapshots}->{$key}, $self->width - 35, 0);
    }

    $self->{latest} = $output;
}




sub render {
    my ($self, $canvas) = @_;

    my @snapshot_types = sort keys %{ $self->{latest} };
    $self->{snapshot_types} = \@snapshot_types;

    my $sort_field = $snapshot_types[$self->{selected_type_index}];


    my $by_file = {};

    foreach my $type (@snapshot_types) {
        foreach my $record (@{ $self->{latest}->{$type} }) {
            $by_file->{$record->{filename}}->{$type} = $record;
        }
    }

    my $curr_line = 0;

    $canvas->attron(Curses::COLOR_PAIR($Curses::UI::color_object->get_color_pair('green', 'black')));
    $canvas->addstring($curr_line, 0, "(s)ort by:  ");
    foreach my $type (@snapshot_types) {
        my @colours = $type eq $sort_field ? qw(black green) : qw(green black);

        $canvas->attron(Curses::COLOR_PAIR($Curses::UI::color_object->get_color_pair(@colours)));
        $canvas->addstring($type);
        $canvas->attroff(Curses::A_COLOR);
        $canvas->addstring("  ");
    }

    $curr_line += 2;


    foreach my $record (@{ $self->{latest}->{ $sort_field } }) {
        $canvas->addstring($curr_line++, 0, "$record->{filename}  " . pages2size($record->{num_pages}));

        foreach my $type (@snapshot_types) {
            my $subrecord = $by_file->{$record->{filename}}->{$type};

            my $resident = 0;
            my $rendered = '';

            if (defined $subrecord) {
                $resident = $subrecord->{num_resident_pages};
                $rendered = Vmprobe::Util::buckets_to_rendered($subrecord);
            }

            $canvas->addstring($curr_line++, 0, sprintf("  %-13s | %-10s | %s", $type, pages2size($resident), $rendered));
        }

        last if $curr_line + @snapshot_types >= $self->height;
    }
}



1;

package Monitoring::CheckMkAgent;

use strict;
use warnings;
use Carp;
use IO::Dir;
use parent qw/Class::Accessor/;
use Monitoring::CheckMkAgent::Section;

__PACKAGE__->mk_accessors(qw/host store_dir sections/);

my $STORE_DIR = '/var/lib/check_cmkagent';

sub new {
    my ($class, %args) = @_;
    my %this;

    # Check mandatory arguments
    for (qw/host/) {
        croak("No $_ given") unless defined $args{$_};
        $this{$_} = $args{$_};
    }

    # Validate arguments
    croak("Invalid host specification: \"@{[$this{host}]}\"")
        unless $this{host} =~ /^[a-zA-Z0-9._-]+$/;

    # Check and fill in optional arguments
    $this{store_dir} = $args{store_dir} // $STORE_DIR;

    # Initialize other members
    $this{sections} = [];

    # Fully realize instance
    return bless(\%this, $class);
}

sub from_agent_output {
    my ($class, %args) = @_;
    my @section_lines;
    my $this = __PACKAGE__->new(%args);

    # Read agent output file in if necessary
    my @output;

        my $store_dir = $args{store_dir} // $STORE_DIR;
        my $host = $args{host} // croak('No host given');

        my $fh = IO::File->new("$store_dir/$host");
        croak("Can't open agent output for host \"$host\": $!")
            unless defined $fh;
        while (my $line = $fh->getline) {
            chomp($line);
            push(@output, $line);
        }


    # Parse output into individual sections
    my %sections;
    my $current;
    for my $line (@output) {
        chomp($line);
        if ($line =~ /^\s*<<<([^>:]+)(?::[^>]+)?/) {
            $current = $1;
            $sections{$current} = [ $line ];
        }
        else {
            push(@{$sections{$current}}, $line) if defined $current;
        }
    }

    # Create sections
    while (my ($name, $output) = each(%sections)) {
        my $section = Monitoring::CheckMkAgent::Section->from_agent_output(
            $output
        );
        push(@{$this->sections}, $section) if defined $section;
    }

    return $this;
}

sub list {
    my ($class, %args) = @_;

    my $store_dir = $args{store_dir} // $STORE_DIR;
    my $dh = IO::Dir->new($store_dir);
    return () unless defined $dh;

    return grep({ -f "$store_dir/$_" } $dh->read);
}


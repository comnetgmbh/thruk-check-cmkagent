package Monitoring::CheckMkAgent::Section;

use strict;
use warnings;
use Carp;
use IO::Dir;

use parent qw/Class::Accessor/;
__PACKAGE__->mk_accessors(qw/
    name specialization entities
    threshold_attr
/);

sub new {
    my ($class, %args) = @_;

    my $this = \%args;
    for (qw/entities/) {
        $this->{$_} //= [];
    }

    return bless($this, $class);
}

sub from_agent_output {
    my ($class, $output) = @_;

    # Determine section name
    my $name;
    if ($output->[0] =~ /^\s*<<<([^>:]+)(?::[^>]+)?/) {
        $name = $1;
        unless (__PACKAGE__->_valid_sections->{$name}) {
            carp("Unknown section: \"$name\"");
            return undef;
        }
    }
    else {
        croak("Malformed agent output: Section header invalid");
    }

    # Instantiate
    my $this = eval("use ${class}::${name}; ${class}::${name}->new(name => \$name)");
    croak($@) if $@;

    # Parse section output
    for (@{$output}[1..$#{$output}]) {
        chomp;
        if (/^\s*[[]([^]]+)_(?:start|end)[]]$/) {
            $this->specialization($1);
        }
        else {
            $this->parse_line($_);
        }
    }

    return $this;
}

sub parse_line($$) {
    ...
}

sub _valid_sections {
    my $class = shift;
    my @ret;

    for my $dir (@INC) {
        my $dh = IO::Dir->new("$dir/Monitoring/CheckMkAgent/Section");
        next unless defined $dh;
        while (my $entry = $dh->read) {
            push(@ret, $1) if $entry =~ /^([^.]+)\.pm$/;
        }
    }

    return { map({ $_ => 1 } @ret) };
}

1;

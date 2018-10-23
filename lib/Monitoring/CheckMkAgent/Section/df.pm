package Monitoring::CheckMkAgent::Section::df;

use strict;
use warnings;
use Monitoring::CheckMkAgent::Section::df::Mount;

use parent qw/Monitoring::CheckMkAgent::Section/;

sub parse_line($$) {
    my ($this, $line) = @_;

    push(@{$this->entities},
        Monitoring::CheckMkAgent::Section::df::Mount->from_agent_output($line),
    );
}


1;

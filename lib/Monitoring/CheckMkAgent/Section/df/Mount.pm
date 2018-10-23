package Monitoring::CheckMkAgent::Section::df::Mount;

use strict;
use warnings;

my @attributes = qw/
    mountpoint filesystem total used free usage volume
/;
use parent qw/Monitoring::CheckMkAgent::Entity/;
__PACKAGE__->mk_accessors(@attributes);

sub from_agent_output($$) {
    my ($class, $line) = @_;
    my $this = $class->new;

    my @split = split(/\s+/, $line);
    if (@split != @attributes) {
        croak("Malformed df line \"$line\"");
    }

    for (my $i = 0; $i < @attributes; $i++) {
        $this->{$attributes[$i]} = $split[$i];
    }

    return $this;
}

1;

package Monitoring::CheckMkAgent::Section::mem;

use strict;
use warnings;
use Carp;

my %attributes = map({ $_ => 1} qw/
    mem_total mem_free
    swap_total swap_free
    page_total page_free
    virtual_total virtual_free
/);
use parent qw/Monitoring::CheckMkAgent::Section/;
__PACKAGE__->mk_accessors(keys(%attributes));

sub parse_line($$) {
    my ($this, $line) = @_;

    if ($line =~ /^([a-zA-z]+):\s+(\d+)\s+kB/) {
        my ($key, $value) = ($1, $2);
        my $attr = $key =~ s/([a-z])([A-Z])/$1_$2/r =~ tr/A-Z/a-z/r;
        croak("Invalid mem property: $key") unless $attributes{$attr};
        $this->$attr($value);
    }
    else {
        croak("Malformed mem line: \"$line\"");
    }
}

1;

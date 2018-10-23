#!/usr/bin/perl

use strict;
use warnings;
use File::Slurp qw/slurp/;
use Test::More tests => 3;

use_ok('Monitoring::CheckMkAgent::Section::mem');
isa_ok(Monitoring::CheckMkAgent::Section::mem->new, 'Monitoring::CheckMkAgent::Section::mem');

my $section = Monitoring::CheckMkAgent::Section::mem->from_agent_output(
    [ IO::File->new('t/split/mem')->getlines ],
);

is_deeply(
    $section,
    {
        'name'          => 'mem',
        'entities'      => [],
        'mem_total'     => '3071540',
        'mem_free'      => '1682980',
        'swap_total'    => '524288',
        'swap_free'     => '485980',
        'page_total'    => '3595828',
        'page_free'     => '2168960',
        'virtual_total' => '137438953344',
        'virtual_free'  => '137438832800',
    },
    'mem parses'
);

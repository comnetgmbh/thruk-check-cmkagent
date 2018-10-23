#!/usr/bin/perl

use strict;
use warnings;
use File::Slurp qw/slurp/;
use Test::More tests => 3;

use_ok('Monitoring::CheckMkAgent::Section::df');
isa_ok(Monitoring::CheckMkAgent::Section::df->new, 'Monitoring::CheckMkAgent::Section::df');

my $section = Monitoring::CheckMkAgent::Section::df->from_agent_output(
    [ IO::File->new('t/split/df')->getlines ],
);

is_deeply(
    $section->entities,
    [
        {
            'mountpoint' => 'C:\\',
            'total' => '51864572',
            'usage' => '38%',
            'volume' => 'C:\\',
            'filesystem' => 'NTFS',
            'free' => '32291900',
            'used' => '19572672',
        },
        {
            'usage' => '70%',
            'volume' => 'D:\\',
            'mountpoint' => 'D:\\',
            'total' => '1234',
            'used' => '112312',
            'filesystem' => 'NTFS',
            'free' => '567564'
        },
    ],
    'Entities correct',
);

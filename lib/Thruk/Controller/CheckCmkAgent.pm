package Thruk::Controller::CheckCmkAgent;

use strict;
use warnings;
use YAML;
use IO::File;
use IO::Dir;
use IO::Socket::INET;

my $AGENT_DIR = '/var/lib/check_cmkagent';
my $NAGIOS_DIR = 'etc/naemon/conf.d/';
my $VALID_HOST_REGEX = qr/^[a-zA-Z0-9._-]+$/;

sub add_routes {
    my($self, $app, $routes) = @_;

    $routes->{'/thruk/cgi-bin/check_cmkagent.cgi'} = 'Thruk::Controller::CheckCmkAgent::index';
    $routes->{'/thruk/cgi-bin/check_cmkagent_add.cgi'} = 'Thruk::Controller::CheckCmkAgent::add';

    # add new view item
    Thruk::Utils::Menu::insert_item(
        System => {
            href => '/thruk/cgi-bin/check_cmkagent.cgi',
            name => 'check_cmkagent',
        }
    );

    return;
}

sub collect_hosts {
    my @hosts = @_;
    my %hosts;

    unless (@hosts)  {
        my $dh = IO::Dir->new($AGENT_DIR);
        return unless defined $dh;

        while (my $entry = $dh->read) {
            push(@hosts, $entry);
        }
    }

    for my $entry (@hosts) {
        my $path = "$AGENT_DIR/$entry";
        next unless -f $path;

        $hosts{$entry} = {
            name => $entry,
            services => { collect_host_services($path) },
        };
    }

    return %hosts;
}

sub parse_cmkagent {
    my $path = shift;
    my @sections;

    my $fh = IO::File->new($path, 'r');
    while (my $line = $fh->getline) {
        if ($line =~ /^\s*<<<([^>:]+)(?::[^>]+)?/) {
            push(@sections, { section => $1, content => [] });
        }
        elsif ($line =~ /^\s*[[]([^]]+)_(?:start|end)[]]$/) {
            $sections[-1]->{specialization} = $1;
        }
        else {
            push(@{$sections[-1]->{content}}, $line);
        }
    }

    return @sections;
}

sub collect_host_services {
    my $path = shift;
    my %services;

    my @sections = parse_cmkagent($path);
    for my $section (@sections) {
        my %service = (
            %{$section},
            id => join('_', $section->{section}, ($section->{specialization} // '')),
        );
        my @services = ( \%service );

        if ($section->{section} eq 'df') {
            my $i = 0;
            @services = ();
            for my $line (@{$section->{content}}) {
                push(@services, {
                    %service,
                    content => $line,
                    entity => [split(/\s/, $line)]->[-1],
                    id => $service{id} . '_' . $i,
                });
                $i++;
            }
        }

        for (@services) {
            $services{$_->{id}} = $_;
        }
    }

    return %services;
}

sub index {
    my $c = shift;

    my $host = $c->req->parameters->{host};
    $host = undef unless $host =~ /$VALID_HOST_REGEX/;

    my @filter;
    push(@filter, $host) if defined $host;
    $c->stash->{hosts} = { collect_hosts(@filter) };
    $c->stash->{template} = 'check_cmkagent.tt';
}

sub add {
    my $c = shift;

    # Fetch arguments
    my $host = $c->req->parameters->{host};
    my $service = $c->req->parameters->{service};
    my $warn = $c->req->parameters->{warn};
    my $crit = $c->req->parameters->{crit};

    # Validate arguments
    return unless $host =~ /$VALID_HOST_REGEX/;
    return unless $service =~ /^[a-zA-Z0-9_]+$/;
    return unless $warn =~ /^\d+$/;
    return unless $crit =~ /^\d+$/;

    # Fetch host
    my %hosts = collect_hosts($host);
    my %service = %{%hosts->{$host}->{services}->{$service}};

    # Write service config
    my $service_cfg = "$NAGIOS_DIR/cmkagent_${host}_$service.cfg";
    my $service_fh = IO::File->new($service_cfg, 'w');
    die("Can't open $service_cfg: $!\n") unless defined $service_fh;
    print($service_fh <<EOF
define service {
	use                     generic-service
	host_name               $host
	service_description     $service{section}: $service{entity}
	check_command           check_cmkagent_passive!$service{section}!$service{entity}!$warn!$crit
}
EOF
);

    # Reload core
    for (@{$c->{db}->{backends}}) {
        Thruk::Utils::External::cmd($c, { cmd => $_->{'config'}->{'configtool'}->{'obj_reload_cmd'}." 2>&1", 'background' => 1 });
    }

    # Notify user about added service
    $c->stash->{added} = { host => $host, service => \%service };

    # Render index
    return Thruk::Controller::CheckCmkAgent::index($c);
}

1;


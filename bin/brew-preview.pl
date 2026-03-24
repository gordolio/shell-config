#!/usr/bin/env perl
# Preview script for bugi's fzf: shows brew info + GitHub release notes
# Usage: brew-preview.pl <F|C> <package-name>

use strict;
use warnings;
use JSON::PP;

binmode STDOUT, ':utf8';

my $type_tag = $ARGV[0] // 'F';
my $pkg      = $ARGV[1] // '';
exit 0 unless length $pkg;

my $json_flag = $type_tag eq 'C' ? '--cask' : '--formula';

# Get JSON info (used for both display and release notes)
my $info_raw = `brew info --json=v2 $json_flag \Q$pkg\E 2>/dev/null`;
exit 0 if $? != 0 || !length $info_raw;

# Collect all output, then print release notes first, then brew info
my $release_output = get_release_notes($info_raw);
my $info_text = `brew info $json_flag \Q$pkg\E 2>/dev/null`;

if (length($release_output // '')) {
    print $release_output;
    print "\n";
}

print $info_text if length($info_text // '');

sub get_release_notes {
    my ($json_str) = @_;

    my $info = decode_json($json_str);

    my $entry;
    if ($info->{formulae} && @{$info->{formulae}}) {
        $entry = $info->{formulae}[0];
    } elsif ($info->{casks} && @{$info->{casks}}) {
        $entry = $info->{casks}[0];
    }
    return unless $entry;

    my $gh_repo = extract_github_repo($entry) or return;
    my $version = extract_version($entry)      or return;
    my $release = fetch_release($gh_repo, $version) or return;

    my $name = $release->{name} // '';
    my $body = $release->{body} // '';
    return unless length $body;

    # Truncate to ~60 lines
    my @lines = split /\n/, $body;
    @lines = @lines[0..59] if @lines > 60;
    $body = join "\n", @lines;

    my $header = "Release Notes";
    $header .= " ($name)" if length $name;

    return "\x{2501}" x 3 . " $header " . "\x{2501}" x 3 . "\n" . $body . "\n";
}

sub extract_github_repo {
    my ($entry) = @_;

    my @sources;
    push @sources, $entry->{homepage} if $entry->{homepage};

    if (ref($entry->{urls}) eq 'HASH') {
        for my $v (values %{$entry->{urls}}) {
            if (ref $v eq 'HASH' && $v->{url}) {
                push @sources, $v->{url};
            } elsif (!ref $v) {
                push @sources, $v;
            }
        }
    } elsif ($entry->{url} && !ref $entry->{url}) {
        push @sources, $entry->{url};
    }

    for my $src (@sources) {
        if ($src =~ m{https?://github\.com/([^/]+/[^/]+?)(?:\.git|/releases/|/archive/|/|$)}) {
            return $1;
        }
    }
    return;
}

sub extract_version {
    my ($entry) = @_;

    if ($entry->{versions} && $entry->{versions}{stable}) {
        return $entry->{versions}{stable};
    }
    if ($entry->{version}) {
        return $entry->{version};
    }
    return;
}

sub fetch_release {
    my ($gh_repo, $version) = @_;

    my @auth;
    if ($ENV{HOMEBREW_GITHUB_API_TOKEN}) {
        @auth = ('-H', "Authorization: token $ENV{HOMEBREW_GITHUB_API_TOKEN}");
    }

    # Try GitHub Releases first: v1.2.3, 1.2.3, then latest
    for my $prefix ('v', '', undef) {
        my $url;
        if (defined $prefix) {
            $url = "https://api.github.com/repos/${gh_repo}/releases/tags/${prefix}${version}";
        } else {
            $url = "https://api.github.com/repos/${gh_repo}/releases/latest";
        }

        my $data = api_get($url, \@auth) or next;
        return $data if $data->{body};
    }

    # Fall back to annotated tag messages (e.g. git, which doesn't use GitHub Releases)
    for my $prefix ('v', '') {
        my $ref = api_get(
            "https://api.github.com/repos/${gh_repo}/git/ref/tags/${prefix}${version}",
            \@auth,
        ) or next;

        my $obj = $ref->{object} // {};
        next unless ($obj->{type} // '') eq 'tag';

        my $tag = api_get($obj->{url}, \@auth) or next;
        my $msg = $tag->{message} // '';
        $msg =~ s/-----BEGIN PGP SIGNATURE-----.*//s;
        $msg =~ s/\s+\z//;
        next unless length $msg;

        return { name => $tag->{tag} // '', body => $msg };
    }

    return;
}

sub api_get {
    my ($url, $auth) = @_;

    open my $fh, '-|', 'curl', '-sf', @$auth, $url or return;
    local $/;
    my $body = <$fh>;
    close $fh;
    return if $? != 0 || !length($body // '');

    return eval { decode_json($body) };
}

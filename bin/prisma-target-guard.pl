#!/usr/bin/perl
# prisma-target-guard.pl - block destructive Prisma commands aimed at a non-local DB
#
# Usage: prisma-target-guard.pl <package-manager> <args...>
#        exit 0 = allow, exit 1 = block (reason on STDERR)
#
# Called from the npm/yarn/pnpm wrappers in {fish,zsh}config/personal.d/
# js-package-managers.*, which every `yarn ...` invocation already funnels through.
#
# Why: `yarn prisma migrate dev` takes its target from whatever MYSQL_URL is in the
# repo's .env, and those files get swapped between local and staging copies. Nothing
# in the command line says which database it hit, so a stale .env silently points a
# migration at staging. This resolves the URL the same way mft-api's prisma.config.ts
# does (real env wins over .env, since dotenv does not override existing vars) and
# refuses to run when the host is not local.
#
# `npx prisma ...` is refused outright instead of target-checked. It sidesteps the
# yarn wrapper entirely, and npx will happily fetch a prisma release that differs from
# the one the workspace pins, so there is no invocation of it worth allowing here.
#
# Deliberate remote run: PRISMA_GUARD_ALLOW_REMOTE=1 yarn prisma migrate deploy
# Extra local hostnames:  PRISMA_GUARD_LOCAL_HOSTS="db.test,10.0.0.5"
# Confirm the target:     PRISMA_GUARD_VERBOSE=1

use strict;
use warnings;
use JSON::PP;

# Subcommands that write to (or read from) the live database. `migrate diff`,
# `migrate status`, `generate`, `validate` and `format` are absent on purpose:
# they are either offline or harmless against a remote, and blocking them would
# only train us to set the override reflexively.
my %DESTRUCTIVE = (
    migrate => [qw(dev reset deploy resolve)],
    db      => [qw(push execute seed pull)],
);

# Hosts that mean "this machine". Anything else is treated as remote: an allowlist
# fails safe, where a staging-hostname denylist would miss the next environment.
my @LOCAL_HOSTS = qw(
    localhost
    127.0.0.1
    0.0.0.0
    ::1
    host.docker.internal
    docker.for.mac.host.internal
);

my @URL_KEYS = qw(MYSQL_URL SHADOW_DB_URL DATABASE_URL DIRECT_DATABASE_URL);

# ------------------------------------------------------------------------- output

# Colour only for a terminal, and honour the NO_COLOR convention, so piped or CI
# output stays plain. Everything goes to STDERR: this is guard chatter, not data.
my $colour = -t STDERR && !exists $ENV{NO_COLOR};

sub paint {
    my ($code, $text) = @_;
    return $colour ? "\e[${code}m$text\e[0m" : $text;
}

sub red    { paint('1;31', $_[0]) }    # bold red
sub yellow { paint('1;33', $_[0]) }
sub cyan   { paint('36',   $_[0]) }
sub dim    { paint('2',    $_[0]) }
sub bold   { paint('1',    $_[0]) }

sub say_err { print STDERR @_, "\n" }

# The banner exists so this never reads as prisma's own output: when a command is
# refused, it should be obvious within one line that the local shell did it.
sub banner {
    my ($icon, $headline) = @_;
    say_err "$icon  $headline " . dim('· prisma-target-guard, your shell (not prisma)');
}

my $command = shift @ARGV // exit 0;

exit 0 if ($ENV{PRISMA_GUARD_ALLOW_REMOTE} // '') eq '1';

# Any `npx prisma` at all, destructive or not: prisma belongs to the workspace here.
if ($command eq 'npx' && (my ($at) = grep { $ARGV[$_] eq 'prisma' } 0 .. $#ARGV)) {
    my @prisma_args = @ARGV[$at + 1 .. $#ARGV];    # `npx --yes prisma db push` too

    banner('🛑', red('BLOCKED') . ' ' . bold('npx prisma'));
    say_err '    ' . dim('npx bypasses the .env target check and can fetch a prisma');
    say_err '    ' . dim('release that differs from the one the workspace pins.');
    say_err '    Use the workspace copy:  ' . cyan(join ' ', 'yarn prisma', @prisma_args);
    say_err '    ' . dim('Override: ') . cyan(join ' ', 'PRISMA_GUARD_ALLOW_REMOTE=1 npx', @ARGV);
    exit 1;
}

# ---------------------------------------------------------------- command matching

chomp(my $git_root = qx{git rev-parse --show-toplevel 2>/dev/null});
$git_root = '' if $?;

# The same destructive set as %DESTRUCTIVE, matched inside a shell command string.
my $DESTRUCTIVE_RE =
    qr/prisma \s+ (?: migrate \s+ (?: dev | reset | deploy | resolve )
                    | db      \s+ (?: push | execute | seed | pull ) )/x;

# `yarn dev:full` runs ./scripts/dev.sh, which calls `yarn prisma migrate reset --force`
# in a shell yarn spawns for it. Shell functions are not inherited by child processes,
# so the wrapper cannot see that inner call - by the time it happens we are out of the
# loop. Resolve the script body instead (and one level into any shell script it runs)
# so the *outer* command is refused before the script gets to start.
#
# This only ever reads package.json; nothing in the repo is modified.
sub script_shells_out_to_prisma {
    my ($name) = @_;
    return undef unless defined $name && length $name;

    my $root = length $git_root ? $git_root : '.';
    open my $fh, '<', "$root/package.json" or return undef;
    my $json = do { local $/; <$fh> };
    close $fh;

    my $scripts = eval { JSON::PP->new->decode($json)->{scripts} } or return undef;
    my $body = $scripts->{$name};
    return undef unless defined $body;

    if (my @hit = destructive_calls_in($body)) {
        return "$name -> @{[join ', ', @hit]}";
    }

    # One level deeper: the script may just invoke a shell script that does the damage.
    for my $file ($body =~ m{((?:\./)?[\w./-]+\.sh)}g) {
        my $path = $file =~ m{^/} ? $file : "$root/$file";
        $path =~ s{/\./}{/}g;
        open my $sh, '<', $path or next;
        my $source = do { local $/; <$sh> };
        close $sh;

        my @hit = destructive_calls_in($source) or next;
        my $more = @hit > 2 ? ' +' . (@hit - 2) . ' more' : '';
        return "$name -> $file -> " . join(', ', @hit[0 .. ($#hit < 1 ? $#hit : 1)]) . $more;
    }
    return undef;
}

# Matches only commands the script would actually run. Comments are dropped, and so is
# anything from `echo`/`printf` to end of line: check-prisma-migrations.sh prints advice
# text containing `yarn prisma migrate dev`, which is a message, not an invocation.
# Reported worst-first, so `reset` surfaces ahead of a `resolve` that appears earlier.
sub destructive_calls_in {
    my ($text) = @_;

    $text =~ s/^\s*#.*$//mg;
    $text =~ s/\b(?:echo|printf)\b.*$//mg;

    my %seen;
    my @found = grep { !$seen{$_}++ } ($text =~ /($DESTRUCTIVE_RE)/g);
    s/\s+/ /g for @found;

    my %rank = (reset => 0, dev => 1, push => 2, execute => 3, seed => 4, deploy => 5);
    return sort {
        my ($x) = $a =~ /(\w+)$/;
        my ($y) = $b =~ /(\w+)$/;
        ($rank{$x} // 9) <=> ($rank{$y} // 9);
    } @found;
}

# The script name is the first non-flag token, past `run` and `workspace <name>`.
sub script_name_from {
    my @tokens = grep { !/^-/ } @_;
    shift @tokens if @tokens && $tokens[0] eq 'run';
    splice @tokens, 0, 2 if @tokens && $tokens[0] eq 'workspace';
    return $tokens[0];
}

# Returns a human-readable description of the guarded operation, or undef.
sub guarded_operation {
    my @tokens = grep { !/^-/ } @_;

    for my $i (0 .. $#tokens) {

        # `yarn prisma migrate dev`, `yarn workspace @mft-api/prisma prisma db push`
        if ($tokens[$i] eq 'prisma' && $i + 2 <= $#tokens) {
            my ($group, $verb) = @tokens[$i + 1, $i + 2];
            return "prisma $group $verb" if is_destructive($group, $verb);
        }

        # package.json script names: `yarn migrate:dev`, `yarn db:seed`
        if ($tokens[$i] =~ /^(migrate|db)[:_-](\w+)$/) {
            return $tokens[$i] if is_destructive($1, $2);
        }
    }

    # Any other script whose body reaches prisma: `yarn dev:full` -> scripts/dev.sh.
    return script_shells_out_to_prisma(script_name_from(@_));
}

sub is_destructive {
    my ($group, $verb) = @_;
    return 0 unless $DESTRUCTIVE{$group};
    return scalar grep { $_ eq $verb } @{$DESTRUCTIVE{$group}};
}

my $operation = guarded_operation(@ARGV) or exit 0;

# ------------------------------------------------------------------- url resolution

# mft-api's prisma.config.ts reads `process.env.ENV_PATH ?? '../../.env'` from
# lib/prisma, i.e. the repo root, so ENV_PATH takes the same precedence here.
sub env_file_path {
    my @candidates;
    if (my $override = $ENV{ENV_PATH}) {
        push @candidates, $override;
        push @candidates, "$git_root/$override" if length $git_root;
    }
    push @candidates, "$git_root/.env" if length $git_root;
    push @candidates, '.env';

    for my $path (@candidates) {
        return $path if -r $path;
    }
    return undef;
}

sub parse_env_file {
    my ($path) = @_;
    my %values;

    open my $fh, '<', $path or return %values;
    while (my $line = <$fh>) {
        chomp $line;
        $line =~ s/^\s*export\s+//;
        next if $line =~ /^\s*(?:#|$)/;

        my ($key, $raw) = $line =~ /^\s*([A-Za-z_]\w*)\s*=\s*(.*)$/ or next;
        if ($raw =~ /^'([^']*)'/ || $raw =~ /^"((?:[^"\\]|\\.)*)"/) {
            $raw = $1;
        }
        else {
            $raw =~ s/\s+#.*$//;    # dotenv strips trailing comments when unquoted
            $raw =~ s/\s+$//;
        }
        $values{$key} = $raw;
    }
    close $fh;
    return %values;
}

my $env_file  = env_file_path();
my %from_file = defined $env_file ? parse_env_file($env_file) : ();

# ---------------------------------------------------------------- host classification

sub host_of {
    my ($url) = @_;
    return undef unless $url =~ m{^[A-Za-z][\w+.-]*://};

    my ($authority) = $url =~ m{^[A-Za-z][\w+.-]*://([^/?#]*)};
    $authority = '' unless defined $authority;
    $authority =~ s/^.*\@//;              # greedy: passwords may contain a literal @
    return '' unless length $authority;   # mysql://user@/db means a unix socket

    return $1 if $authority =~ /^\[([^\]]+)\]/;    # [::1]:3306
    $authority =~ s/:\d+$//;
    return $authority;
}

sub is_local {
    my ($host) = @_;
    return 1 unless length $host;     # unix socket is local by definition

    my @allowed = @LOCAL_HOSTS;
    push @allowed, grep { length } split /[\s,]+/, $ENV{PRISMA_GUARD_LOCAL_HOSTS}
        if defined $ENV{PRISMA_GUARD_LOCAL_HOSTS};

    my $lc = lc $host;
    return 1 if grep { lc($_) eq $lc } @allowed;
    return 1 if $lc =~ /^127\.\d+\.\d+\.\d+$/;
    return 1 if $lc =~ /\.localhost$/;
    return 0;
}

# Credentials never reach the terminal or the scrollback.
sub describe {
    my ($url) = @_;
    my ($scheme)    = $url =~ m{^([A-Za-z][\w+.-]*)://};
    my ($authority) = $url =~ m{^[A-Za-z][\w+.-]*://([^/?#]*)};
    my ($path)      = $url =~ m{^[A-Za-z][\w+.-]*://[^/?#]*(/[^?#]*)};

    $authority = '' unless defined $authority;
    $authority =~ s/^.*\@//;
    $authority = '<socket>' unless length $authority;

    return sprintf '%s://%s%s', $scheme // '?', $authority, $path // '';
}

# ------------------------------------------------------------------------ verdict

my (@remote, @checked);
for my $key (@URL_KEYS) {
    my ($url, $source);
    if (defined $ENV{$key} && length $ENV{$key}) {
        ($url, $source) = ($ENV{$key}, 'environment');
    }
    elsif (defined $from_file{$key} && length $from_file{$key}) {
        ($url, $source) = ($from_file{$key}, $env_file);
    }
    next unless defined $url;

    my $host = host_of($url);
    next unless defined $host;    # not a URL we understand

    push @checked, $key;
    push @remote, {key => $key, url => $url, host => $host, source => $source}
        unless is_local($host);
}

if (!@checked) {
    banner('⚠️', yellow('UNVERIFIED') . ' ' . bold("$command $operation"));
    say_err '    None of ' . join(', ', @URL_KEYS) . ' are set in the environment'
        . (defined $env_file ? ' or' : ',');
    say_err '    ' . (defined $env_file ? $env_file : 'and no .env file was found') . '.';
    say_err '    ' . dim('Cannot tell which database this hits - letting it through.');
    exit 0;
}

if (@remote) {
    banner('🛑', red('BLOCKED') . ' ' . bold("$command $operation"));
    say_err '    ' . red('Target database is not local.');
    for my $hit (@remote) {
        say_err '    ' . bold($hit->{key}) . ' = ' . yellow(describe($hit->{url}));
        say_err '      ' . dim("↳ from $hit->{source}");
    }
    say_err '    Point .env at a local database, or re-run with:';
    say_err '      ' . cyan(join ' ', 'PRISMA_GUARD_ALLOW_REMOTE=1', $command, @ARGV);
    exit 1;
}

if (($ENV{PRISMA_GUARD_VERBOSE} // '') eq '1') {
    banner('✅', bold("$command $operation") . ' → local');
    for my $key (@checked) {
        say_err '    ' . bold($key) . ' = ' . cyan(describe($ENV{$key} // $from_file{$key}));
    }
}

exit 0;

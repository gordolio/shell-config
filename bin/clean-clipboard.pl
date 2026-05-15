#!/usr/bin/env perl

# Dedent the clipboard and rejoin soft-wrapped lines, preserving structure.
#
# Pass 1: find the smallest leading whitespace count across non-blank lines
# and strip that prefix from every line. Preserves relative indent so code
# structure survives.
#
# Pass 2: for each run of consecutive non-blank lines, decide whether to
# treat it as a wrapped paragraph (join with spaces) or as structural
# content (keep newlines). The signal: if every line in the run is
# flush-left after dedent, it is paragraph prose - join it. If any line
# has residual leading whitespace, the run is structural (code, nested
# list, indented block) - keep its newlines and indentation.
#
# Blank lines are kept as paragraph separators.

use strict;
use warnings;

my $text = `pbpaste`;
my @lines = split /\n/, $text, -1;

# --- Pass 1: dedent ---
my $min;
for my $line (@lines) {
    next if $line =~ /^\s*$/;
    my ($indent) = $line =~ /^([ \t]*)/;
    my $len = length $indent;
    $min = $len if !defined $min || $len < $min;
}
$min //= 0;

if ($min > 0) {
    for my $line (@lines) {
        $line = substr($line, $min) if length($line) >= $min;
    }
}

# --- Pass 2: rejoin runs of flush-left lines ---
my @out;
my @buffer;
my $can_join = 1;

my $flush = sub {
    return unless @buffer;
    if ($can_join) {
        push @out, join(' ', @buffer);
    } else {
        push @out, @buffer;
    }
    @buffer = ();
    $can_join = 1;
};

for my $line (@lines) {
    if ($line =~ /^\s*$/) {
        $flush->();
        push @out, '';
    } else {
        $can_join = 0 if $line =~ /^\s/;
        $line =~ s/\s+$//;
        push @buffer, $line;
    }
}
$flush->();

my $result = join "\n", @out;
$result =~ s/^\n+//;

open(my $pbcopy, '|-', 'pbcopy') or die "pbcopy: $!";
print $pbcopy $result;
close $pbcopy;

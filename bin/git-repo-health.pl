#!/usr/bin/env perl
# Estimates whether a git repo would benefit from gc/repack, and by how much.
# Usage:
#   git-repo-health.pl <repo-path>            summary line (tab-delimited, for scripting)
#   git-repo-health.pl --detail <repo-path>    human-readable report (for fzf preview)

use strict;
use warnings;

# Below these, gc is unlikely to be worth the wall-clock time.
my $LOOSE_MAYBE  = 500;
my $LOOSE_GC     = 2000;
my $PACKS_MAYBE  = 5;
my $PACKS_GC     = 20;
my $GARBAGE_MAYBE_KB = 1;      # any garbage/prune-packable at all is worth a look
my $GARBAGE_GC_KB    = 1024;   # 1 MiB+ of reclaimable garbage is worth doing

# Rough compression git tends to gain by delta-packing loose objects that
# aren't already redundant-with-pack. Not measurable without an actual
# repack, so this is a labeled estimate, not a fact.
my $LOOSE_REPACK_SAVINGS_RATIO = 0.30;

my @args = @ARGV;
my $detail = 0;
if (@args && $args[0] eq '--detail') {
    $detail = 1;
    shift @args;
}
my $repo = $args[0] // '';
die "usage: $0 [--detail] <repo-path>\n" unless length $repo;
die "not a directory: $repo\n" unless -d $repo;
die "not a git repo (no .git): $repo\n" unless -e "$repo/.git";

my $counts = parse_count_objects($repo);
exit 1 unless $counts;

my $total_kb = du_kb("$repo/.git");

my $prune_packable_kb = 0;
if (($counts->{count} // 0) > 0 && ($counts->{size} // 0) > 0) {
    my $avg_loose_kb = $counts->{size} / $counts->{count};
    $prune_packable_kb = $avg_loose_kb * ($counts->{'prune-packable'} // 0);
}

my $size_garbage_kb = $counts->{'size-garbage'} // 0;

my $remaining_loose_kb = ($counts->{size} // 0) - $prune_packable_kb;
$remaining_loose_kb = 0 if $remaining_loose_kb < 0;
my $repack_savings_kb = $remaining_loose_kb * $LOOSE_REPACK_SAVINGS_RATIO;

my $reclaim_kb = int($size_garbage_kb + $prune_packable_kb + $repack_savings_kb);

my $has_gc_log = -e "$repo/.git/gc.log";

my ($severity, $status) = classify($counts, $size_garbage_kb, $prune_packable_kb, $has_gc_log);

if ($detail) {
    print_detail($repo, $counts, $total_kb, $size_garbage_kb, $prune_packable_kb,
                 $repack_savings_kb, $reclaim_kb, $severity, $status, $has_gc_log);
} else {
    print join("\t",
        $severity, $status,
        $counts->{count} // 0, $counts->{packs} // 0,
        $reclaim_kb, $total_kb, $repo,
    ), "\n";
}

exit 0;

sub parse_count_objects {
    my ($path) = @_;
    open my $fh, '-|', 'git', '-C', $path, 'count-objects', '-v' or return;
    my %counts;
    while (my $line = <$fh>) {
        chomp $line;
        next unless $line =~ /^([\w-]+):\s*(\d+)\s*$/;
        $counts{$1} = $2;
    }
    close $fh;
    return unless %counts;
    return \%counts;
}

sub du_kb {
    my ($path) = @_;
    my $out = `du -sk \Q$path\E 2>/dev/null`;
    return 0 unless $out =~ /^(\d+)/;
    return $1;
}

sub classify {
    my ($counts, $size_garbage_kb, $prune_packable_kb, $has_gc_log) = @_;

    my $loose = $counts->{count} // 0;
    my $packs = $counts->{packs} // 0;

    my $severity = 0;

    if ($loose >= $LOOSE_GC || $packs >= $PACKS_GC
        || $size_garbage_kb >= $GARBAGE_GC_KB || $prune_packable_kb >= $GARBAGE_GC_KB) {
        $severity = 2;
    } elsif ($loose >= $LOOSE_MAYBE || $packs >= $PACKS_MAYBE
        || $size_garbage_kb >= $GARBAGE_MAYBE_KB || $prune_packable_kb >= $GARBAGE_MAYBE_KB
        || $has_gc_log) {
        $severity = 1;
    }

    my @status_words = ('ok', 'maybe', 'gc');
    return ($severity, $status_words[$severity]);
}

sub human_kb {
    my ($kb) = @_;
    return sprintf('%dK', $kb) if $kb < 1024;
    return sprintf('%.1fM', $kb / 1024) if $kb < 1024 * 1024;
    return sprintf('%.1fG', $kb / 1024 / 1024);
}

sub print_detail {
    my ($repo, $counts, $total_kb, $size_garbage_kb, $prune_packable_kb,
        $repack_savings_kb, $reclaim_kb, $severity, $status, $has_gc_log) = @_;

    print "$repo\n";
    print "\n";
    print "raw counts (git count-objects -v)\n";
    for my $key (qw(count size in-pack packs size-pack prune-packable garbage size-garbage)) {
        printf "  %-16s %s\n", $key, $counts->{$key} // 0;
    }
    print "\n";
    printf ".git size on disk: %s\n", human_kb($total_kb);
    print "\n";

    print "reclaim estimate\n";
    printf "  garbage (unreferenced, git gc would delete): %s\n", human_kb($size_garbage_kb);
    printf "  redundant loose objects (already in a pack): %s\n", human_kb($prune_packable_kb);
    printf "  est. delta-compression on remaining loose objects (~%d%%, not measured): %s\n",
        $LOOSE_REPACK_SAVINGS_RATIO * 100, human_kb($repack_savings_kb);
    printf "  ~total estimated reclaim: %s\n", human_kb($reclaim_kb);
    print "\n";

    my %verdicts = (
        0 => "looks fine — gc is unlikely to be worth running",
        1 => "could help a little — cheap to run, modest gain expected",
        2 => "worth running — meaningfully high loose-object/pack count or reclaimable garbage",
    );
    print "verdict: $status — $verdicts{$severity}\n";

    if ($has_gc_log) {
        print "\nnote: .git/gc.log exists — a previous 'git gc' failed or was interrupted.\n";
        print "git will refuse to auto-gc until this is resolved. Run 'git gc' manually to see the error,\n";
        print "then remove .git/gc.log once fixed.\n";
    }

    my $recommend = $severity == 2 ? 'git gc'
                  : $severity == 1 ? 'git gc (or leave it, low urgency)'
                  : 'no action needed';
    print "\nsuggested command: $recommend\n";

    print "\ncaveat: 'git gc' prunes unreachable objects (default grace period: 2 weeks).\n";
    print "If you have dangling commits/stashes you still care about that are older than\n";
    print "that, back up refs (e.g. 'git branch backup <sha>') before gc'ing.\n";
}

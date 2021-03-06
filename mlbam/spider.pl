#!/usr/bin/env perl
#
# This script has been modified from the one included with the Baseball Hacks
# book in the following ways:
#
# * it takes command line options for year, league, and various settings
# * it doesn't try to download files for future games
# * it does *not* download players.txt or batter/pitcher files
# * it *does* download: game.xml, gameday_Syn.xml, linescore.xml
# * it will not die on a transfer error, so be sure to save output
#   to a log file and read carefully to get any missed files
#

use Getopt::Std;
getopts('wthy:l:', \%opts);

use Time::Local;

sub extractDate {
  # extracts and formats date from a time stamp
  ($t) = @_;
  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)
    = localtime($t);
  $mon  += 1;
  $year += 1900;
  $mon = (length($mon) == 1) ? "0$mon" : $mon;
  $mday = (length($mday) == 1) ? "0$mday" : $mday;
  return ($mon, $mday, $year);
}

sub currentYear {
  my ($d, $m, $y) = extractDate(time);
  return $y;
}

sub verifyDir {
  # verifies that a directory exists,
  # creates the directory if the directory doesn't
  my ($d) = @_;
  if (-e $d) {
    die "$d not a directory\n" unless (-d $outputdir);
  } else {
    die "could not create $d: $!\n" unless (mkdir $d);
  }
}

# help
if ($opts{'h'}) {
  print "Usage: spider [-y <year>] [-l <league>] [-w] [-t] [-h] [output_dir]\n";
  exit;
}

# year
$y = $opts{'y'};
$y = currentYear() if ($y eq "");

# league (mlb, aaa, etc)
$lg = $opts{'l'};
$lg = "mlb" if ($lg eq "");

# start on Mar 20
$start = timelocal(0,0,0,20,2,$y-1900);
($mon, $mday, $year) = extractDate($start);
print "starting at $mon/$mday/$year\n";

# end on Nov 30
$end = timelocal(0,0,0,30,10,$y-1900);
if (time < $end) {
  # don't go beyond yesterday (include today if -t specified)
  $end = time - ($opts{'t'} ? 0 : 60*60*24);
}
($mon, $mday, $year) = extractDate($end);
print "ending at $mon/$mday/$year\n";


# start fetching
use LWP;
my $browser = LWP::UserAgent->new;
$baseurl = "http://gdx.mlb.com/components/game/" . $lg;
$outputdir = (-e $ARGV[-1]) ? $ARGV[-1] : "./games";

verifyDir($outputdir);

sub fetchFile {
  my ($filename, $urlpath, $filepath) = @_;
  if($gamehtml =~ m/<a href=\"$filename\"/ ) {
    my $url = "$urlpath/$filename";
    my $response = $browser->get($url);
    print "Couldn't get $url: ", $response->status_line, "\n"
      unless $response->is_success;
    my $content = $response->content;
    open FILE, ">$filepath/$filename"
      or die "could not open file $gamedir/$filename: $|\n";
    print FILE $content;
    close FILE;
  } else {
    print "warning: no $filename for $game\n";
  }
}

for ($t = $start; $t < $end; $t += 60*60*24) {
  ($mon, $mday, $year) = extractDate($t);
  print "processing $mon/$mday/$year\n";

  verifyDir("$outputdir");
  verifyDir("$outputdir/month_$mon");
  verifyDir("$outputdir/month_$mon/day_$mday");

  $dayurl = "$baseurl/year_$year/month_$mon/day_$mday/";
  print "\t$dayurl\n";

  $response = $browser->get($dayurl);
  print "Couldn't get $dayurl: ", $response->status_line, "\n"
    unless $response->is_success;
  $html = $response->content;
  my @games = ();
  while($html =~ m/<a href=\"(gid_\w+\/)\"/g ) {
    push @games, $1;
  }

  foreach $game (@games) {
    $gamedir = "$outputdir/month_$mon/day_$mday/$game";
    if (-e $gamedir && !$opts{'w'}) {
      # already fetched info on this game
      print "\t\tskipping game: $game\n";
    } else {
      print "\t\tfetching game: $game\n";
      verifyDir($gamedir);
      $gameurl = "$dayurl/$game";
      $response = $browser->get($gameurl);
      print "Couldn't get $gameurl: ", $response->status_line, "\n"
        unless $response->is_success;
      $gamehtml = $response->content;

      fetchFile("boxscore.xml"    , $gameurl , $gamedir);
      fetchFile("players.xml"     , $gameurl , $gamedir);
      fetchFile("game.xml"        , $gameurl , $gamedir);
      fetchFile("gameday_Syn.xml" , $gameurl , $gamedir);
      fetchFile("linescore.xml"   , $gameurl , $gamedir);


      #if($gamehtml =~ m/<a href=\"inning\/\"/ ) {
      #  $inningdir = "$gamedir/inning";
      #  verifyDir($inningdir);
      #  $inningurl = "$dayurl/$game/inning/";
      #  $response = $browser->get($inningurl);
      #  print "Couldn't get $gameurl: ", $response->status_line, "\n"
      #    unless $response->is_success;
      #  $inninghtml = $response->content;

      #  my @files = ();
      #  while($inninghtml =~ m/<a href=\"(inning_.*)\"/g ) {
      #    push @files, $1;
      #  }

      #  foreach $file (@files) {
      #    print "\t\t\tinning file: $file\n";
      #    $fileurl = "$inningurl/$file";
      #    $response = $browser->get($fileurl);
      #    print "Couldn't get $fileurl: ", $response->status_line, "\n"
      #      unless $response->is_success;
      #    $filehtml = $response->content;
      #    open FILE, ">$inningdir/$file"
      #      or die "could not open file $inningdir/$file: $|\n";
      #    print FILE $filehtml;
      #    close FILE;
      #  }
      #}


      #if($gamehtml =~ m/<a href=\"players\.txt\"/ ) {
      #  $plyrurl = "$dayurl/$game/players.txt";
      #  $response = $browser->get($plyrurl);
      #  print "Couldn't get $plyrurl: ", $response->status_line, "\n"
      #    unless $response->is_success;
      #  $plyrhtml = $response->content;
      #  open PLYRS, ">$gamedir/players.txt"
      #    or die "could not open file $gamedir/players.txt: $|\n";
      #  print PLYRS $plyrhtml;
      #  close PLYRS;
      #} else {
      #  print "warning: no player list for $game\n";
      #}


      #if($gamehtml =~ m/<a href=\"batters\/\"/ ) {
      #  $battersdir = "$gamedir/batters";
      #  verifyDir($battersdir);
      #  $battersurl = "$dayurl/$game/batters/";
      #  $response = $browser->get($battersurl);
      #  print "Couldn't get $battersurl: ", $response->status_line, "\n"
      #    unless $response->is_success;
      #  $battershtml = $response->content;

      #  my @files = ();
      #  while($battershtml =~ m/<a href=\"(\d+\.xml)\"/g ) {
      #    push @files, $1;
      #  }

      #  foreach $file (@files) {
      #    print "\t\t\tbatter file: $file\n";
      #    $fileurl = "$battersurl/$file";
      #    $response = $browser->get($fileurl);
      #    print "Couldn't get $fileurl: ", $response->status_line, "\n"
      #      unless $response->is_success;
      #    $filehtml = $response->content;
      #    open FILE, ">$battersdir/$file"
      #      or die "could not open file $battersdir/$file: $|\n";
      #    print FILE $filehtml;
      #    close FILE;
      #  }
      #}


      #if($gamehtml =~ m/<a href=\"pitchers\/\"/ ) {
      #  $pitchersdir = "$gamedir/pitchers";
      #  verifyDir($pitchersdir);
      #  $pitchersurl = "$dayurl/$game/pitchers/";
      #  $response = $browser->get($pitchersurl);
      #  print "Couldn't get $pitchersurl: ", $response->status_line, "\n"
      #    unless $response->is_success;
      #  $pitchershtml = $response->content;

      #  my @files = ();
      #  while($pitchershtml =~ m/<a href=\"(\d+\.xml)\"/g ) {
      #    push @files, $1;
      #  }

      #  foreach $file (@files) {
      #    print "\t\t\tpitcher file: $file\n";
      #    $fileurl = "$pitchersurl/$file";
      #    $response = $browser->get($fileurl);
      #    print "Couldn't get $fileurl: ", $response->status_line, "\n"
      #      unless $response->is_success;
      #    $filehtml = $response->content;
      #    open FILE, ">$pitchersdir/$file"
      #      or die "could not open file $pitchersdir/$file: $|\n";
      #    print FILE $filehtml;
      #    close FILE;
      #  }
      #}


      #if($gamehtml =~ m/<a href=\"pbp\/\"/ ) {
      #  $pbpdir = "$gamedir/pbp";
      #  verifyDir($pbpdir);

      #  $bpbpdir = "$gamedir/pbp/batters";
      #  verifyDir($bpbpdir);
      #  $bpbpurl = "$dayurl/$game/pbp/batters";
      #  $response = $browser->get($bpbpurl);
      #  print "Couldn't get $bpbpurl: ", $response->status_line, "\n"
      #    unless $response->is_success;
      #  $bpbphtml = $response->content;

      #  my @files = ();
      #  while($bpbphtml =~ m/<a href=\"(\d+\.xml)\"/g ) {
      #    push @files, $1;
      #  }

      #  foreach $file (@files) {
      #    print "\t\t\tpbp batter file: $file\n";
      #    $fileurl = "$bpbpurl/$file";
      #    $response = $browser->get($fileurl);
      #    print "Couldn't get $fileurl: ", $response->status_line, "\n"
      #      unless $response->is_success;
      #    $filehtml = $response->content;
      #    open FILE, ">$bpbpdir/$file"
      #      or die "could not open file $bpbpdir/$file: $!\n";
      #    print FILE $filehtml;
      #    close FILE;
      #  }

      #  $ppbpdir = "$gamedir/pbp/pitchers";
      #  verifyDir($ppbpdir);
      #  $ppbpurl = "$dayurl/$game/pbp/pitchers";
      #  $response = $browser->get($ppbpurl);
      #  print "Couldn't get $ppbpurl: ", $response->status_line, "\n"
      #    unless $response->is_success;
      #  $ppbphtml = $response->content;

      #  my @files = ();
      #  while($ppbphtml =~ m/<a href=\"(\d+\.xml)\"/g ) {
      #    push @files, $1;
      #  }

      #  foreach $file (@files) {
      #    print "\t\t\tpbp pitcher file: $file\n";
      #    $fileurl = "$ppbpurl/$file";
      #    $response = $browser->get($fileurl);
      #    print "Couldn't get $fileurl: ", $response->status_line, "\n"
      #      unless $response->is_success;
      #    $filehtml = $response->content;
      #    open FILE, ">$ppbpdir/$file"
      #      or die "could not open file $ppbpdir/$file: $|\n";
      #    print FILE $filehtml;
      #    close FILE;
      #  }
      #}
      sleep(1); # be at least somewhat polite; one game per second
    }
  }
}

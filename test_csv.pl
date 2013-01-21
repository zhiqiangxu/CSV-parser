use strict;
use warnings;
use Data::Dumper;

require q{csv.pl};

sub file_get_contents {
    my ($file_name) = @_;
    open my $fd, "<", $file_name;
    local $/;
    my $content = <$fd>;
    close $fd;
    return $content;
}

print Dumper parse(file_get_contents(q{KPI-2012.csv}));

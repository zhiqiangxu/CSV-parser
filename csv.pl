use strict;
use warnings;
use Carp::Assert;

my ($token, $text, $length, $offset, %symbols);

$symbols{q{,}}          = { id => q{,} };
$symbols{q{(nl)}}       = { id => q{(nl)} };
$symbols{q{(string)}}   = { id => q{(string)} };
$symbols{q{(end)}}      = { id => q{(end)} };

sub parse {
    ($text) = @_;
    $offset = 0;
    $length = length($text);
    advance();
    my $s = statements();
    advance('(end)');
    return $s;
}

sub advance {
    my ($expect) = @_;
    if (defined $expect) {
        assert($token->{id} eq $expect);
    }
    my ($current_char, $nl, $string_value);
    while (1) {
        if ($offset >= $length) {
            goto END_OK;
        } else {
            $current_char = substr($text, $offset, 1);
            if ($current_char eq q{ } or $current_char eq qq{\t}) {
                $offset ++;
            } elsif ($current_char eq q{,}) {
                $token = $symbols{q{,}};
                $offset ++;
                return;
            } elsif ($nl = get_nl($current_char)) {
                $token = $symbols{q{(nl)}};
                $offset += $nl;
                return;
            } else {
                my ($escaping, $string_quote);

                $escaping = 1;
                if ($current_char eq q{'} or $current_char eq q{"}) {
                    $string_quote = $current_char;
                    $string_value = '';
                    $offset ++;
                    if ($offset >= $length) {
                        goto END_OK;
                    }
                    $escaping = 0 if $current_char eq q{'};
                    $current_char = substr($text, $offset, 1);
                } else {
                    $string_value = '';
                }

                do {
                    if ($current_char eq qq{\\}) {
                        if ($escaping) {
                            $offset ++;
                            $string_value .= get_escaped_char();
                        } else {
                            $string_value .= $current_char;
                        }
                    } else {
                        if (defined $string_quote) {
                            if ($current_char eq $string_quote) {
                                $offset ++;
                                goto STRING_OK;
                            } else {
                                $offset ++;
                                $string_value .= $current_char;
                            }
                        } else {
                            if ($current_char eq qq{,}) {
                                goto STRING_OK;
                            } elsif ($nl = get_nl($current_char)) {
                                goto STRING_OK;
                            } else {
                                $offset ++;
                                $string_value .= $current_char;
                            }
                        }
                    }

                    if ($offset >= $length) {
                        goto END_OK;
                    } else {
                        $current_char = substr($text, $offset, 1);
                    }
                } while (1);
            }
        }
    }
STRING_OK:
    $token = $symbols{q{(string)}};
    $token->{value} = $string_value;
    return;
END_OK:
    if (defined $string_value) {
        goto STRING_OK;
    }
    $token = $symbols{q{(end)}};
    return;
}

sub get_escaped_char {
    my $current_char = substr($text, $offset, 1);
    if ($current_char eq qq{\\}) {
        $offset ++;
        return qq{\\};
    } elsif ($current_char eq q{,}) {
        $offset ++;
        return q{,};
    } elsif (my $nl = get_nl()) {
        $offset += $nl;
        return q{};
    } else {
        $offset ++;
        return $current_char;
    }
}

sub get_nl {
    my ($current_char) = @_;
    $current_char = substr($text, $offset, 1) unless defined $current_char;
    if ($current_char eq qq{\n}) {
        return 1;
    } elsif ($current_char eq qq{\r}) {
        if (substr($text, $offset + 1, 1) eq qq{\n}) {
            return 2;
        }
        return 1;
    }
}

sub statements {
    my ($s, @a);
    while (1) {
        if ($token->{id} eq '(end)') {
            last;
        }
        $s = statement();
        push @a, $s;
    }
    return \@a;
}

sub statement {
    my @result = (q{});
    while (1) {
        if ($token->{id} eq q{(nl)} or $token->{id} eq q{(end)}) {
            advance();
            return \@result;
        } elsif ($token->{id} eq q{(string)}) {
            $result[-1] .= $token->{value};
            advance();
        } elsif ($token->{id} eq q{,}) {
            push @result, q{};
            advance();
        }
    }
}

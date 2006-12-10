#!perl

##############################################################################
#      $URL$
#     $Date$
#   $Author$
# $Revision$
##############################################################################

use strict;
use warnings;
use English qw(-no_match_vars);
use List::MoreUtils qw(all any none);
use Perl::Critic::Theme;
use Perl::Critic::PolicyFactory;
use Perl::Critic::UserProfile;
use Perl::Critic::Config;
use Test::More (tests => 53);

#-----------------------------------------------------------------------------

ILLEGAL_CHARACTERS:{

    my @invalid_expressions = (
        '$cosmetic',
        '"cosmetic"',
        '#cosmetic > bugs',
        'cosmetic / bugs',
        'cosmetic % bugs',
        'cosmetic + [bugs - pbp]',
        'cosmetic + {bugs - pbp}',
        'cosmetic && bugs || pbp',
        'cosmetic @ bugs ^ pbp',
    );

    for my $invalid ( @invalid_expressions ) {
        eval { Perl::Critic::Theme::_validate_expression( $invalid ) };
        like( $EVAL_ERROR, qr/Illegal character/, qq{Invalid expression: "$invalid"} );
    }
}

#-----------------------------------------------------------------------------

MISSING_OPERATORS:{

    my @invalid_expressions = (
         'cosmetic bugs',
         '(cosmetic bugs) - bugs',
         '(bugs) (pbp)',
    );

    for my $invalid ( @invalid_expressions ) {
        eval { Perl::Critic::Theme::_validate_expression( $invalid ) };
        like( $EVAL_ERROR, qr/Missing operator/, qq{Missing operator: "$invalid"} );
    }
}

#-----------------------------------------------------------------------------

VALID_EXPRESSIONS:{

    my @valid_expressions = (
        'cosmetic',
        'cosmetic + bugs',
        'cosmetic - bugs',
        'cosmetic + (bugs - pbp)',
        'cosmetic+(bugs-pbp)',
    );

    for my $valid ( @valid_expressions ) {
        my $got = Perl::Critic::Theme::_validate_expression( $valid );
        is( $got, 1, qq{Valid expression: "$valid"} );
    }
}

#-----------------------------------------------------------------------------

TRANSLATIONS:
{
    my %expressions = (
        'cosmetic' => 'cosmetic',
        'cosmetic + bugs',           =>  'cosmetic + bugs',
        'cosmetic - bugs',           =>  'cosmetic - bugs',
        'cosmetic + (bugs - pbp)'    =>  'cosmetic + (bugs - pbp)',
        'cosmetic+(bugs-pbp)'        =>  'cosmetic+(bugs-pbp)',
        'cosmetic or bugs'           =>  'cosmetic + bugs',
        'cosmetic and bugs'          =>  'cosmetic * bugs',
        'cosmetic and (bugs or pbp)' =>  'cosmetic * (bugs + pbp)',
    );

    while ( my ($raw, $expected) = each %expressions ) {
        my $cooked = Perl::Critic::Theme::_translate_expression( $raw );
        is( $cooked, $expected, 'Theme translation');
    }
}

#-----------------------------------------------------------------------------

{
    my %expressions = (
         'cosmetic'                =>  '$tmap{"cosmetic"}',
         'cosmetic + bugs',        =>  '$tmap{"cosmetic"} + $tmap{"bugs"}',
         'cosmetic * bugs',        =>  '$tmap{"cosmetic"} * $tmap{"bugs"}',
         'cosmetic - bugs',        =>  '$tmap{"cosmetic"} - $tmap{"bugs"}',
         'cosmetic + (bugs - pbp)' =>  '$tmap{"cosmetic"} + ($tmap{"bugs"} - $tmap{"pbp"})',
         'cosmetic*(bugs-pbp)'     =>  '$tmap{"cosmetic"}*($tmap{"bugs"}-$tmap{"pbp"})',
    );

    while ( my ($raw, $expected) = each %expressions ) {
        my $cooked = Perl::Critic::Theme::_interpolate_expression($raw,'tmap');
        is( $cooked, $expected, 'Theme interpolation');
    }
}

#-----------------------------------------------------------------------------

{
    my $prof = Perl::Critic::UserProfile->new( -profile => q{} );
    my @pols = Perl::Critic::PolicyFactory->new( -profile => $prof )->policies();
    my %pmap = map { ref $_ => $_ } @pols; #Hashify class_name -> object


    my $theme = 'cosmetic';
    my %args = (-theme => $theme, -policies => \@pols);
    my @members = Perl::Critic::Theme->new( %args )->members();
    ok( all { in_theme($pmap{$_}, 'cosmetic') }  @members );

    #--------------

    $theme = 'cosmetic - pbp';
    %args  = (-theme => $theme, -policies => \@pols);
    @members = Perl::Critic::Theme->new( %args )->members();
    ok( all  { in_theme($pmap{$_}, 'cosmetic') } @members );
    ok( none { in_theme($pmap{$_}, 'pbp')      } @members );

    $theme = 'cosmetic not pbp';
    %args  = (-theme => $theme, -policies => \@pols);
    @members = Perl::Critic::Theme->new( %args )->members();
    ok( all  { in_theme($pmap{$_}, 'cosmetic') } @members );
    ok( none { in_theme($pmap{$_}, 'pbp')      } @members );

    #--------------

    $theme = 'cosmetic + pbp';
    %args  = (-theme => $theme, -policies => \@pols);
    @members = Perl::Critic::Theme->new( %args )->members();
    ok( all  { in_theme($pmap{$_}, 'cosmetic') ||
               in_theme($pmap{$_}, 'pbp') } @members );

    $theme = 'cosmetic or pbp';
    %args  = (-theme => $theme, -policies => \@pols);
    @members = Perl::Critic::Theme->new( %args )->members();
    ok( all  { in_theme($pmap{$_}, 'cosmetic') ||
               in_theme($pmap{$_}, 'pbp') } @members );

    #--------------

    $theme = 'bugs * pbp';
    %args  = (-theme => $theme, -policies => \@pols);
    @members = Perl::Critic::Theme->new( %args )->members();
    ok( all  { in_theme($pmap{$_}, 'bugs') } @members );
    ok( all  { in_theme($pmap{$_}, 'pbp')   } @members );

    $theme = 'bugs and pbp';
    %args  = (-theme => $theme, -policies => \@pols);
    @members = Perl::Critic::Theme->new( %args )->members();
    ok( all  { in_theme($pmap{$_}, 'bugs') } @members );
    ok( all  { in_theme($pmap{$_}, 'pbp')   } @members );

    #--------------

    $theme = '-pbp';
    %args  = (-theme => $theme, -policies => \@pols);
    @members = Perl::Critic::Theme->new( %args )->members();
    ok( none  { in_theme($pmap{$_}, 'pbp') } @members );

    $theme = 'not pbp';
    %args  = (-theme => $theme, -policies => \@pols);
    @members = Perl::Critic::Theme->new( %args )->members();
    ok( none  { in_theme($pmap{$_}, 'pbp') } @members );

    #--------------

    $theme = 'pbp - (danger * security)';
    %args  = (-theme => $theme, -policies => \@pols);
    @members = Perl::Critic::Theme->new( %args )->members();
    ok( all  { in_theme($pmap{$_}, 'pbp') } @members );
    ok( none { in_theme($pmap{$_}, 'danger') &&
               in_theme($pmap{$_}, 'security') } @members );

    $theme = 'pbp not (danger and security)';
    %args  = (-theme => $theme, -policies => \@pols);
    @members = Perl::Critic::Theme->new( %args )->members();
    ok( all  { in_theme($pmap{$_}, 'pbp') } @members );
    ok( none { in_theme($pmap{$_}, 'danger') &&
               in_theme($pmap{$_}, 'security') } @members );

    #--------------

    $theme = 'bogus';
    %args  = (-theme => $theme, -policies => \@pols);
    @members = Perl::Critic::Theme->new( %args )->members();
    is( scalar @members, 0, 'bogus theme' );

    $theme = 'bogus - pbp';
    %args  = (-theme => $theme, -policies => \@pols);
    @members = Perl::Critic::Theme->new( %args )->members();
    is( scalar @members, 0, 'bogus theme' );

    $theme = q{};
    %args  = (-theme => $theme, -policies => \@pols);
    @members = Perl::Critic::Theme->new( %args )->members();
    is( scalar @members, scalar @pols, 'empty theme' );

    $theme = undef;
    %args  = (-theme => $theme, -policies => \@pols);
    @members = Perl::Critic::Theme->new( %args )->members();
    is( scalar @members, scalar @pols, 'undef theme' );

    #--------------
    # Exceptions

    $theme = 'cosmetic *(';
    %args  = (-theme => $theme, -policies => \@pols);
    eval{ Perl::Critic::Theme->new( %args )->members() };
    like( $EVAL_ERROR, qr/Invalid theme/, 'invalid theme expression' );

}

sub in_theme {
    my ($policy, $theme) = @_;
    return any{ $_ eq $theme } $policy->get_themes();
}

# Local Variables:
#   mode: cperl
#   cperl-indent-level: 4
#   fill-column: 78
#   indent-tabs-mode: nil
#   c-indentation-style: bsd
# End:
# ex: set ts=8 sts=4 sw=4 tw=78 ft=perl expandtab :

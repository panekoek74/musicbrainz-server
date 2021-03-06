package t::MusicBrainz::Server::Edit::Artist::Merge;
use Test::Routine;
use Test::More;
use Test::Fatal;

with 't::Edit';
with 't::Context';

BEGIN { use MusicBrainz::Server::Edit::Artist::Merge }

use MusicBrainz::Server::Context;
use MusicBrainz::Server::Constants qw( $EDIT_ARTIST_MERGE );
use MusicBrainz::Server::Constants qw( :edit_status );
use MusicBrainz::Server::Test qw( accept_edit reject_edit );

test 'Non-existant merge target' => sub {
    my $test = shift;
    my $c = $test->c;

    MusicBrainz::Server::Test->prepare_test_database($c, '+edit_artist_merge');

    my $edit = create_edit($c);
    $c->model('Artist')->delete(4);

    accept_edit($c, $edit);

    is($edit->status, $STATUS_FAILEDDEP);
    ok(defined $c->model('Artist')->get_by_id(3));
};

test 'Merge Person with gender into Group' => sub {
    my $test = shift;
    my $c = $test->c;

    MusicBrainz::Server::Test->prepare_test_database($c, '+edit_artist_merge');
    $c->sql->do(<<'EOSQL');
UPDATE artist SET type = 2 WHERE id = 4;
UPDATE artist SET type = 1, gender = 2 WHERE id = 3;
EOSQL

    # merge 3 -> 4
    my $edit = create_edit($c);

    ok(!exception { accept_edit($c, $edit) },
       'Edit merging person with gender to group does not cause exception');
};

# The name of this test may be confusing, since the code should do the opposite
# of what is understood to happen in the UI. By "renaming" the credits, the code
# should do nothing and leave them empty, so that they take on the new artist
# name. By "not renaming" the credits, the code should rename them to have the
# old artist name, making them appear to be the same as before the merge.

test 'Merge, renaming relationship credits' => sub {
    my $test = shift;
    my $c = $test->c;

    MusicBrainz::Server::Test->prepare_test_database($c, '+edit_artist_merge');

    my $edit = create_edit($c, 1);
    accept_edit($c, $edit);

    my $relationship = $c->model('Relationship')->get_by_id('artist', 'recording', 1);
    is($relationship->entity0_credit, '', 'entity0_credit is empty, so it shows the new artist name');
};

test 'Merge, without renaming relationship credits' => sub {
    my $test = shift;
    my $c = $test->c;

    MusicBrainz::Server::Test->prepare_test_database($c, '+edit_artist_merge');

    my $edit = create_edit($c, 0);
    accept_edit($c, $edit);

    my $relationship = $c->model('Relationship')->get_by_id('artist', 'recording', 1);
    is($relationship->entity0_credit, 'Old Artist', 'entity0_credit has the old artist name');
};

test all => sub {
    my $test = shift;
    my $c = $test->c;

    MusicBrainz::Server::Test->prepare_test_database($c, '+edit_artist_merge');

    my $edit = create_edit($c);
    isa_ok($edit, 'MusicBrainz::Server::Edit::Artist::Merge');

    my ($edits, $hits) = $c->model('Edit')->find({ artist => [3, 4] }, 10, 0);
    is($hits, 1);
    is($edits->[0]->id, $edit->id);

    my $a1 = $c->model('Artist')->get_by_id(3);
    my $a2 = $c->model('Artist')->get_by_id(4);
    is($a1->edits_pending, 1);
    is($a2->edits_pending, 1);

    reject_edit($c, $edit);

    $a1 = $c->model('Artist')->get_by_id(3);
    $a2 = $c->model('Artist')->get_by_id(4);
    is($a1->edits_pending, 0);
    is($a2->edits_pending, 0);

    $edit = create_edit($c);
    accept_edit($c, $edit);

    $a1 = $c->model('Artist')->get_by_id(3);
    $a2 = $c->model('Artist')->get_by_id(4);
    ok(!defined $a1);
    ok(defined $a2);

    is($a2->edits_pending, 0);

    my $ipi_codes = $c->model('Artist')->ipi->find_by_entity_id($a2->id);
    is(scalar @$ipi_codes, 3, "Merged Artist has all ipi codes after accepting edit");

    my $isni_codes = $c->model('Artist')->isni->find_by_entity_id($a2->id);
    is(scalar @$isni_codes, 4, "Merged Artist has all isni codes after accepting edit");
};

sub create_edit {
    my ($c, $rename) = @_;
    return $c->model('Edit')->create(
        edit_type => $EDIT_ARTIST_MERGE,
        editor_id => 1,
        old_entities => [ { id => 3, name => 'Old Artist' } ],
        new_entity => { id => 4, name => 'New Artist' },
        rename => $rename // 0
    );
}

1;

package MusicBrainz::Server::Entity::Relationship;

use Moose;
use Readonly;
use MusicBrainz::Server::Entity::Types;
use MusicBrainz::Server::Validation qw( trim_in_place );
use MusicBrainz::Server::Translation qw( l comma_list comma_only_list );
use MusicBrainz::Server::Data::Relationship;

use overload '<=>' => \&_cmp, fallback => 1;

Readonly our $DIRECTION_FORWARD  => 1;
Readonly our $DIRECTION_BACKWARD => 2;

extends 'MusicBrainz::Server::Entity';
with  'MusicBrainz::Server::Entity::Role::Editable';
with  'MusicBrainz::Server::Entity::Role::LastUpdate';

has 'link_id' => (
    is => 'rw',
    isa => 'Int',
);

has 'link' => (
    is => 'rw',
    isa => 'Link',
);

has 'direction' => (
    is => 'rw',
    isa => 'Int',
    default => $DIRECTION_FORWARD
);

has 'entity0_id' => (
    is => 'rw',
    isa => 'Int',
);

has 'entity0' => (
    is => 'rw',
    isa => 'Linkable',
);

has 'entity0_credit' => (
    is => 'ro',
    isa => 'Str',
);

has 'entity1_id' => (
    is => 'rw',
    isa => 'Int',
);

has 'entity1' => (
    is => 'rw',
    isa => 'Linkable',
);

has 'entity1_credit' => (
    is => 'ro',
    isa => 'Str',
);

has 'link_order' => (
    is => 'rw',
    isa => 'Int',
);

has '_phrase' => (
    is => 'ro',
    builder => '_build_phrase',
    lazy => 1
);

has '_verbose_phrase' => (
    is => 'ro',
    builder => '_build_verbose_phrase',
    lazy => 1
);

sub entity_is_orderable {
    my ($self, $entity) = @_;

    my $orderable_direction = $self->link->type->orderable_direction;

    return 1 if (
        ($orderable_direction == 1 && $entity == $self->entity1) ||
        ($orderable_direction == 2 && $entity == $self->entity0)
    );

    return 0;
}

sub _source_target_prop {
    my ($self, %opts) = @_;
    my $is_target = $opts{is_target};
    my $prop_base = $opts{prop_base} // $self;
    my $prop_suffix = $opts{prop_suffix};
    my $prop;
    if (not $is_target) {
        $prop = ($self->direction == $DIRECTION_FORWARD) ? 'entity0' : 'entity1';
    } else {
        $prop = ($self->direction == $DIRECTION_FORWARD) ? 'entity1' : 'entity0';
    }
    $prop = $prop . '_' . $prop_suffix if $prop_suffix;
    return $prop_base->$prop;
}

sub source {
    return shift->_source_target_prop();
}

sub source_type {
    my ($self) = @_;
    return $self->_source_target_prop(prop_suffix => 'type', prop_base => $self->link->type);
}

sub source_cardinality {
    my ($self) = @_;
    return $self->_source_target_prop(prop_suffix => 'cardinality', prop_base => $self->link->type);
}

sub source_credit {
    my ($self) = @_;
    return $self->_source_target_prop(prop_suffix => 'credit');
}

sub source_key {
    my ($self) = @_;
    return ($self->source_type eq 'url')
        ? $self->source->url
        : $self->source->gid;
}

sub target {
    my ($self) = @_;
    return $self->_source_target_prop(is_target => 1);
}

sub target_type {
    my ($self) = @_;
    return $self->_source_target_prop(is_target => 1, prop_suffix => 'type', prop_base => $self->link->type);
}

sub target_cardinality {
    my ($self) = @_;
    return $self->_source_target_prop(is_target => 1, prop_suffix => 'cardinality', prop_base => $self->link->type);
}

sub target_credit {
    my ($self) = @_;
    return $self->_source_target_prop(is_target => 1, prop_suffix => 'credit');
}

sub target_key
{
    my ($self) = @_;
    return ($self->target_type eq 'url')
        ? $self->target->url
        : $self->target->gid;
}

sub phrase
{
    my ($self) = @_;
    return $self->_phrase->[0];
}

sub extra_phrase_attributes
{
    my ($self) = @_;
    return $self->_phrase->[1];
}

sub verbose_phrase
{
    my ($self) = @_;
    return $self->_verbose_phrase->[0];
}

sub extra_verbose_phrase_attributes
{
    my ($self) = @_;
    return $self->_verbose_phrase->[1];
}

sub _build_phrase {
    my ($self) = @_;
    $self->_interpolate(
        $self->direction == $DIRECTION_FORWARD
            ? $self->link->type->l_link_phrase()
            : $self->link->type->l_reverse_link_phrase()
    );
}

sub _build_verbose_phrase {
    my ($self) = @_;
    $self->_interpolate($self->link->type->l_long_link_phrase);
}

sub _interpolate {
    my ($self, $phrase) = @_;

    my @attrs = $self->link->all_attributes;
    my %attrs;
    foreach my $attr (@attrs) {
        my $name = lc $attr->type->root->name;

        if (exists $attrs{$name}) {
            push @{$attrs{$name}}, $attr->html;
        } else {
            $attrs{$name} = [ $attr->html ];
        }
    }
    my %extra_attrs = %attrs;
    my $type_is_orderable = $self->link->type->orderable_direction > 0;

    # Ordered relationships in a series should all share the same link phrase,
    # even if their attributes differ, so that they remain grouped together
    # in the relationships display.
    %attrs = () if $type_is_orderable;

    my $replace_attrs = sub {
        my ($name, $alt) = @_;
        delete $extra_attrs{$name} unless $type_is_orderable;
        if (!$alt) {
            return '' unless exists $attrs{$name};
            return comma_list(@{ $attrs{$name} });
        } else {
            my ($alt1, $alt2) = split /\|/, $alt;
            return $alt2 || '' unless exists $attrs{$name};
            my $attr = comma_list(@{ $attrs{$name} });
            $alt1 =~ s/%/$attr/eg;
            return $alt1;
        }
    };
    $phrase =~ s/{(.*?)(?::(.*?))?}/$replace_attrs->(lc $1, $2)/eg;
    trim_in_place($phrase);

    my @extra_attrs = map { @$_ } values %extra_attrs;
    return [ $phrase, comma_only_list(@extra_attrs) ];
}

sub _cmp {
    my ($a, $b) = @_;
    my $a_sortname = $a->target->can('sort_name')
        ? $a->target->sort_name
        : $a->target->name;
    my $b_sortname = $b->target->can('sort_name')
        ? $b->target->sort_name
        : $b->target->name;
    $a->link_order              <=> $b->link_order ||
    $a->link->begin_date        <=> $b->link->begin_date ||
    $a->link->end_date          <=> $b->link->end_date   ||
    $a->link->type->child_order <=> $b->link->type->child_order ||
    $a_sortname cmp $b_sortname;
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;

=head1 COPYRIGHT

Copyright (C) 2009 Lukas Lalinsky

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.

=cut

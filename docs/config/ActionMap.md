# ActionMap

Defines or overrides an Interchange *action* -- a named handler that runs
when its name appears as the first component of a request path. Reach for
it to add custom URL endpoints (downloads, redirects, API-style calls) or
to change what a built-in action such as `process` or `order` does.

**Scope:** both (`interchange.cfg` global, `catalog.cfg` catalog)

An action is a piece of Perl (or interpolatable Interchange Tag Language,
ITL) mapped to a name. When a request path begins with that name -- for
example `/cgi-bin/ic/standard/deliver/42` invokes the `deliver` action --
Interchange runs the mapped code before serving a page. If the code
returns a false value, page processing stops and the action is expected to
have produced the whole response itself.

## Syntax

    ActionMap  name  CODE

`name` is the action name (hyphens are converted to underscores).
`CODE` is one of:

- an anonymous Perl subroutine, `sub { ... }` (commonly written as a
  here-document);
- the name of a defined `Sub`/`GlobalSub` (catalog or global);
- a block of ITL/HTML, which is wrapped and interpolated at call time.

The directive accumulates: each line adds or replaces one named action.
Default: empty.

## Description

The mapped subroutine is called with the request path as its argument and
runs in the usual page context (`$CGI`, `$Session`, `$Scratch`, `$Tag`,
etc. are available). Its return value controls dispatch: a true value lets
normal page lookup continue; a false value ends the request.

### Global

A global `ActionMap` in `interchange.cfg` is available to every catalog.
Global action code is subject to the `Safe` compartment unless the calling
catalog is listed in `AllowGlobal`.

### Catalog

A catalog `ActionMap` in `catalog.cfg` applies to that catalog only.

Behavior is otherwise identical in both scopes. Beginning with Interchange
5.5, global and catalog action maps behave the same with respect to the
path: neither strips the action name from the path handed to the routine.
(Earlier versions stripped the action name for global maps.)

## Examples

Turn the built-in `order` action into a no-op (put in `catalog.cfg`):

```
ActionMap order sub { 1 }
```

Deliver a downloadable file, from the strap demo `catalog.cfg`:

```
ActionMap  deliver   <<EOR
sub {
	$Scratch->{deliverable} = $CGI->{mv_arg};
	$CGI->{mv_nextpage} = 'deliver';
	if(! $Session->{username} and $CGI->{mv_username}) {
		$Tag->userdb('login');
	}
	return 1;
}
EOR
```

Split a request into an action, a page name, and arguments:

```
ActionMap test <<EOA
sub {
	my $url = shift;

	# Remove the action name from the URL
	$url =~ s:^test/+::i;

	# Arguments are optional
	if ($url =~ s:/+(.*)$::) {
		$CGI->{mv_arg} = $1;
	}

	$CGI->{mv_nextpage} = $url;
	return 1;
}
EOA
```

A request for `test/foo/bar` now serves page `foo` with `mv_arg` set to
`bar`.

## Notes

`FormAction`, `FileControl`, and (catalog-only) `ItemAction` are sibling
directives parsed the same way; they map names in other dispatch
namespaces. The standard `process` action has a number of settings
controlled through `FormAction`.

`CodeDef` with a type of `ActionMap` is an equivalent lower-level way to
register an action.

## See also

[FormAction](FormAction.md), [FileControl](FileControl.md), [ItemAction](ItemAction.md), [CodeDef](CodeDef.md), [AddDirective](AddDirective.md),
[UserTag](UserTag.md), [AllowGlobal](AllowGlobal.md), the [forms](../guides/forms.md) guide.

## Source

Parsed by `parse_action` in `lib/Vend/Config.pm`; actions are dispatched
in `lib/Vend/Dispatch.pm`.

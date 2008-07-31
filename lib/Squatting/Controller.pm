package Squatting::Controller;

use strict;
no  strict 'refs';
use warnings;
no  warnings 'redefine';

use CGI::Cookie;

our $AUTOLOAD;

# constructor
sub new {
  bless { name => $_[1], urls => $_[2], @_[3..$#_] } => $_[0];
}

# (shallow) copy constructor
sub clone {
  bless { %{$_[0]}, @_[1..$#_] } => ref($_[0]);
}

# name    - name of controller
# urls    - arrayref of URL patterns that this controller responds to
# cr      - Continuity::Request object
# env     - incoming request headers and misc info like %ENV in the CGI days
# input   - incoming CGI variables
# cookies - incoming *AND* outgoing cookies
# state   - your session data
# v       - outgoing vars
# status  - outgoing HTTP Response status
# headers - outgoing HTTP headers
# view    - name of default view
# log     - logging object
# app     - name of our app
for my $m qw(name urls cr env input cookies state v status headers log view app) {
  *{$m} = sub : lvalue { $_[0]->{$m} }
}

# HTTP methods
for my $m qw(get post head put delete options trace connect) {
  *{$m} = sub { $_[0]->{$m}->(@_) }
}

# $content = $self->render($template, $vars)
sub render {
  my ($self, $template, $vn) = @_;
  my $view;
  $vn ||= $self->view;
  my $app = $self->app;
  if (defined($vn)) {
    $view = ${$app."::Views::V"}{$vn}; #  hash
  } else {                             #    vs
    $view = ${$app."::Views::V"}[0];   # array -- Perl provides a lot of 'namespaces' so why not use them?
  }
  $view->headers = $self->headers;
  $view->$template($self->v);
}

# $self->redirect($url, $status_code)
sub redirect {
  my ($self, $l, $s) = @_;
  $self->headers->{Location} = $l || '/';
  $self->status = $s || 302;
}

# default 404 controller
my $not_found = sub { $_[0]->status = 404; $_[0]->env->{REQUEST_PATH}." not found." };
our $r404 = Squatting::Controller->new(
  R404 => [],
  get  => $not_found,
  post => $not_found,
  app  => 'Squatting'
);

1;

=head1 NAME

Squatting::Controller - default controller class for Squatting

=head1 SYNOPSIS

  package App::Controllers;
  use Squatting ':controllers';
  our @C = (
    C(
      Thread => [ '/forum/(\d+)/thread/(\d+)-(\w+)' ],
      get => sub {
        my ($self, $forum_id, $thread_id, $slug) = @_;
        #
        # get thread from database...
        #
        $self->render('thread');
      },
      post => sub {
        my ($self, $forum_id, $thread_id, $slug) = @_;
        # 
        # add post to thread
        #
        $self->redirect(R('Thread', $forum_id, $thread_id, $slug));
      }
    )
  );

=head1 DESCRIPTION

Squatting::Controller is the default controller class for Squatting
applications.  Its job is to take HTTP requests and construct an appropriate
response by setting up output headers and returning content.

=head1 API

=head2 Object Construction

=head3 Squatting::Controller->new($name => \@urls, %methods)

The constructor takes a name, an arrayref or URL patterns, and a hash of
method definitions.  There is a helper function called C() that makes this
slightly less verbose.

=head3 $c->clone([ %opts ])

This will create a shallow copy of the controller.  You may optionally pass in
a hash of options that will be merged into the new clone.

=head2 HTTP Request Handlers

=head3 $c->get(@args)

=head3 $c->post(@args)

=head3 $c->put(@args)

=head3 $c->delete(@args)

=head3 $c->head(@args)

=head3 $c->options(@args)

=head3 $c->trace(@args)

=head3 $c->connect(@args)

These methods are called when their respective HTTP requests are sent to the
controller.  @args is the list of regex captures from the URL pattern in
$c->urls that matched $c->env->{REQUEST_PATH}.

=head2 Attribute Accessors

The following methods are lvalue subroutines that contain information
relevant to the current controller and current request/response cycle.

=head3 $c->name

This returns the name of the controller.

=head3 $c->urls

This returns the arrayref of URL patterns that the controller responds to.

=head3 $c->cr

This returns the L<Continuity::Request> object for the current session.

=head3 $c->env

This returns a hashref populated with a CGI-like environment.  This is where
you'll find the incoming HTTP headers.

=head3 $c->input

This returns a hashref containing the incoming CGI parameters.

=head3 $c->cookies

This returns a hashref that holds both the incoming and outgoing cookies.

Incoming cookies are just simple scalar values, whereas outgoing cookies are
hashrefs that can be passed to L<CGI::Cookie> to construct a cookie string.

=head3 $c->state

If you've setup sessions, this method will return the current session 
data as a hashref.

=head3 $c->v

This returns a hashref that represents the outgoing variables for this
request.  This hashref will be passed to a view's templates when render()
is called.

=head3 $c->status

This returns an integer representing the outgoing HTTP status code.
See L<HTTP::Status> for more details.

=head3 $c->headers

This returns a hashref representing the outgoing HTTP headers.

=head3 $c->log

This returns a logging object if one has been set up for your app.  If it
exists, you should be able to call methods like C<debug()>, C<info()>,
C<warn()>, C<error()>, and C<fatal()> against it, and the output of this would
typically end up in an error log.

=head3 $c->view

This returns the name of the default view for the current request.  If
it's undefined, the first view in @App::Views::V will be considered the
default.

=head3 $c->app

This returns the name of the app that this controller belongs to.

=head2 Output

=head3 $c->render($template, [ $view ])

This method will return a string generated by the specified template and view.  If
a view is not specified, the first view object in @App::Views::V will be used.

=head3 $c->redirect($path, [ $status ])

This method is a shortcut for setting $c->status to 302 and $c->headers->{Location}
to the specified URL.  You may optionally pass in a different status code as the
second parameter.

=head1 SEE ALSO

L<Squatting>,
L<Squatting::View>

=cut

# Local Variables: ***
# mode: cperl ***
# indent-tabs-mode: nil ***
# cperl-close-paren-offset: -2 ***
# cperl-continued-statement-offset: 2 ***
# cperl-indent-level: 2 ***
# cperl-indent-parens-as-block: t ***
# cperl-tab-always-indent: nil ***
# End: ***
# vim:tabstop=8 softtabstop=2 shiftwidth=2 shiftround expandtab

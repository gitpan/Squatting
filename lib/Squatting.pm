package Squatting;

use strict;
no  strict 'refs';
#use warnings;
#no  warnings 'redefine';
use base 'Class::C3::Componentised';

use List::Util qw(first);
use URI::Escape;
use Carp;
use Data::Dump 'pp';

our $VERSION = '0.83';

require Squatting::Controller;
require Squatting::View;

# XXX - deprecated | use App ':controllers'
# XXX - deprecated | use App ':views'
# use App @PLUGINS
# 
# No longer have to :  use base 'Squatting';
# Simply saying     :  use Squatting;
#   will muck with the calling packages @ISA.
sub import {
  my $m = shift;
  my $p = (caller)[0];

  if ($m ne 'Squatting') {
    return $m->load_components(grep /::/, @_);
  }

  push @{$p.'::ISA'}, 'Squatting';

  # $url = R('Controller', @args, { cgi => vars })  # Generate URLs with the routing function
  *{$p."::Controllers::R"} = *{$p."::Views::R"} = *{$p."::R"} = sub {
    my ($controller, @args) = @_;
    my $input;
    if (@args && ref($args[-1]) eq 'HASH') {
      $input = pop(@args);
    }
    my $c = ${$p."::Controllers::C"}{$controller};
    croak "$controller controller not found in '\%$p\::Controllers::C" unless $c;
    my $arity = @args;
    my $path = first { my @m = /\(.*?\)/g; $arity == @m } @{$c->urls};
    croak "couldn't find a matching URL path" unless $path;
    while ($path =~ /\(.*?\)/) {
      $path =~ s{\(.*?\)}{uri_escape(+shift(@args), "^A-Za-z0-9\-_.!~*’()/")}e;
    }
    if ($input) {
      $path .= "?".  join('&' => 
        map { 
          my $k = $_;
          ref($input->{$_}) eq 'ARRAY'
            ? map { "$k=".uri_escape($_) } @{$input->{$_}}
            : "$_=".uri_escape($input->{$_})
        } keys %$input);
    }
    $path;
  };

  # ($controller, \@regex_captures) = D($path)  # Return controller and captures for a path
  *{$p."::D"} = sub {
    my $url = uri_unescape($_[0]);
    my $C = \@{$p.'::Controllers::C'};
    my ($c, @regex_captures);
    for $c (@$C) {
      for (@{$c->urls}) {
        if (@regex_captures = ($url =~ qr{^$_$})) {
          pop @regex_captures if ($#+ == 0);
          return ($c, \@regex_captures);
        }
      }
    }
    ($Squatting::Controller::r404, []);
  };

  *{$p."::Controllers::C"} = sub {
    Squatting::Controller->new(@_, app => $p)
  };
  *{$p."::Views::V"} = sub {
    Squatting::View->new(@_)
  };

}

# Squatting plugins may be anywhere in Squatting::*::* but by convention
# (and for fun) you should use poetic diction in your package names.
#
# Squatting::On::Continuity
# Squatting::On::Catalyst
# Squatting::On::CGI
# Squatting::On::Jifty 
#
# (ALL YOUR FRAMEWORK ARE BELONG TO US)
#
# Squatting::With::Impunity (What could we do w/ this name?)
# Squatting::With::Log4Perl (which is how we could add logging support)
#
# (etc)
sub component_base_class { __PACKAGE__ }

# 1
# App->mount($AnotherApp, $prefix)  # Map another app on to a URL $prefix.
sub mount {
  my ($app, $other, $prefix) = @_;
  push @{$app."::O"}, $other;
  push @{$app."::Controllers::C"}, map {
    my $urls = $_->urls;
    $_->urls = [ map { $prefix.$_ } @$urls ];
    $_;
  } @{$other."::Controllers::C"}
}

# 2
# App->relocate($prefix)  # Map main app to a URL $prefix
sub relocate {
  my ($app, $prefix) = @_;
  for (@{$app."::Controllers::C"}) {
    my $urls = $_->urls;
    $_->urls = [ map { $prefix.$_ } @$urls ];
  }
  ${$app."::CONFIG"}{relocated} = $prefix;
}

# 3
# App->init  # Initialize $app
sub init {
  $_->init for (@{$_[0]."::O"});
  %{$_[0]."::Controllers::C"} = map { $_->name => $_ } @{$_[0]."::Controllers::C"};
  %{$_[0]."::Views::V"}       = map { $_->name => $_ } @{$_[0]."::Views::V"};
}

# App->service($controller, @args)  # Handle an HTTP request
sub service {
  my ($app, $c, @args) = grep { defined } @_;
  my $method = lc $c->env->{REQUEST_METHOD};
  my $content;

  eval { $content = $c->$method(@args) };
  die $@ if (ref($@) =~ /^HTTP::Exception/); # Pass HTTP::Exceptions on up
  warn "EXCEPTION: $@" if ($@);

  my $cookies = $c->cookies;
  $c->headers->{'Set-Cookie'} = join("; ",
    map { CGI::Cookie->new( -name => $_, %{$cookies->{$_}} ) }
      grep { ref $cookies->{$_} eq 'HASH' }
        keys %$cookies) if (%$cookies);

  $content;
}

1;

=head1 NAME

Squatting - A Camping-inspired Web Microframework for Perl

=head1 SYNOPSIS

Running an App:

  $ squatting App
  Please contact me at: http://localhost:4234/

Check out our ASCII art logo:

  $ squatting --logo

What a basic App looks like:

  # STEP 1 => Use Squatting for your App
  {
    package App;  # <-- I hope it's obvious that this name can whatever you want.
    use Squatting;
    our %CONFIG;  # <-- standard app config goes here
  }

  # STEP 2 => Define the App's Controllers
  {
    package App::Controllers;

    # Setup a list of controller objects in @C using the C() function.
    our @C = (
      C(
        Home => [ '/' ],
        get  => sub {
          my ($self) = @_;
          my $v = $self->v;
          $v->{title}   = 'A Simple Squatting Application';
          $v->{message} = 'Hello, World!';
          $self->render('home');
        },
        post => sub { }
      ),
    );
  }

  # STEP 3 => Define the App's Views
  {
    package App::Views;

    # Setup a list of view objects in @V using the V() function.
    our @V = (
      V(
        'html',
        layout  => sub {
          my ($self, $v, $content) = @_;
          "<html><head><title>$v->{title}</title></head>".
          "<body>$content</body></html>";
        },
        home    => sub {
          my ($self, $v) = @_;
          "<h1>$v->{message}</h1>"
        },
      ),
    );
  }

  # Models?  
  # - The whole world is your model.  ;-)
  # - I have no interest in defining policy here.
  # - Use whatever works for you.

=head1 DESCRIPTION

Squatting is a web microframework based on Camping.
It originally used L<Continuity> as its foundation,
but it has since been generalized such that it can
squat on top of any Perl-based web framework (in theory).

=head2 What does this mean?

=over 4

=item B<Concise API>

_why did a really good job designing Camping's API so that you could get the
B<MOST> done with the B<LEAST> amount of code possible.  I loved Camping's API
so much that I ported it to Perl.

=item B<Tiny Codebase>

The core of Squatting (which includes Squatting, Squatting::Controller, and
Squatting::View) can be squished into less than 4K of obfuscated perl.  Also,
the number of Perl module dependencies has been kept down to a minimum.

=item B<RESTful Controllers By Default>

Controllers are objects (not classes) that are made to look like HTTP
resources.  Thus, they respond to methods like get(), post(), put(), and
delete().

=item B<RESTless Controllers Are Possible>

Stateful continuation-based code can be surprisingly useful (especially for
COMET), so we try to make RESTless controllers easy to express as well. (B<*>)

=item B<Squatting Apps Can Have Multiple Views>

Views are also objects (not classes) whose methods represent templates to be
rendered.  An app can also have more than one view.  Changing a Squatting app's
look and feel can be as simple as swapping out one view object for another.

=item B<Squatting Apps Are Composable>

You can take multiple Squatting apps and compose them into a single app.  For
example, suppose you built a site and decided that you'd like to add a forum.
You could take a hypothetical forum app written in Squatting and just mount
it at an arbitrary path like /forum.

=item B<Squatting Apps Are Embeddable>

Already using another framework?  No problem.  You should be able to embed
Squatting apps into apps written in anything from CGI on up to Catalyst.
B<Squatting aims to be compatible with EVERYONE.>

=item B<Minimal Policy>

You may use any templating system you want, and you may use any ORM you
want.  We only have a few rules on how the controller code and the view code
should be organized, but beyond that, you are free as you want to be.

=back

B<*> RESTless controllers currently only work when you're L<Squatting::On::Continuity>.

=head1 API

=head2 Use as a Base Class for Squatting Applications

  package App;
  use Squatting;
  our %CONFIG = ();
  1;

Just C<use>ing Squatting makes a lot of magic happen.  In the example above:

=over 4

=item App becomes a subclass of Squatting.

=item App::Controllers is given this app's R() and C() functions.

=item App::Views is given this app's R() and V() functions.

=back

=head3 App->service($controller, @args)

Every time an HTTP request comes in, this method is called with a controller
object and a list of arguments.  The controller will then be invoked with the
HTTP method that was requested (like GET or POST), and it will return the
content of the response as a string.

B<NOTE>:  If you want to do anything before, after, or around an HTTP request,
this is the method you should override in your subclass.

=head3 App->init

This method takes no parameters and initializes some internal variables.

B<NOTE>:  You can override this method if you want to do more things when
the App is initialized.

=head3 App->mount($AnotherApp => $prefix)

XXX - The C<mount()> has been moved out of the core and into 
L<Squatting::With::Mount>.  Furthermore, Squatting::With::Mount has
been implemented using L<Squatting::On::Squatting>.

This method will mount another Squatting app at the specified prefix.

  App->mount('My::Blog'   => '/my/ridiculous/rantings');
  App->mount('Forum'      => '/forum');
  App->mount('ChatterBox' => '/chat');

B<NOTE>:  You can only mount an app once.  Don't try to mount it again
at some other prefix, because it won't work.  This is a consequence
of storing so much information in package variables and a strong argument
for going all objects all the time.

=head3 App->relocate($prefix)

This method will relocate a Squatting app to the specified prefix.  It's useful
for embedding a Squatting app into apps written in other frameworks.

This also has a side-effect of setting C<$CONFIG{relocated}> to C<$prefix>.

=head2 Use as a Helper for Controllers

In this package, you will define a list of L<Squatting::Controller> objects in C<@C>.

  package App::Controllers;
  use Squatting ':controllers';
  our @C = (
    C(...),
    C(...),
    C(...),
  );

=head3 C($name => \@urls, %methods)

This is a shortcut for:

  Squatting::Controller->new(
    $name => \@urls, 
    app   => $App, 
    %methods
  );

=head3 R($name, @args, [ \%params ])

R() is a URL generation function that takes a controller name and a list of
arguments.  You may also pass in a hashref representing CGI variables as the
very last parameter to this function.

B<Example>:  Given the following controllers, R() would respond like this.

  # Example Controllers
  C(Home    => [ '/' ]);
  C(Profile => [ '/~(\w+)', '/~(\w+)\.(\w+)' ]);

  # Generated URLs
  R('Home')                             # "/"
  R('Home', { foo => 1, bar => 2})      # "/?foo=1&bar=2"
  R('Profile', 'larry')                 # "/~larry"
  R('Profile', 'larry', 'json')         # "/~larry.json"
                                                             
As you can see, C<@args> represents the regexp captures, and C<\%params>
represents the CGI query parameters.

=head2 Use as a Helper for Views

In this package, you will define a list of L<Squatting::View> objects in C<@V>.

  package App::Views;
  use Squatting ':views';
  our @V = (
    V(
      'html',
      home => sub { "<h1>Home</h1>" },
    ),
  );

=head3 V($name, %methods)

This is a shortcut for:

  Squatting::View->new($name, %methods);

=head3 R($name, @args, [ \%params ])

This is the same R() function that the controllers get access to.
Please use it to generate URLs so that your apps may be composable
and embeddable.

=head1 SEE ALSO

=over 4

=item B<Other Squatting::* modules>:

L<Squatting::Controller>, L<Squatting::View>,
L<Squatting::Mapper>, L<Squatting::H>,
L<Squatting::On::Continuity>, L<Squatting::On::Catalyst>, L<Squatting::On::CGI>,
L<Squatting::On::MP13>, L<Squatting::On::MP20>,
L<Squatting::With::AccessTrace>, L<Squatting::With::Log>,
L<Squatting::With::Coro::Debug>

L<Squatting::On::PSGI>,
L<Squatting::On::Mojo>,
L<Squatting::On::HTTP::Engine>

=item B<Squatting's superclass>:

L<Class::C3::Componentised>

=item B<Squatting apps you can find on CPAN>:

L<Pod::Server> - a nice way to browse through the POD for your locally
installed perl modules.

L<Stardust> - a simple COMET server.  (DEPRECATED.  Use Web::Hippie or Plack::Middleware::SocketIO instead.)

L<Rhetoric> - a simple CPAN-friendly blogging system for Perl.

=back

=head2 Google Group:  squatting-framework

A Google Group has been setup so that people can discuss Squatting.
If you have questions about the framework, this is the place to ask.

L<http://groups.google.com/group/squatting-framework>

=head2 Squatting Source Code

The source code is short and it has some useful comments in it, so this might
be all you need to get going.  There are also some examples in the F<eg/>
directory.

L<http://github.com/beppu/squatting/tree/master>

=head2 Bavl Source Code

We're going to throw Squatting (and Continuity) into the metaphorical deep end
by using it to implement the L<http://towr.of.bavl.org/>.  It's a site that
will help people learn foreign languages by letting you hear the phrases you're
interested in learning as actually spoken by fluent speakers.  If you're
looking for an example of how to use Squatting for an ambitious project, look
at the Bavl code.

L<http://github.com/beppu/bavl/tree/master>

=head2 Continuity and Coro

When you want to start dabbling with RESTless controllers, it would serve you
well to understand how Continuity, Coro and Event work.  To learn more, I
recommend reading the POD for the following Perl modules:

L<Continuity>,
L<Coro>,
L<AnyEvent>.

Combining coroutines with an event loop is a surprisingly powerful technique.

=head2 Camping

Squatting is descended from Camping, so studying the Camping API
will indirectly teach you much of the Squatting API.

L<http://github.com/why/camping/tree/master>

=head2 Prototype-based OO

There were a lot of obscure Ruby idioms in Camping that were damn near
impossible to directly translate into Perl.  I got around this by resorting to
techniques that are reminiscent of prototype-based OO.  (That's why controllers
and views are objects instead of classes.)

=head3 Prototypes == Grand Unified Theory of Objects

I've been coding a lot of JavaScript these days, and it has definitely
influenced my programming style.  I've come to love the simplicity of
prototype-based OO, and I think it's a damned shame that they're introducing
concepts like 'class' in the next version of JavaScript.  It's like they missed
the point of prototype-based OO.

If you're going to add anything to JavaScript, make the prototype side of it
stronger.  Look to languages like Io, and make it easier to clone objects and
manipulate an object's prototype chain.  The beauty of prototypes is that you
can combine it with slot-based objects to unify the functionality of objects,
classes, and namespaces into a surprisingly simple and coherent system.  Look
at Io if you don't believe me.

L<http://iolanguage.com/>

=head1 AUTHOR

John BEPPU E<lt>beppu@cpan.orgE<gt>

Scott WALTERS (aka scrottie) gets credit for the name of this module.

=head1 COPYRIGHT

Copyright (c) 2008-9 John BEPPU E<lt>beppu@cpan.orgE<gt>.

=head2 The "MIT" License

Permission is hereby granted, free of charge, to any person
obtaining a copy of this software and associated documentation
files (the "Software"), to deal in the Software without
restriction, including without limitation the rights to use,
copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the
Software is furnished to do so, subject to the following
conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.

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

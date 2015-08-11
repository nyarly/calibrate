# Calibrate

A library to provide object-level configuration. Features are:

* __Nestable__ a configuration field can itself be configurable
* __Composible__ configurable objects can copy and proxy values
* __Defaults__ every field can have a default value
* __Validation__ configurable objects can be checked that their values have
  been set

Extra bonus: file tree configuration - little sets of related files can be
described, configured, validated and referred to.

## Usage

Install per the usual formula:

Gemfile:
```
gem 'calibrate'
```

Then:
```
bundle
```

The you can set up stuff like:

```ruby
class MyThingDoer
  include Calibrate::Configurable

  setting :name, "my-task-lib"
  settings :prefers => "tasky", :age => "less than a day"
  nil_setting :optional_thing
  required_fields :cant_compute_this


  def initialize
    setup_defaults
  end

  def update_from(other)
    other.copy_settings_to(self)
  end

  def do_eeeeet
    check_required
    #... actual doing
  end
end
```

The most basic class method here is `setting` - it just creates a special
attribute on the `Tasklib` class with a default value.

There's a variant of setting `settings` which take a hash and creates several
settings and their defaults all at once.

`nil_setting` is essentially sugar for `setting :name => nil`

`required_fields` create attributes on the tasklib that must be set - in
validation, required fields will raise a helpful error if they haven't been
set.

## Motivation

Why not Hashes? _because hashes don't restrict the keys you set - a key typo is
an annoying bug to reproduce_ Why not attributes? _because attributes don't
confirm that they've been set, and defaults have to be set one at a time_

Honestly, if Calibrate seems heavyweight for your application, it probably
is. Having good errors in complex configurations can be very helpful, but often
it can be more trouble than it's worth.

### Configuration Tools

`Calibrate` settings have a lot of extra power associated with
them.  First of all, the `resolve_configuration` from above would probably be
better like this:

```ruby
def resolve_configuration
  if field_unset?(:full_name)
    self.full_name = [first_name, last_name].join(" ")
  end
end
```

In this case, you could probably have said `self.full_name ||= join_names()`
but the nice thing about `field_unset?` is that I does exactly what it says: if
the user set full_name to `nil`, that's still a setting (but it's a "falsy"
value, which means ||= would clobber it.)

The other utility function here are `from_hash(source_hash)` and `to_hash` -
which do essentially what they sound like. Especially handy to do a YAML.load
(or see [`Valise`](https://github.com/nyarly/valise)) to pull in a hash
from a file and configure a task from that.

### Validation

```
setup_defaults

check_required
```

### Path Names

Because the most common settings for a Rake task tend to be paths to files -
the source and target files for a compiler, for instance - `Calibrate` has a
convenience functions for creating and managing those.

```ruby
class MyTasklib
  include Calibrate::Configurable
  dir(:project,
    dir(:source_dir, "src",
      path(:source_file, "file.txt")),
    dir(:destination_dir, "dest",
      path(:target_file, "file.txt")))

  def define
    check_required
    file target_file.abs_path => source_file.abs_path do
      sh "compilerify #{source_file.abs_path} > #{target_file.abs_path}"
    end
  end
end
```

```ruby
tasklib = MyTasklib.new(:buildit) do |build|
  build.project.rel_path = "proj_dir"
end
```

```
> rake buildit
   compilerify proj_dir/src/file.txt > proj_dir/dest/file.txt
```

(note: this is an example lifted from Mattock, so there's some Rake oddities there)

This is one of the nicest things Calibrate does. The management of paths is a big
hassle for writing build scripts, and handling that in a coherent, expressive
way is really helpful. Furthermore, Calibrate treats all of those rel_paths as
required fields.  This helps mitigate errors related to empty paths, e.g.
deleting all the files in the whole project.

### Composition

Related `Calibrate::Configurable` object tend to share configuration, however,
and it'd be a hassle for users to have to duplicate configuration, especially
when some of one tasklibs configuration comes from another's computed values.

The most common use case is something like "copy all the fields with the same
name from that object to this one." There's a method on `Calibrate::Configurable`
to support that, like so:

```ruby
class Parent
  include Calibrate::Configurable
  settings :first_name => "Jane", :last_name => "Smith"
end

class Child
  include Calibrate::Configurable

  def configure_from(parent)
    parent.copy_settings_to(self) #here's the copy
    self.parent_name = parent.first_name
  end
end
```

Used like:
```ruby
mom = Parent.new
mom.last_name = "Jones"

kid = Child.new
kid.configure_from(mom)
  #kid.last_name is already "Jones" here
kid.age = 6
```

## Advanced Topics

### Setting Metadata

One of the features of `Calibrate` settings are that they have some extra
metadata that helps control how they're used. In general you don't need to
fiddle with them, but more complicated setups can get some value from
this feature. One solid example is this:

```ruby
def self.default_namespace(name)
  setting(:namespace, name).isnt(:copiable)
end
```

The `isnt(:copiable)`
serves to prevent `parent.copy_settings_to(self)` overriding the namespace of
the current task with the namespace of the "parent" task.

The metadata you can set on a field are `:copiable`, `:proxiable`, `:required`,
`:defaulting` and `:runtime`. `:copiable`, `:proxiable` and `:defaulting`
default to true (i.e. `.is(:copiable)`), but most of those changes are handled
by how the fields were defined in the first place.

## History

Calibrate began as a component of Mattock, a tool for defining Rake
libraries. Features grew from the needs of complex build setups.  There may
still be some "mattock-isms" lingering in the code and documentation. To some
degree, those are bugs and PRs to make the documentation more general will
gratefully be accepted.

## License

MIT

## Contributing

Tests and PRs, yo.

---
title: Creating methods dynamically in a Ruby object
date: 2017-04-02
---

It feels like Rails' makes things hard when working with models that are not
AR-related, which sees to be the case lately as we are integrating more and more external services.

Sometimes you have a class, say `User`, that defines some methods like
`first_name`, `last_name` etc. and you use an object of that class in forms in your
Rails app.

Now imagine that in a specific form you also need to render a couple more inputs,
related to the user object BUT you don't want to define those methods in your `User` class.

What you can do is to create a simple Decorator or Presenter of that `User` class
for that specific form. But exactly because I am lazy sometimes I do the following:
I setup the methods in the object itself, not in the class. For that reason I have
created a little module that I extend on runtime in the object.

The module has some magic using anonymous modules in order to inject the method names you want your object
to have and also the values, using primitives like Hashes and Arrays.

```ruby
module Methy
  def self.of(*array)
    array = [array].flatten.compact
    m = Module.new
    array.each do |item|
      if item.is_a? Hash
        item.each do |key, value|
          m.send(:define_method, key){ value }
        end
      else
        m.send(:define_method, item){}
      end
    end

    return m
  end
end
```

The usage can be seen in the following example:

```ruby
class UserController < ApplicationController
  def create
    @user = ExternalAPI::User.new.send(
      :extend,
      Methy.of(*[:subscribe_newsletter, :nickname])
    )
  end
end
```

It's as simple as that. Now `ExternalAPI::User` object will also have the
`subscribe_newsletter` and `nickname` methods so that Rails' `form_for` can use
them instead of manually adding the html of that inputs.

`extend` method is private on the `Object` class and it feels a bit clumsy to use
`send` method just for that so in models that I intend to use that I add the following
module:

```ruby
module Extensible
  def extended_by(*args)
    self.send(:extend, *args)
  end
end

class ExternalAPI::User
  include Extensible

  # other code
end
```

Now the code becomes a bit more beautiful:
```ruby
class UserController < ApplicationController
  def create
    @user = ExternalAPI::User.new.extended_by(
      Methy.of(*[:subscribe_newsletter, :nickname])
    )
  end
end
```


In case you need default values in the inputs you can pass a hash:

```ruby
class UserController < ApplicationController
  def create
    @user = ExternalAPI::User.new.extended_by(
      Methy.of(*[subscribe_newsletter: false, :nickname])
    )
  end
end
```

Please note that extending an object at runtime is not the most performant thing
to do in the world, so evaluate your performance requirements first :)

But usually it's OK.

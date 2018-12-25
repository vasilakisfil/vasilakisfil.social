---
title: Best service objects until now
date: 2017-04-09
---

Service objects was a big thing a couple years ago in Rails community, like everyone
just learned about the single responsibility principle.
In any case, personally I couldn't find a Service Object pattern that I was happy with,
neither from my brain nor from the Internetzz.
Lately I have been using something that I can say it's good enough.
I call it `PerformerService`, meaning that it's for service objects that should
have a simple method, called `perform`.
First I define and include the following module in any Service Object I need it
to behave as a `PerformerService`.

```ruby
module PerformerService
  def self.included(base)
    base.send(:define_singleton_method, :perform) do |*args|
      return self.send(:new, *args).send(:perform)
    end
  end

  class Failure
    attr_reader :errors, :meta

    def initialize(errors = [], meta = {})
      @errors = [errors].flatten
      @meta = meta.is_a?(Hash) ? OpenStruct.new(meta) : meta
    end

    def success?
      false
    end
    alias_method :valid?, :success?

    def method_missing(meth, *args)
      if meta.respond_to?(meth)
        self.data.send(meth, *args)
      elsif meta.is_a?(Hash) && meta.key?(meth) && args.length == 0
        self.data.send(:[], meth)
      else
        super
      end
    end
  end

  F = Failure

  class Success
    attr_reader :data

    def initialize(data = {})
      @data = data.is_a?(Hash) ? OpenStruct.new(data) : data
    end

    def success?
      true
    end

    alias_method :valid?, :success?

    def value
      data
    end

    def method_missing(meth, *args)
      if data.respond_to?(meth)
        self.data.send(meth, *args)
      elsif data.is_a?(Hash) && data.key?(meth) && args.length == 0
        self.data.send(:[], meth)
      else
        super
      end
    end
  end

  S = Success
end
```

The module does 3 important things:

* First it defines a class method called `perform` so that you can call the
Service Object as `ServiceObject.perform`
* Secondly it treats the object's `initialize` method as private, which means that
we **should** mark the method as private in our Service Object class definition (as seen below)
to avoid calling the object in a different way other than the `perform` class method
* Third it defines a `Success` and `Failure` classes that have some nice interfaces,
as we will she below.

Now in order to create a Service Object all we have to do is to include the module
and mark **everything else** as private methods.

```ruby
class UserAuthenticationService
  include PerformerService

  private
    attr_reader :username, :password

    def initialize(username, password)
      @username, @password = username, password
    end

    def perform
      begin
        resp = external_api_user
        return S.new({user: resp[:user]})
      rescue ExternalApi::AuthenticationError => msg
        F.new(msg, status: 401)
      end
    end

    def external_api_user
      ExternalApi::User.do_stuff(token)
    end
end
```

```ruby
class SessionsController < ApplicationController
  def create
    result = UserAuthenticationService.perform(params[:username], params[:password])

    if result.success?
      @current_user = result.user
      head :created
    else
      render(json: {errors: result.errors}, status: result.status)
    end
  end
end
```

Note: I add the `method_missing` because I like to use `result.method` instead of
`result.meta.method` (in case of `Failure`) or `result.data.method` (in case of `Success`).

It's a matter of personal taste and you can remove it if you don't like it, the `PerformerService`
will still be the best Servic Object pattern out there, I think :)

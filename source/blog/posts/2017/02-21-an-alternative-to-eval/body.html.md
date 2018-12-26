---
title: An alternative to eval
date: 2017-02-21
---


When we define a closure in Ruby (a proc or a lambda), it encapsulates its lexical scope/environment.

This means that even if you define a proc in point A in code, if you pass it around and
call it in point B, it will still be able to reference variables and anything that is defined inside the lexical scope of point A (where it was defined). To put it in another way, it has "(en)closed its environment".

What if we would like to do the opposite. Say we define a proc in point A, that if we call there it makes no sense, but we want it to run it in point B and change the lexical scope of the closure so that what we run is reflected in point B.

To give you an example:

```ruby
CLOSURE = proc{puts internal_name}
def outside_closure
  proc{puts internal_name}
end

class Foo
  def internal_name
    'foo'
  end

  def closure
    proc{puts internal_name}
  end

  def name1
    closure.call
  end

  def name2
    outside_closure.call
  end

  def name3
    CLOSURE.call
  end

end

puts Foo.new.name1 #=> foo
puts Foo.new.name2 #=> undefined local variable or method `internal_name' for main:Object (NameError)
puts Foo.new.name3 #=> undefined local variable or method `internal_name' for main:Object (NameError)
```

Makes sense that `name2` method failed because `internal_name` had not been defined when we defined the closure.


However, it is possible to redefine proc's binding (lexical scope) using `instance_exec`:

```ruby
CLOSURE = proc{puts internal_name}
def outside_closure
  proc{puts internal_name}
end

class Foo
  def internal_name
    'foo'
  end

  def closure
    proc{puts internal_name}
  end

  def name1
    closure.call
  end

  def name2
    outside_closure.call
  end

  def name3
    instance_exec(&(CLOSURE))
  end

end

puts Foo.new.name1 #=> foo
puts Foo.new.name2 #=> foo
puts Foo.new.name3 #=> foo
```

Success! This means that we can write code in one part of our app and run it under totally different context. Also, it's better than eval because it provides some basic sytax checking by Ruby interpreter. But where could this be useful?

I have been using it in various hacks but one of most useful ones are on Rails routes. This little trick has helped me to remap nested routes for free.

Let's say that we have the following route:
```ruby
  namespace :api do
    namespace :v1 do
      resources :company_users, only: [:show] do
        resources :posts, only: [:index] do
          resource :stats, only: [:show]
        end
      end
    end
  end
```

This leads to the following routes:

```
/api/v1/company_users/:id
/api/v1/company_users/:company_user_id/posts
/api/v1/company_users/:company_user_id/posts/:post_id/stats
```

Turns out that `:company_user_id` is kind of useless and we would like to give more flexibility to the client by having the following:

```
/api/v1/stats?user_id=:company_user_id&post_id=:post_id
```

However, the API is already out in production and changes are difficult. So we employ our little trick:


```ruby
  namespace :api do
    namespace :v1 do
      resources :company_users, only: [:show] do
        resources :posts, only: [:index] do
          resource :stats, only: [:show]
        end
      end

      resource :stats, only: [:show], defaults: {company_user_id: proc{params[:company_id]}}
    end
  end
```

Params inside routes?! Yes! Because we will rebind the context of that proc in the context of a controller with the following snippet:
```ruby
  def reshape_hash!
    self.params = HashWithIndifferentAccess.new(params.to_unsafe_h.reshape(self))
  end
```

Now if you send `user_id` to this route, it will be added as `company_user_id`  by adding this method as a `before_filter`

```ruby
class Api::V1::StatsController < ApplicationController
  before_action :authenticate_user!
  before_action :reshape_hash!

  def index
    stats = Stats.new(current_user).all(
      user_id: params[:company_user_id], post_id: params[:post_id]
    )

    render json: stats, serializer: StatsSerializer
  end
```

Another place I use it is when dealing with DSLs. An example is with [rspec-api_helpers](https://github.com/kollegorna/rspec-api_helpers). For instance, in the following spec:

```ruby
describe Api::V1::UsersController, '#show', type: :api do
  describe 'Authorization' do
    context 'when authenticated as a regular user' do
      before do
        create_and_sign_in_user
        FactoryGirl.create(:user)
        @user = User.last!

        get api_v1_user_path(@user.id)
      end

      it_returns_attribute_values(
        resource: 'user', model: proc{@user}, attrs: [
          :id, :name, :email,
        ]
      )
    end
end
```

The `it_returns_attribute_values` method accepts a proc with an instance variable in the `context` context which initially makes no sense. However it's a way letting the user to pass in a variable that _should_ be called inside the `it` block.

I have used it in other places too but mostly as a last resort. Use it with carefulness towards your collegues!

---
title: My favorite RSpec aliases
date: 2017-04-12
---

Development in compilers has advanced so much that static typed languages have reached the same level
human-friendly level as dynamic languages and type safety is coming back while dynamic languages are fading away :)

Lately I have been focusing more on safety when I develop code on dynamic languages, especially in Ruby.
(I had a couple of days fun in Crystal and it feels like a minefield when working with Ruby again or any other dynamic language)

One of the usual things I do is, in order to avoid code duplication, I use metaprogramming to generate code
that I would otherwise write myself. The advantage is two-fold: first it saves me time from writing the same stuff,
secondly checks are made by the interpreter when the system boots (or during runtime but I avoid that case).

When running the tests I always like to have in `.rspec` the following 2 options:

```
--color
--format=documentation
```

Now my usual rspec test file would look like that:
```ruby
RSpec.describe "Feature: Create account", :type => :feature do
  describe "with correct input" do
    before :each do
      #setup state
    end

    it "creates an account" do
      #run expectations
    end
  end

  describe "with wrong input" do
    before :each do
      #setup state
    end

    it "creates an account" do
      #run expectations
    end
  end
```
Very simple example just for the sake of showing you what I mean.

With those options in `.rspec` we would get the following:

```nohighlight
Feature: Create account
  with correct input
    creates an account
  with wrong input
    gets an error
```

Do you see a pattern there? Some `with` are repeated and also `Feature:` will be repeated in every feature.

How can we move that from simple string descriptions to the language itself?

```ruby
module RSpecWith
  def with(text, options = {}, &block)
    describe("with #{text}", options, &block)
  end

  def when(text, options = {}, &block)
    describe("when #{text}", options, &block)
  end

  def inside(text, options = {}, &block)
    describe("inside #{text}", options, &block)
  end
end

RSpec.configure do |config|
  # other stuff...
  config.extend RSpecWith
end
```

Or with some meta alcohol:
```ruby
module RSpecWith
  [:with, :when, :inside].each do |descriptor|
    define_method(descriptor) do |text, options = {}, &block|
      describe("with #{text}", options, &block)
    end
  end
end

RSpec.configure do |config|
  # other stuff...
  config.extend RSpecWith
end
```

And about the top feature thingy:
```ruby
RSpec.send(:define_singleton_method, :top_feature) do |text, options, &block|
  RSpec.describe("Feature: #{text}", options, &block)
end
```

So now we basically can write some code instead of strings :)

```ruby
RSpec.top_feature "Create account", :type => :feature do
  with "correct input" do
    before :each do
      #setup state
    end

    it "creates an account" do
    end
  end

  with "wrong input" do
    before :each do
      #setup state
    end

    it "creates an account" do
      #run expectations
    end
  end
end
```

I have been using this technique **alot** through out my code.
I explicitly aim for things that can be setup on startup time and not on demand.
Creating methods on runtime is really bad idea, I think, but on boot it doesn't hurt because even if you create, say, 100 new methods and 10 classes
it is still OK but imagine if you create 5 methods in each request on Rails and having like 1000 request per minute on a single process.. that would mean
5000 new methods per minute..

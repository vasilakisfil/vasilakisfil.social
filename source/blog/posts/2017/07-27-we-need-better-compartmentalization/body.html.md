---
title: We need better compartmentalization
date: 2017-07-27
---

With the latest updates from the [unethical moves of Kite](https://theoutline.com/post/1953/how-a-vc-funded-company-is-undermining-the-open-source-community),
something that I had been thinking about for a long time now came into my mind again: how secure is our Ruby/Rails/Sinatra/Hanami code?

We have been using so many little gems to save time from re-inventing the wheel and that has worked out great.
We save time by reusing open-source projects, let alone all the advantages of using open source in our code.
But if we step back and take a look from a security perspective, adding gems even for the simpliest thing could be a security breach.

Did you know that a maintainer of a popular gem can publish a new version in Rubygems without publishing anything in Github ?
Or it can bump and publish a new version in Github but still send different code in Rubygems, from which people download the gem.
Even worse, do you acknowledge that any gem you add in your Ruby project has access to all public methods/constants/namespaces
(like `Rails.application.secrets`), global `ENV` or even in your data in your database?
Not only it does have access, but also it can even alter the code of methods or classes of your core app or framework's code.
Ruby even allows you to alter a constant unless it's already frozen.

An ActiveRecord gem that extends AR for JSONB data types on Postgres _could_ be OK to access the database, but a tiny gem
that I need for enhancing my Rails views, accessing all that kind of stuff and even having the ability to modify some of them **is not cool**.

Think twice and be careful before you install yet another Ruby gem.

So.. how do we solve this issue?
I guess one idea is to create a tiny microservice with only a gem and serve it from a private isolated network.
That way you won't have any data leach. However, even that is not secure enough:
the malicious code could decide to return garbage data at any point (or at a specific point, when you need it most, having some "inside" information in combination with after some
crazy machine learning ^_^ on your usage patterns, favoring your competitor).
But let's be more pragmatic: none is going to do that :)

Instead, we need to add primitives in Ruby (although I suspect that other languages like PHP, Elixir and Javascript probably have the same issues)
that help us compartmentalizing specific parts of our code.

[`freeze`](https://ruby-doc.org/core-2.4.1/Object.html#method-i-freeze) method implemented in the language itself is a good start.
When you freeze a constant, you make it immutable and thus cannot be changed by any means.
We need more primitives like that. We need ways to say that this class cannot be extended/reopened/altered **by default**.
The same goes with methods, we need to give ways to developers to not allow critical
methods to be altered.
We need to instruct constants that are not supposed to be accessible by outside as private only by explicitly marking them as private (it needs some special work in Ruby).

Once we do that, then the application frameworks need to use those primitives but also build upon those.
For instance, in Rails, critical (if not all) classes/methods/constants should not only be "frozen" (which means cannot be modified by malicious code)
but also be declared as private-only so that
installed gems don't even have access to such information **by default**.
Let the user inject what she thinks that is necessary for her installed gem to work, through the initializers.
Classes should not be open for extension **by default**, unless the user instructs differently (that could be a bit challenging).

It might take some time and effort but we need to invest time and find better ways on how to protect ourselves from such and similar attacks.

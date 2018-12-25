---
title: REST is all about evolvability
date: 2017-07-29
---

I just saw this post ([RESTful APIs, the big lie](https://mmikowski.github.io/the_lie/)) and I am wondering if developers understand what REST is before denouncing it.
Even worse, people are agreeing in that post's comments and if you go to hackernews or reddit discussion about this blog post you will see that
most people are confused on what REST is, which sometimes wrongly leads to the assumption that REST is bad.

**REST is all about evolvability by applying a uniform interface in your implementation.**

If you **do have** evolvability in your API then my guess is that it will be either REST or GraphQL.
I haven't seen any other model for evolvable networked architectural style.

If you don't have evolvability in your API architecture don't even try to compare it to REST because these are 2 different things.
A non evolvable API can only be compared to RPC.
It can be great RPC but it's an RPC.
Does it mean it's bad ? Not necessarily, it depends on the amount of time/money you
want to invest for it in combination with the use case.
When you built an API to be used in the span of 2-3 years a non-REST API _could_ be fine.
**But when your API is supposed to talk with IoT devices from Mars, live 50 years or talk to clients that you cannot control then REST or an equivelent model (like GraphQL) is the only solution**.
Comparing a non-evolvable JSON API and saying that it's better or equivalent than REST then this means that you don't understand what REST is.

If you want to denounce REST, come up with an equivalent model (like GraphQL creators did) to compare it.

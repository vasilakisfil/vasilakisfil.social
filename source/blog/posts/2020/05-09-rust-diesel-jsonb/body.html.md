---
title: JSONB data with Rust and Diesel
date: 2020-05-09
---


PostgreSQL JSONB columns are quite handy, there many times that I use them actually.
I usually employ JSONB for (meta)data that even if they get lost, we are fine,
we just need to do more manual work.

READMORE

The usual cases include:

* caching data
* shortening relations, so instead of going table1 -> table2 -> table3 -> table4, you can
store the table4 id inside table1 jsonb `meta` column to shorten the path (and vice versa)
* metadata that we want to store, but don't deserve a dedicated column.

Working lately in Rust, I was trying to figure out how can I use a JSONB column
with diesel. It turns out that it's not that difficult actually!

So let's say that we have the following db-related struct (the context taken from
an [OCPP](https://en.wikipedia.org/wiki/Open_Charge_Point_Protocol)-related project):

```rust
#[derive(Debug, Queryable, QueryableByName)]
#[table_name = "remote_starts"]
pub struct RemoteStart {
    id: Uuid,
    created_at: chrono::DateTime<Utc>,
    updated_at: chrono::DateTime<Utc>,
}
```

First we need to add the migration

```sql
ALTER TABLE remote_starts ADD COLUMN meta JSONB DEFAULT '{}'::jsonb NOT NULL;
```

It's important to define a default, in general nullable columns should be avoided.
Also, we can't set the default to the current structure of the json document we
are thinking to build because

  * it's live system and we don't even have the data to normalize existing rows
  *  we don't even know how the document will look like in the future, and every time
we want to add/remove attributes from the document we also need to update the default
migration, to keep things in sync. That's quite tedious and we should shift type
checking in the application level instead. As I said I mostly treat JSONB column data
as "nice to have", rather than crtical application data.

Hence, having the default as an empty json, should be enough, and we can shift
type checking in the application layer.

Then we define the struct that will handle the data of the jsonb column.
Of course, we need to derive the appropriate traits for it:

```rust
#[derive(FromSqlRow, AsExpression, serde::Serialize, serde::Deserialize, Debug, Default)]
#[sql_type = "Jsonb"]
pub struct Meta {
    pub error_info: Option<String>,
    pub suggested_id_tag: Option<String>,
}
```

Here we have each field of `Meta` as optional, and probably it's a good idea since
we don't want to be super strict for the data found inside.


The next part and the most tricky, is to derive the FromSql and ToSql Diesel traits,
that Diesel uses internally to serialize and deserialize the column.
Just a note, when I say serialize/deserialize, I mean in the sql terms, not JSON,
it just happens here that the column we want to serialize/deserialize is a JSON(B)
column.
After some research I figured out:

```rust
impl FromSql<Jsonb, Pg> for RemoteStartMeta {
    fn from_sql(bytes: Option<&[u8]>) -> diesel::deserialize::Result<Self> {
        let value = <serde_json::Value as FromSql<Jsonb, Pg>>::from_sql(bytes)?;
        Ok(serde_json::from_value(value)?)
    }
}

impl ToSql<Jsonb, Pg> for RemoteStartMeta {
    fn to_sql<W: Write>(&self, out: &mut Output<W, Pg>) -> diesel::serialize::Result {
        let value = serde_json::to_value(self)?;
        <serde_json::Value as ToSql<Jsonb, Pg>>::to_sql(&value, out)
    }
}
```

Yes it's not that straightforward, even for me personally that I have been working 9 months
with Rust. But if you look the big picture it actually makes sense: for the
`FromSql`, we read the value and serialize it using Serde, while for the `ToSql`
trait, we just serialize the value again using Serde. The tricky part is to derive
the correct types. Note that Pg is `diesel::pg::Pg`, and we could actually use
the generic trait of `diesel::backend::Backend`, that is more generic and does
work for all 3 sql databases (postgres, mysql and sqlite). We _could_ I said, as
I couldn't figure out actually how, I gave up after 1 hour fight with the compiler..

Anyway, once you have those traits, then you can update the db-struct and you
should be good to go:

```rust
#[derive(Debug, Queryable, QueryableByName)]
#[table_name = "remote_starts"]
pub struct RemoteStart {
    id: Uuid,
    created_at: chrono::DateTime<Utc>,
    updated_at: chrono::DateTime<Utc>,
    meta: Meta
}
```

### Updating the jsonb attributes
So what can you do when you wanna update a simple field of json attribute?
Let's first see how we would do that in postgreSQL. Let's say that we get back
an error (note: OCPP operations are mostly async), and we need to update our db
with the error info for further inspection.
Using postgresql we would do:

```sql
UPDATE remote_starts SET meta = jsonb_set(meta, '{error_info}', '"ConnectionError"');
```

If we are fine with loosening type checking a bit (and shift more checks over the
db itself), we could use the [AsChangeset](http://docs.diesel.rs/diesel/query_builder/derive.AsChangeset.html)
trait that would enable us to make all fields optional and when updating the
struct, diesel will update only the ones that are Some. It's a quite handy
pattern if you want to build up something quickly.

But as I said, that is problematic because:

* you lose on type checking
* it has a lot of boilerplate for JSONB columns, because the None/Some that diesel
uses to check which columns to update, works only on column level. Which means that
if you want to update a single JSONB attribute, you need to make sure that you
write the whole column in order to keep intact the rest attributes,
so you basically don't actually run the update above but rather a complete column
update.


However, it turns out that Diesel has a magic macro named `sql_function!` that
can help us. As the documentation says:

> Diesel only provides support for a very small number of SQL functions. This macro enables you to add additional functions from the SQL standard, as well as any custom functions your application might have.
> The syntax for this macro is very similar to that of a normal Rust function, except the argument and return types will be the SQL types being used. Typically these types will come from diesel::sql_types
> This macro will generate two items. A function with the name that you've given, and a module with a helper type representing the return type of your function.

So basically we should define the postgres function with the postgres types, but
with rust syntax. Let's look again what function we use to update the `meta`:

```sql
jsonb_set(meta, '{error_info}', '"ConnectionError"')
```

Let's find what the postgresql documentation says exactly about this function:

```
jsonb_set(target jsonb, path text[], new_value jsonb [, create_missing boolean])
```

So, using `sql_function!` that would be:

```rust
sql_function!{
    fn jsonb_set(target: Jsonb, path: Array<Text>, new_value: Jsonb) -> Jsonb
}
```


I think it seems quite straightforward, right? At least until you figure out that
Diesel provides you that little gem.

So how can we use it? As you would use anything else in diesel, when updating
a column. The `sql_function!` macro above has created a `jsonb_set` function,
with the appropriate types/signature ready to be used.

```rust
diesel::update(remote_starts::table.filter(remote_starts::id.eq(id))).set(
    remote_starts::meta.eq(jsonb_set(
        remote_starts::meta,
        vec![String::from("error_info")],
        serde_json::Value::String(error.unwrap_or("")), //we will improve that part later by assigning proper null
    )),
)
```

Note: `error` here is an `Option<String>` argument to that function that does the update, so
replace the `error` with just `Some(ConnectionError)`, `None` or any other error you
could think.

Ok great, only that having `"error_info"` string hand-typed in there breaks the
whole idea of type checking. A simple miss and the JSONB data is messed up..
What can we do better? We could extract it as a separate function:

```rust
pub fn update_error_info_jsonb_expression(
    error_info: Option<String>,
) -> jsonb_set::jsonb_set<
    remote_starts::columns::meta,
    diesel::expression::bound::Bound<
        diesel::sql_types::Array<diesel::sql_types::Text>,
        std::vec::Vec<String>,
    >,
    diesel::expression::bound::Bound<diesel::sql_types::Jsonb, serde_json::value::Value>,
> {
    let error_info = match error_info {
        Some(error_info) => serde_json::Value::String(error_info),
        _ => serde_json::Value::Null,
    };

    super::jsonb_set(
        remote_starts::meta,
        vec![String::from("error_info")],
        error_info,
    )
}
```

Yeap that's what Rust does internally with type inference in the previous example.
Well almost, previously we would unwrap the error with empty string in case of `None`,
here we set proper `null` in case of an empty string.

But my point here is that, instead of writing manually the json attribute you want
to update each time (like `error_info`), we wrap that part in a function to save
ourselves from bugs. We still need to explicitly hand-write the `error_info`, only
that we write it once, wrap it in a function and use that. So we increased safety
a bit and minimized the possibility of introducing a bug.

Talking about safety, actually in Ruby, _that specific part_ would be "safer" here,
mostly because with some metaprogramming, you wouldn't type the attribute name,
but rather you would call a method name, and if it didn't exist it would throw
a runtime error and you wouldn't mess up your data (but you would have to fix that
error though). Of course, given that you are working with a sane library and not
a pretty lame one that uses `method_missing` and allows you to write _any_ attribute...
I am noting that here cause there is a lot of hype in Rust regarding safety,
but there are many concepts of "safety" when writing software.

But in fact, in Rust you can also make it safer, ruby-equivalent safe at least, by wrapping
the whole thing in a macro. However writing that macro is hard, way
way harder than Ruby metaprogramming, so that's all I could get for safety,
the macro stuff probably in another blog post..




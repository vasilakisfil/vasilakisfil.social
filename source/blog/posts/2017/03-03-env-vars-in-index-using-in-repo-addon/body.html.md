---
title: Env variables inside Ember's index.html
date: 2017-03-03
---

Using environment variables in ember is straightforward: export your env vars using
any tool like direnv and import them inside your `config/environment.js` using
node's `process.ENV.YOUR_ENV_KEY`.

```javascript
  ENV.APP.MIXPANEL_TOKEN = process.env.MIXPANEL_TOKEN;
  ENV.APP.GA_TOKEN = process.env.GA_TOKEN;
```

Then in any part of your Ember app you can import the `config` env and use them.

```javascript
import Config from 'my-ember-project/config/environment';
```

However this won't work if you want to use an environment variable from `index.html`.
This is the first file that the browser loads which then tells the browser
to fetch the ember and your ember code, among others.

### Ember in-repo addons to the rescue
Ember in-repo addons come to the rescue because they allow you to manipulate the
`index.html` using ember-cli's `contentFor` [hook](https://ember-cli.com/extending/#content).
As you might have guessed, this hook is called whenever you add a `content-for` in
your `index.html`, like `{{content-for "head"}}`.


You can even create your own `content-for` hook like `{{content-for "variables"}}`.
Then in your project run `ember g in-repo-addon variables` which will create a basic
addon structure under your `lib/` folder.
This will allow you to export the environment variables straight to the `window` object:

```javascript
/*jshint node:true, esversion: 6*/
module.exports = {
  name: 'metrics',

  isDevelopingAddon: function() {
    return true;
  },
  contentFor: function(type, config){
    if (type === 'variables'){
      return `
        window.MIXPANEL_TOKEN = "${config.APP.MIXPANEL_TOKEN}";
        window.GA_TOKEN = "${config.APP.GA_TOKEN}";
      `;
    }
  }
};
```
Now `{{content-for "variables"}}` will basically run the code returned by the hook method,
giving you access to your environment variables, on build time.

I should note that those hooks are also available on regular (out-of-repo) addons.

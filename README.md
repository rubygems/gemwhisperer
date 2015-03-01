gemwhisperer
============

[![Deploy](https://www.herokucdn.com/deploy/button.png)](https://heroku.com/deploy)

This is an example application that uses the RubyGems webhook system to post Twitter updates about gems.

Check out more information about [webhooks](https://rubygems.org/pages/api_docs#webhook).

Development
-----------

First thing's first. Install the gem dependencies:

    bundle install

In development, gemwhisperer runs on SQLite so there's no need to create the database. Simply:

    rake db:migrate

Before you fire it up, you'll need to configure the application for your own [Twitter application](https://dev.twitter.com/apps) and [RubyGems account](https://rubygems.org/profile/edit). The `config/application.example.yml` file will get you started.

Now, fire it up:

    rackup

The gemwhisperer application is built for [Heroku](http://heroku.com/). To deploy:

    gem install heroku
    heroku create
    git push heroku master

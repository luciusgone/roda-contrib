# RodaContrib

The roda-contrib gem is my personal collection of plugins working with Roda(the
Routing tree toolkit).

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'roda-contrib'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install roda-contrib

## Usage

Currently, the roda-contrib gem ships 4 plugins:

* load\_all
* multi\_dispatch
* csrf
* json\_api

When loading plugins from this gem, you should append the 'contrib' to the
symbol to load it. For example, if you want to use the multi\_dispatch plugin:

```ruby
class App < Roda
  plugin :contrib_multi_dispatch
end
```

For details of the each plugin, please refer to the documentation or the code.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run
`rake spec` to run the tests. You can also run `bin/console` for an interactive
prompt that will allow you to experiment.

## Contributing

Bug reports and pull requests are welcome on GitHub at
https://github.com/luciusgone/roda-contrib.


## License

The gem is available as open source under the terms of the
[MIT License](http://opensource.org/licenses/MIT).

require 'roda/contrib/plugins/csrf'

Roda::RodaPlugins.register_plugin(:contrib_csrf, RodaContrib::Plugins::Csrf)

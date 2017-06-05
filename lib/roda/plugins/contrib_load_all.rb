require 'roda/contrib/plugins/load_all'

Roda::RodaPlugins.register_plugin(:contrib_load_all, RodaContrib::Plugins::LoadAll)

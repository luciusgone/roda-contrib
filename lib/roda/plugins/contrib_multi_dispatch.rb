require 'roda/contrib/plugins/multi_dispatch'

Roda::RodaPlugins.register_plugin(:contrib_multi_dispatch, RodaContrib::Plugins::MultiDispatch)

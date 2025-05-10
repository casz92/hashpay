# Configuración genesis
import Config

pubkey =
  <<62, 171, 231, 251, 152, 189, 107, 129, 207, 216, 84, 103, 99, 143, 107, 71, 71, 117, 173, 45,
    229, 68, 164, 172, 46, 135, 230, 171, 30, 179, 144, 68>>

# <<163, 16, 202, 44, 150, 158, 173, 215, 186, 87, 97, 174, 103, 66, 25, 187, 204,
# 123, 16, 205, 97, 66, 91, 175, 79, 230, 5, 218, 178, 0, 137, 198, 62, 171,
# 231, 251, 152, 189, 107, 129, 207, 216, 84, 103, 99, 143, 107, 71, 71, 117,
# 173, 45, 229, 68, 164, 172, 46, 135, 230, 171, 30, 179, 144, 68>>

hashnumber =
  14_094_546_945_335_813_518_113_527_622_292_004_298_502_402_621_906_749_383_847_767_774_109_225_594_204

config :hashpay, :hashnumber, hashnumber
config :hashpay, :pubkey, pubkey
config :hashpay, :default_currency, "cu_HPY"
config :hashpay, :default_channel, "#origin"
config :hashpay, :round_time, 500
config :hashpay, :round_timeout, 1_500

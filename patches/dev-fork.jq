# Подменяет ключ producer-а eosio на dev-ключ во всех местах снапшота coopos,
# чтобы локальная нода продолжила цепь, не имея прод-приватника.
#
# Структура секций в снапшоте coopos подтверждена на v5.2.0:
#   eosio::chain::permission_object   — права аккаунтов (owner|active|...)
#   eosio::chain::block_state         — head block, active_schedule, signing authority
#
# На проде coopos работает в single-producer-mode (active_schedule = только "eosio"),
# поэтому достаточно подменить ключ "EOS7TjqL5..." на dev-ключ ниже.
#
# Dev keypair (Antelope default — известен всем):
#   public:  EOS6MRyAjQq8ud7hVNYcfnVPJqcVpscN5So8BhtHuGYqET5GDW5CV
#   private: 5KQwrPbwdL6PhXujxW37FSSQZ1JiwsST4cqQzDeyXtP79zkvFD3

"EOS6MRyAjQq8ud7hVNYcfnVPJqcVpscN5So8BhtHuGYqET5GDW5CV" as $DEV_KEY

# 1. permission_object: для всех permissions аккаунта `eosio` (owner, active, …)
#    подменяем ключ. Threshold/accounts/waits не трогаем — у eosio их нет.
| .["eosio::chain::permission_object"].rows |= map(
    if .owner == "eosio"
    then .auth.keys |= map(.key = $DEV_KEY)
    else . end
  )

# 2. block_state: единственная строка содержит head-блок и его подписной authority.
#    Меняем ключ в трёх местах:
#      a) active_schedule.producers[*].authority — variant [0, {keys: [...]}]
#      b) valid_block_signing_authority — тот же variant
#      c) pending_schedule.schedule.producers — на проде пуст, но если есть — тоже.
| .["eosio::chain::block_state"].rows |= map(
    .active_schedule.producers |= map(
      .authority[1].keys |= map(.key = $DEV_KEY)
    )
    | .valid_block_signing_authority[1].keys |= map(.key = $DEV_KEY)
    | (if .pending_schedule.schedule.producers != null then
         .pending_schedule.schedule.producers |= map(
           .authority[1].keys |= map(.key = $DEV_KEY)
         )
       else . end)
  )
